import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../bloc/arrival_bloc.dart';
import '../bloc/arrival_event.dart';
import '../bloc/arrival_state.dart';
import '../widgets/arrival_status_badge.dart';

/// Page principale de statut et de signalement d'arrivée (F03).
///
/// Interface responsive et bilingue (FR/AR) avec support complet RTL,
/// cibles tactiles ≥ 48dp et badges dynamiques hautement contrastés.
class ArrivalStatusPage extends StatelessWidget {
  const ArrivalStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sortie d\'école'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context.read<ArrivalBloc>().add(const RefreshArrivalStatusRequested());
            },
          ),
        ],
      ),
      body: BlocConsumer<ArrivalBloc, ArrivalState>(
        listener: (context, state) {
          if (state is ArrivalSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Arrivée enregistrée avec succès !'),
                backgroundColor: SortieColors.success,
              ),
            );
          } else if (state is ArrivalFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: SortieColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is ArrivalLocating || state is ArrivalSubmitting;
          final isSuccess = state is ArrivalSuccess;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // En-tête informatif
                  Card(
                    elevation: 0,
                    color: SortieColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: SortieColors.border),
                    ),
                    child: const Padding(
                      padding: EdgeInsetsDirectional.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school_rounded,
                            size: 36,
                            color: SortieColors.primary,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Portail de sortie',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: SortieColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Signalez votre arrivée dès que vous êtes à proximité de l\'école.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: SortieColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Affichage dynamique des badges d'état
                  if (state is! ArrivalInitial)
                    ArrivalStatusBadge(
                      state: state,
                      onRetry: () {
                        context.read<ArrivalBloc>().add(const SignalArrivalRequested());
                      },
                      onRefreshLocation: () {
                        context.read<ArrivalBloc>().add(const SignalArrivalRequested());
                      },
                    )
                  else
                    // État initial d'invitation à cliquer
                    Container(
                      padding: const EdgeInsetsDirectional.all(24),
                      decoration: BoxDecoration(
                        color: SortieColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SortieColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 48,
                            color: SortieColors.primaryLight,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Vous êtes devant l\'école ?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: SortieColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Appuyez sur le bouton ci-dessous pour avertir l\'équipe scolaire de votre présence.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: SortieColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // Bouton d'action principal (taille tactile ≥ 48dp)
                  SortiePrimaryButton(
                    label: isSuccess ? 'Actualiser le statut' : 'Je suis arrivé',
                    icon: isSuccess ? Icons.refresh_rounded : Icons.near_me_rounded,
                    isLoading: isLoading,
                    onPressed: () {
                      context.read<ArrivalBloc>().add(const SignalArrivalRequested());
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
