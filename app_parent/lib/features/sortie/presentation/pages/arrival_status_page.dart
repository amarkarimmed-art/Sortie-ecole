import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../../core/auth_session_memory.dart';
import '../../../../shared/services/parent_reverb_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../bloc/arrival_bloc.dart';
import '../bloc/arrival_event.dart';
import '../bloc/arrival_state.dart';
import '../widgets/arrival_status_badge.dart';

/// Page principale de statut et de signalement d'arrivée (F03).
///
/// Interface responsive et bilingue (FR/AR) avec support complet RTL,
/// cibles tactiles ≥ 48dp, indicateur temps réel Laravel Reverb et
/// progression visuelle des 4 étapes de sortie de l'élève.
class ArrivalStatusPage extends StatefulWidget {
  final ParentReverbService? reverbService;

  const ArrivalStatusPage({
    super.key,
    this.reverbService,
  });

  @override
  State<ArrivalStatusPage> createState() => _ArrivalStatusPageState();
}

class _ArrivalStatusPageState extends State<ArrivalStatusPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _schoolName;
  String? _schoolLogo;
  ParentReverbService? _reverbService;
  StreamSubscription? _statusSubscription;
  bool _ownsReverbService = false;

  @override
  void initState() {
    super.initState();
    _loadSchoolBranding();
    _initReverbService();
  }

  Future<void> _loadSchoolBranding() async {
    try {
      final name = AuthSessionMemory.schoolName ??
          await _secureStorage.read(key: 'auth_school_name');
      final logo = AuthSessionMemory.schoolLogo ??
          await _secureStorage.read(key: 'auth_school_logo');
      if (mounted) {
        setState(() {
          _schoolName = name;
          _schoolLogo = logo;
        });
      }
    } catch (_) {}
  }

  void _initReverbService() {
    if (widget.reverbService != null) {
      _reverbService = widget.reverbService;
      _ownsReverbService = false;
    } else {
      final token = AuthSessionMemory.token;
      final schoolId = AuthSessionMemory.schoolId;
      final userId = AuthSessionMemory.userId;

      if (schoolId != null && userId != null) {
        _ownsReverbService = true;
        _reverbService = ParentReverbService(
          schoolId: schoolId,
          userId: userId,
          arrivalRepository: context.read<ArrivalBloc>().arrivalRepository,
        );
        _reverbService?.connect(authToken: token);
      }
    }

    _statusSubscription = _reverbService?.statusUpdatesStream.listen((data) {
      final status = data['status'] as String?;
      final childName = data['child_name'] as String?;
      if (status != null && mounted) {
        context.read<ArrivalBloc>().add(
              ArrivalRealtimeStatusUpdated(status, childName: childName),
            );
      }
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    if (_ownsReverbService) {
      _reverbService?.dispose();
    }
    super.dispose();
  }

  void _handleLogout() {
    try {
      context.read<AuthBloc>().add(const LogoutRequested());
    } catch (_) {}

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.school, size: 24),
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
                _schoolName ?? "Sortie d'école",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Indicateur WebSocket temps réel (En direct / Synchronisation...)
          StreamBuilder<bool>(
            key: const Key('parent_reverb_status_indicator'),
            stream: _reverbService?.connectionStream,
            initialData: _reverbService?.isConnected ?? false,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.wifi : Icons.wifi_off,
                      size: 18,
                      color: isConnected ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4.0),
                    Text(
                      isConnected ? 'En direct' : 'Synchronisation...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConnected ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              context
                  .read<ArrivalBloc>()
                  .add(const RefreshArrivalStatusRequested());
            },
          ),
          IconButton(
            key: const Key('parent_logout_button'),
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _handleLogout,
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
            // Affichage de l'erreur dans un SnackBar sans JAMAIS déconnecter automatiquement
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: SortieColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading =
              state is ArrivalLocating || state is ArrivalSubmitting;
          final isSuccess = state is ArrivalSuccess;
          final currentStatus = isSuccess ? state.currentStatus : '';

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  // En-tête informatif avec nom et logo de l'école
                  Card(
                    elevation: 0,
                    color: SortieColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: SortieColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(16.0),
                      child: Row(
                        children: [
                          if (_schoolLogo != null && _schoolLogo!.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _schoolLogo!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.school_rounded,
                                  size: 36,
                                  color: SortieColors.primary,
                                ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.school_rounded,
                              size: 36,
                              color: SortieColors.primary,
                            ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _schoolName ?? 'Portail de sortie',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: SortieColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
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
                  const SizedBox(height: 20),

                  // Affichage dynamique des badges d'état
                  if (state is! ArrivalInitial)
                    ArrivalStatusBadge(
                      state: state,
                      onRetry: () {
                        context
                            .read<ArrivalBloc>()
                            .add(const SignalArrivalRequested());
                      },
                      onRefreshLocation: () {
                        context
                            .read<ArrivalBloc>()
                            .add(const SignalArrivalRequested());
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

                  // Progression en temps réel des 4 étapes de sortie
                  if (isSuccess) ...[
                    const SizedBox(height: 20),
                    _buildProgressTimeline(currentStatus),
                  ],

                  const SizedBox(height: 32),

                  // Bouton d'action principal (taille tactile ≥ 48dp)
                  SortiePrimaryButton(
                    label:
                        isSuccess ? 'Actualiser le statut' : 'Je suis arrivé',
                    icon: isSuccess
                        ? Icons.refresh_rounded
                        : Icons.near_me_rounded,
                    isLoading: isLoading,
                    onPressed: () {
                      if (isSuccess) {
                        context
                            .read<ArrivalBloc>()
                            .add(const RefreshArrivalStatusRequested());
                      } else {
                        context
                            .read<ArrivalBloc>()
                            .add(const SignalArrivalRequested());
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressTimeline(String currentStatus) {
    final normalized = currentStatus.toLowerCase();
    final steps = [
      {
        'title': "Arrivée signalée (en attente d'appel)",
        'active': [
          'requested',
          'pending_agent_confirmation',
          'processed',
          'class_notified',
          'on_the_way',
          'handed_over'
        ].contains(normalized),
        'done': ['class_notified', 'on_the_way', 'handed_over']
            .contains(normalized),
        'icon': Icons.near_me_rounded,
      },
      {
        'title': "Classe prévenue — Votre enfant est appelé",
        'active': ['class_notified', 'on_the_way', 'handed_over']
            .contains(normalized),
        'done': ['on_the_way', 'handed_over'].contains(normalized),
        'icon': Icons.campaign_rounded,
      },
      {
        'title': "Enfant en chemin vers le portail",
        'active': ['on_the_way', 'handed_over'].contains(normalized),
        'done': ['handed_over'].contains(normalized),
        'icon': Icons.directions_walk_rounded,
      },
      {
        'title': "Enfant remis — Bonne rentrée !",
        'active': normalized == 'handed_over',
        'done': normalized == 'handed_over',
        'icon': Icons.sentiment_very_satisfied_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SortieColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SortieColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progression de la sortie',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: SortieColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < steps.length; i++)
            _buildStepRow(
              title: steps[i]['title'] as String,
              isActive: steps[i]['active'] as bool,
              isDone: steps[i]['done'] as bool,
              icon: steps[i]['icon'] as IconData,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String title,
    required bool isActive,
    required bool isDone,
    required IconData icon,
    required bool isLast,
  }) {
    final color = isDone
        ? SortieColors.success
        : (isActive ? SortieColors.primary : SortieColors.textSecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.12) : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? color : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Icon(
                isDone ? Icons.check : icon,
                size: 16,
                color: isActive ? color : Colors.grey.shade400,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: isDone ? SortieColors.success : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive
                    ? SortieColors.textPrimary
                    : SortieColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
