import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../core/auth_session_memory.dart';
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
  late SurveillanceRepository _repository;
  bool _ownsRepository = false;
  StreamSubscription<PickupRequestDepartedEvent>? _departedSubscription;
  StreamSubscription<ArrivalSignaledEvent>? _newArrivalSubscription;

  String? _effectiveToken;
  String? _effectiveSchoolId;
  String? _schoolName;
  String? _schoolLogo;
  ScheduleStatusDto? _scheduleStatus;
  Timer? _schedulePollingTimer;
  Timer? _queuePollingTimer;

  @override
  void initState() {
    super.initState();
    _effectiveToken = widget.token ?? AuthSessionMemory.token;
    _effectiveSchoolId = widget.schoolId ?? AuthSessionMemory.schoolId ?? 'a308ef34-99df-4f01-ab91-8c3eb47bf72a';
    _schoolName = widget.schoolName ?? AuthSessionMemory.schoolName;
    _schoolLogo = widget.schoolLogo ?? AuthSessionMemory.schoolLogo;

    _initRepository(
      schoolId: _effectiveSchoolId!,
      token: _effectiveToken,
    );

    _loadStorageInfo();

    _loadScheduleStatus();
    _schedulePollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadScheduleStatus(),
    );

    // Polling régulier de la file d'attente toutes les 5s (garantit l'arrivée immédiate de la carte même en cas d'intermittence WebSocket)
    _queuePollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (mounted) {
          _repository.reloadFromQueue(token: _effectiveToken ?? widget.token);
        }
      },
    );
  }

  void _initRepository({required String schoolId, String? token}) {
    if (widget.repository != null) {
      _repository = widget.repository!;
      _ownsRepository = false;
    } else {
      if (_ownsRepository) {
        _departedSubscription?.cancel();
        _newArrivalSubscription?.cancel();
        _repository.reverbService.disconnect();
        _repository.dispose();
        _repository.reverbService.dispose();
      }
      final reverb = widget.reverbService ??
          ReverbService(
            baseUrl: 'ws://127.0.0.1:8080',
            schoolId: schoolId,
          );
      _repository = SurveillanceRepository(
        baseUrl: 'http://127.0.0.1:8000',
        schoolId: schoolId,
        reverbService: reverb,
      );
      _ownsRepository = true;
    }

    _repository.init();
    _repository.loadInitialQueue(token: token ?? _effectiveToken ?? widget.token);
    _repository.reverbService.connect(authToken: token ?? _effectiveToken ?? widget.token);

    _departedSubscription?.cancel();
    _departedSubscription =
        _repository.reverbService.departedEvents.listen((event) {
      if (mounted) {
        setState(() {
          _repository.updateItemStatus(event.requestId, 'on_the_way');
        });
      }
    });

    _newArrivalSubscription?.cancel();
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
      final sId = await storage.read(key: 'auth_school_id');
      final name = await storage.read(key: 'auth_school_name');
      final logo = await storage.read(key: 'auth_school_logo');

      bool needsReinit = false;

      if (mounted) {
        setState(() {
          if ((_effectiveToken == null || _effectiveToken!.isEmpty) && token != null && token.isNotEmpty) {
            _effectiveToken = token;
            needsReinit = true;
          }
          if ((_effectiveSchoolId == null || _effectiveSchoolId!.isEmpty || _effectiveSchoolId == 'a3000c08-8f84-4bff-8c3f-81ebf2b014dd') &&
              sId != null &&
              sId.isNotEmpty) {
            _effectiveSchoolId = sId;
            needsReinit = true;
          }
          if (_schoolName == null || _schoolName!.isEmpty) {
            _schoolName = name;
          }
          if (_schoolLogo == null || _schoolLogo!.isEmpty) {
            _schoolLogo = logo;
          }
        });

        if (needsReinit && widget.repository == null) {
          _initRepository(
            schoolId: _effectiveSchoolId ?? 'a308ef34-99df-4f01-ab91-8c3eb47bf72a',
            token: _effectiveToken,
          );
        } else {
          _repository.loadInitialQueue(token: _effectiveToken ?? widget.token);
        }

        _loadScheduleStatus();
      }
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    final token = _effectiveToken ?? widget.token;
    AuthSessionMemory.clear();
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
    _queuePollingTimer?.cancel();
    _queuePollingTimer = null;
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
      backgroundColor: SortieColors.background,
      appBar: AppBar(
        backgroundColor: SortieColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_schoolLogo != null && _schoolLogo!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    _schoolLogo!,
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.school_rounded, size: 20, color: SortieColors.primary),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 6.0),
                child: Icon(Icons.school_rounded, size: 20, color: SortieColors.primary),
              ),
            Flexible(
              child: Text(
                _schoolName ?? l10n.ecranSurveillanceTitre,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: SortieColors.textPrimary,
                ),
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
              final bgColor = isConnected ? const Color(0xFFE6F4EA) : const Color(0xFFFEF7E0);
              final fgColor = isConnected ? const Color(0xFF137333) : const Color(0xFFB06000);
              return Container(
                margin: const EdgeInsetsDirectional.only(end: 4.0),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: fgColor.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: fgColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      isConnected ? l10n.enDirect : l10n.reconnexionEnCours,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, color: SortieColors.textSecondary),
            onPressed: () {
              _loadScheduleStatus();
              _repository.loadInitialQueue(token: _effectiveToken ?? widget.token);
            },
          ),
          IconButton(
            key: const Key('surveillance_btn_logout'),
            tooltip: l10n.deconnexion,
            iconSize: 20,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.logout_rounded, color: SortieColors.textSecondary),
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
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: 14.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD3E3FD),
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10.0),
                            Text(
                              l10n.miseAJourEnCours,
                              style: const TextStyle(
                                color: Color(0xFF041E49),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (grouped.isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 48.0, start: 8.0, end: 8.0),
                        child: Center(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsetsDirectional.all(32.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE6F4EA),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 42,
                                    color: Color(0xFF137333),
                                  ),
                                ),
                                const SizedBox(height: 18.0),
                                Text(
                                  l10n.aucunEleveAppele,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: SortieColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
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

    final bgColor = isOpen ? const Color(0xFFE6F4EA) : const Color(0xFFFEF7E0);
    final borderColor = isOpen ? const Color(0xFFCEEAD6) : const Color(0xFFFEEFC3);
    final textColor = isOpen ? const Color(0xFF137333) : const Color(0xFFB06000);
    final iconColor = textColor;

    final String text = isOpen
        ? (closesAt.isNotEmpty ? l10n.sortieEnCours(closesAt) : l10n.enDirect)
        : (nextOpeningAt.isNotEmpty ? l10n.sortieCommenceA(nextOpeningAt) : l10n.sortieFermee);

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 14.0),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen ? Icons.check_circle_rounded : Icons.access_time_filled_rounded,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
