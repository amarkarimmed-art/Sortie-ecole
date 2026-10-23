import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/reverb_service.dart';
import '../../auth/data/auth_repository.dart';
import '../data/surveillance_repository.dart';
import '../domain/pickup_request_called_event.dart';
import '../domain/pickup_request_departed_event.dart';
import '../domain/surveillance_state.dart';
import 'widgets/class_group_section.dart';

/// Écran principal du surveillant (F04).
///
/// Affiche la liste des élèves appelés (statut `class_notified`),
/// groupés par classe et triés chronologiquement (CA11).
///
/// Écoute en direct les événements WebSocket Reverb `pickup.called` (CA14).
/// Se resynchronise automatiquement lors de la reconnexion après coupure (CA15).
class SurveillanceScreen extends StatefulWidget {
  final SurveillanceRepository? repository;
  final ReverbService? reverbService;
  final String? token;
  final String? schoolId;
  final String? schoolName;
  final String? schoolLogo;

  const SurveillanceScreen({
    super.key = const Key('ecran_surveillance'),
    this.repository,
    this.reverbService,
    this.token,
    this.schoolId,
    this.schoolName,
    this.schoolLogo,
  });

  @override
  State<SurveillanceScreen> createState() => _SurveillanceScreenState();
}

class _SurveillanceScreenState extends State<SurveillanceScreen> {
  late final SurveillanceRepository _repository;
  bool _ownsRepository = false;
  StreamSubscription<PickupRequestDepartedEvent>? _departedSubscription;
  StreamSubscription<ArrivalSignaledEvent>? _newArrivalSubscription;

  String? _effectiveToken;
  String? _schoolName;
  String? _schoolLogo;
  ScheduleStatusDto? _scheduleStatus;
  Timer? _schedulePollingTimer;

  @override
  void initState() {
    super.initState();
    _effectiveToken = widget.token;
    _schoolName = widget.schoolName;
    _schoolLogo = widget.schoolLogo;

    final effectiveSchoolId =
        widget.schoolId ?? 'a3000c08-8f84-4bff-8c3f-81ebf2b014dd';
    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      final reverb = widget.reverbService ??
          ReverbService(
            baseUrl: 'ws://127.0.0.1:8080',
            schoolId: effectiveSchoolId,
          );
      _repository = SurveillanceRepository(
        baseUrl: 'http://127.0.0.1:8000',
        schoolId: effectiveSchoolId,
        reverbService: reverb,
      );
      _ownsRepository = true;
    }

    _loadStorageInfo();

    _repository.init();
    _repository.loadInitialQueue(token: widget.token);
    _repository.reverbService.connect(authToken: widget.token);

    // Écouter les événements pickup.departed pour mettre à jour la carte en temps réel
    _departedSubscription =
        _repository.reverbService.departedEvents.listen((event) {
      if (mounted) {
        setState(() {
          _repository.updateItemStatus(event.requestId, 'on_the_way');
        });
      }
    });

