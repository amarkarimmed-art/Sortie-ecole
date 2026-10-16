import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/reverb_service.dart';
import '../data/surveillance_repository.dart';
import '../domain/pickup_request_called_event.dart';
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

  const SurveillanceScreen({
    super.key = const Key('ecran_surveillance'),
    this.repository,
    this.reverbService,
  });

  @override
  State<SurveillanceScreen> createState() => _SurveillanceScreenState();
}

class _SurveillanceScreenState extends State<SurveillanceScreen> {
  late final SurveillanceRepository _repository;
  bool _ownsRepository = false;

  @override
  void initState() {
    super.initState();
    if (widget.repository != null) {
      _repository = widget.repository!;
    } else {
      final reverb = widget.reverbService ??
          ReverbService(
            baseUrl: 'ws://localhost:8080',
            schoolId: 'default-school',
          );
      _repository = SurveillanceRepository(
        baseUrl: 'http://localhost:8000',
        schoolId: 'default-school',
        reverbService: reverb,
      );
      _ownsRepository = true;
    }

    _repository.init();
    _repository.loadInitialQueue();
  }

  @override
  void dispose() {
    if (_ownsRepository) {
      _repository.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ecranSurveillanceTitre),
        actions: [
          // Indicateur de resynchronisation / état WS (CA15)
          StreamBuilder<void>(
            key: const Key('ecran_surveillance_resync'),
            stream: _repository.reverbService.resyncStream,
            builder: (context, snapshot) {
              final isConnected = _repository.reverbService.isConnected;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 16.0),
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
                          onPressed: () => _repository.loadInitialQueue(),
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
