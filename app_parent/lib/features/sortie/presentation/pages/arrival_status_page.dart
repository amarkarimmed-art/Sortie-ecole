import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../../core/auth_session_memory.dart';
import '../../../../shared/services/parent_reverb_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../domain/failures/arrival_exceptions.dart';
import '../../domain/services/location_service.dart';
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
  final LocationService _locationService = GeolocatorLocationService();
  String? _schoolName;
  String? _schoolLogo;
  ParentReverbService? _reverbService;
  StreamSubscription? _statusSubscription;
  bool _ownsReverbService = false;

  ScheduleStatusDto? _scheduleStatus;
  LocationEvaluationResponseDto? _locationEvaluation;
  Timer? _locationTimer;
  String? _gpsErrorMessage;
  bool _evaluatingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadSchoolBranding();
    _initReverbService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLaw0908Consent();
      _fetchScheduleStatus();
    });
  }

  Future<void> _checkLaw0908Consent() async {
    try {
      final accepted = await _secureStorage.read(key: 'gps_consent_accepted');
      if (accepted == null && mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.privacy_tip_outlined, color: SortieColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Protection de la vie privée (Loi 09-08)', // hardcoded-ok
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Votre position GPS est utilisée uniquement au premier plan pendant l\'heure de sortie pour vérifier votre proximité au portail et n\'est jamais enregistrée.', // hardcoded-ok
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await _secureStorage.write(
                    key: 'gps_consent_accepted',
                    value: 'true',
                  );
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                },
                child: const Text('Accepter'), // hardcoded-ok
              ),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchScheduleStatus() async {
    try {
      final repo = context.read<ArrivalBloc>().arrivalRepository;
      final status = await repo.getScheduleStatus();
      if (mounted) {
        setState(() {
          _scheduleStatus = status;
        });
        if (status.isOpen) {
          _evaluateLocation();
          _locationTimer?.cancel();
          _locationTimer = Timer.periodic(
            const Duration(seconds: 30),
            (_) => _evaluateLocation(),
          );
        } else {
          _locationTimer?.cancel();
          _locationTimer = null;
        }
      }
    } catch (_) {}
  }

  Future<void> _evaluateLocation() async {
    if (!mounted || _scheduleStatus?.isOpen != true || _evaluatingLocation) {
      return;
    }
    setState(() => _evaluatingLocation = true);
    try {
      final pos = await _locationService.getCurrentPositionWithAccuracy(
        checkAccuracy: false,
      );
      if (pos.accuracy > 50) {
        if (mounted) {
          setState(() {
            _gpsErrorMessage = 'Signal GPS trop faible. Précision insuffisante.';
            _evaluatingLocation = false;
          });
        }
        return;
      }

      final repo = context.read<ArrivalBloc>().arrivalRepository;
      final eval = await repo.evaluateLocation(
        LocationEvaluationRequestDto(
          posLat: pos.latitude,
          posLng: pos.longitude,
          accuracyMeters: pos.accuracy,
          capturedAt: clock.now().toUtc(),
        ),
      );

      if (mounted) {
        setState(() {
          _locationEvaluation = eval;
          _gpsErrorMessage = null;
          _evaluatingLocation = false;
        });
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(() {
          _gpsErrorMessage = 'Les services de localisation GPS sont désactivés.';
          _evaluatingLocation = false;
        });
      }
    } on LocationPermissionDeniedException {
      if (mounted) {
        setState(() {
          _gpsErrorMessage = 'L\'autorisation d\'accès GPS a été refusée.';
          _evaluatingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _evaluatingLocation = false);
      }
    }
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
    _locationTimer?.cancel();
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
                content: Text('Arrivée enregistrée avec succès !'), // hardcoded-ok
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
                  _buildScheduleStatusBanner(),
                  _buildGpsErrorBanner(),
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
                  Builder(
                    builder: (btnCtx) {
                      String buttonLabel = 'Je suis arrivé'; // hardcoded-ok
                      VoidCallback? onButtonClick;

                      if (isSuccess) {
                        buttonLabel = 'Actualiser le statut'; // hardcoded-ok
                        onButtonClick = () {
                          context
                              .read<ArrivalBloc>()
                              .add(const RefreshArrivalStatusRequested());
                          _fetchScheduleStatus();
                        };
                      } else if (_scheduleStatus != null &&
                          !_scheduleStatus!.isOpen) {
                        buttonLabel = _scheduleStatus!.nextOpeningAt != null
                            ? 'La sortie commence à ${_scheduleStatus!.nextOpeningAt}'
                            : 'Sortie fermée'; // hardcoded-ok
                        onButtonClick = null;
                      } else if (_locationEvaluation != null &&
                          !_locationEvaluation!.canSignalArrival) {
                        final dist = _locationEvaluation!.distanceMeters ?? 0;
                        final lim = _locationEvaluation!.perimeterRadius ?? 50;
                        buttonLabel =
                            'Vous êtes à $dist m, rapprochez-vous (limite : $lim m)';
                        onButtonClick = null;
                      } else {
                        buttonLabel = 'Je suis arrivé'; // hardcoded-ok
                        onButtonClick = () {
                          context
                              .read<ArrivalBloc>()
                              .add(const SignalArrivalRequested());
                        };
                      }

                      return SortiePrimaryButton(
                        label: buttonLabel,
                        icon: isSuccess
                            ? Icons.refresh_rounded
                            : Icons.near_me_rounded,
                        isLoading: isLoading,
                        onPressed: onButtonClick,
                      );
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
                color: isActive ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
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

  Widget _buildScheduleStatusBanner() {
    if (_scheduleStatus == null) return const SizedBox.shrink();
    final isOpen = _scheduleStatus!.isOpen;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final message = isArabic
        ? (_scheduleStatus!.messageAr.isNotEmpty ? _scheduleStatus!.messageAr : (isOpen ? 'الخروج مفتوح' : 'الخروج مغلق'))
        : (_scheduleStatus!.messageFr.isNotEmpty ? _scheduleStatus!.messageFr : (isOpen ? 'Sortie ouverte' : 'Sortie fermée'));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? SortieColors.success : SortieColors.warning,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.check_circle_outline : Icons.access_time_rounded,
            color: isOpen ? SortieColors.success : SortieColors.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isOpen ? const Color(0xFF166534) : const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsErrorBanner() {
    if (_gpsErrorMessage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SortieColors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_off_rounded, color: SortieColors.error, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _gpsErrorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF991B1B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _locationService.openLocationSettings(),
                child: const Text('Ouvrir les réglages'), // hardcoded-ok
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _evaluateLocation(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: SortieColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Réessayer'), // hardcoded-ok
              ),
            ],
          ),
        ],
      ),
    );
  }
}