    // Écouter les nouvelles arrivées pour afficher une notification visuelle discrète
    _newArrivalSubscription =
        _repository.newArrivalAlerts.listen((event) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final name = event.studentName ?? event.parentName ?? '';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              name.isNotEmpty && l10n != null
                  ? l10n.nouvelleArrivee(name)
                  : 'Nouvelle arrivée signalée au portail', // hardcoded-ok
            ),
            backgroundColor: Colors.teal.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    _loadScheduleStatus();
    _schedulePollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadScheduleStatus(),
    );
  }

  Future<void> _loadScheduleStatus() async {
    final status = await _repository.getScheduleStatus(
      token: _effectiveToken ?? widget.token,
    );
    if (mounted && status != null) {
      setState(() {
        _scheduleStatus = status;
      });
    }
  }

  Future<void> _loadStorageInfo() async {
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      final name = await storage.read(key: 'auth_school_name');
      final logo = await storage.read(key: 'auth_school_logo');

      if (mounted) {
        setState(() {
          if (_effectiveToken == null || _effectiveToken!.isEmpty) {
            _effectiveToken = token;
          }
          if (_schoolName == null || _schoolName!.isEmpty) {
            _schoolName = name;
          }
          if (_schoolLogo == null || _schoolLogo!.isEmpty) {
            _schoolLogo = logo;
          }
        });
        _loadScheduleStatus();
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    final token = _effectiveToken ?? widget.token;
    try {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
      if (token != null && token.isNotEmpty) {
        final authRepo = AuthRepositoryImpl(baseUrl: _repository.baseUrl);
        await authRepo.logout(token);
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  void dispose() {
    _schedulePollingTimer?.cancel();
    _schedulePollingTimer = null;
    _departedSubscription?.cancel();
    _newArrivalSubscription?.cancel();
    _repository.reverbService.disconnect();
    if (_ownsRepository) {
      _repository.dispose();
      _repository.reverbService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Récupérer arguments de route si passés
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is Map<String, dynamic>) {
      _schoolName ??= routeArgs['schoolName'] as String?;
      _schoolLogo ??= routeArgs['schoolLogo'] as String?;
      _effectiveToken ??= routeArgs['token'] as String?;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_schoolLogo != null && _schoolLogo!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _schoolLogo!,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.school, size: 24),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 8.0),
                child: Icon(Icons.school, size: 24),
              ),
            Flexible(
              child: Text(
                _schoolName ?? l10n.ecranSurveillanceTitre,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Indicateur de resynchronisation / état WS (CA15)
          StreamBuilder<bool>(
            key: const Key('ecran_surveillance_resync'),
            stream: _repository.reverbService.connectionStream,
            initialData: _repository.reverbService.isConnected,
            builder: (context, snapshot) {
              final isConnected =
                  snapshot.data ?? _repository.reverbService.isConnected;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8.0),
                child: Row(
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      size: 20,
                      color: isConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      isConnected ? l10n.enDirect : l10n.reconnexionEnCours,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isConnected ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            key: const Key('surveillance_btn_refresh'),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _loadScheduleStatus();
              _repository.loadInitialQueue(token: _effectiveToken ?? widget.token);
            },
          ),
          IconButton(
            key: const Key('surveillance_btn_logout'),
            tooltip: l10n.deconnexion,
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
          ),
        ],
      ),
      // Flux temps réel encapsulé (CA14)
      body: StreamBuilder<PickupRequestCalledEvent>(
        key: const Key('ecran_surveillance_stream'),
        stream: _repository.reverbService.calledEvents,
        builder: (context, eventSnapshot) {
          return StreamBuilder<SurveillanceState>(
            stream: _repository.state,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data ??
                  SurveillanceLoaded(items: _repository.currentItems);

              if (state is SurveillanceLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state is SurveillanceError) {
                if (state.message.contains('401') || state.message.toLowerCase().contains('unauthenticated')) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _handleLogout());
                }

                return Center(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        ElevatedButton.icon(
                          onPressed: () => _repository.loadInitialQueue(token: _effectiveToken ?? widget.token),
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.reessayer),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is SurveillanceLoaded) {
                final grouped = state.groupedByClass;

                return ListView(
                  padding: const EdgeInsetsDirectional.all(16.0),
                  children: [
                    _buildScheduleStatusBanner(l10n),
                    if (state.isResyncing)
                      Container(
                        margin: const EdgeInsetsDirectional.only(bottom: 12.0),
                        padding: const EdgeInsetsDirectional.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              l10n.miseAJourEnCours,
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (grouped.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48.0),
                        child: Center(
                          child: Text(
                            l10n.aucunEleveAppele,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ...grouped.entries.map((entry) => ClassGroupSection(
                            className: entry.key,
                            items: entry.value,
                            repository: _repository,
                            token: _effectiveToken ?? widget.token,
                          )),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  Widget _buildScheduleStatusBanner(AppLocalizations l10n) {
    if (_scheduleStatus == null) return const SizedBox.shrink();
    final isOpen = _scheduleStatus!.isOpen;
    final closesAt = _scheduleStatus!.closesAt ?? '';
    final nextOpeningAt = _scheduleStatus!.nextOpeningAt ?? '';

    final bgColor = isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final borderColor = isOpen ? Colors.green.shade400 : Colors.amber.shade400;
    final textColor = isOpen ? Colors.green.shade900 : Colors.brown.shade800;

    final String text = isOpen
        ? (closesAt.isNotEmpty ? l10n.sortieEnCours(closesAt) : l10n.enDirect)
        : (nextOpeningAt.isNotEmpty ? l10n.sortieCommenceA(nextOpeningAt) : l10n.sortieFermee);

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 12.0),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.check_circle_outline : Icons.access_time_rounded,
            color: textColor,
            size: 20,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
