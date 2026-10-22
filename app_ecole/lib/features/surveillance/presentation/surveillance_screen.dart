import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  String? _effectiveToken;
  String? _schoolName;
  String? _schoolLogo;

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

    // Écouter les événements pickup.departed pour évaporer la carte en temps réel
    _departedSubscription =
        _repository.reverbService.departedEvents.listen((event) {
      if (mounted) {
        setState(() {
          _repository.removeDeparted(event.requestId);
        });
      }
    });
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
    _departedSubscription?.cancel();
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

                if (grouped.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.aucunEleveAppele,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsetsDirectional.all(16.0),
                  children: [
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
}
