import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sortie_models/sortie_models.dart';
import 'package:sortie_ui/sortie_ui.dart';

import '../../../../core/auth_session_memory.dart';
import '../../../../shared/services/parent_reverb_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
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
  Stream<bool>? _connectionStream;
  bool _ownsReverbService = false;
  bool _isConsentDialogShowing = false;
  bool _hasCheckedConsent = false;

  ScheduleStatusDto? _scheduleStatus;
  LocationEvaluationResponseDto? _locationEvaluation;
  Timer? _locationTimer;
  Timer? _schedulePollingTimer;
  String? _gpsErrorMessage;
  bool _evaluatingLocation = false;
  bool _isFetchingSchedule = false;
  bool _locationEvaluatedOnce = false;

  @override
  void initState() {
    super.initState();
    _schoolName = AuthSessionMemory.schoolName;
    _schoolLogo = AuthSessionMemory.schoolLogo;
    _initReverbService();
    _loadSchoolBranding();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkLaw0908Consent();
      _loadScheduleStatus();
    });
    _schedulePollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadScheduleStatus(),
    );
  }

  Future<void> _checkLaw0908Consent() async {
    if (!mounted || _isConsentDialogShowing || _hasCheckedConsent) return;
    _hasCheckedConsent = true;
    try {
      final accepted = await _secureStorage.read(key: 'gps_consent_accepted');
      if (accepted == null && mounted && !_isConsentDialogShowing) {
        _isConsentDialogShowing = true;
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
        _isConsentDialogShowing = false;
      }
    } catch (_) {
      _isConsentDialogShowing = false;
    }
  }

  Future<void> _fetchScheduleStatus() async {
    if (!mounted || _isFetchingSchedule) return;
    _isFetchingSchedule = true;
    try {
      final repo = context.read<ArrivalBloc>().arrivalRepository;
      final status = await repo.getScheduleStatus();
      if (mounted) {
        final wasOpen = _scheduleStatus?.isOpen ?? false;
        final statusChanged = _scheduleStatus?.isOpen != status.isOpen ||
            _scheduleStatus?.nextOpeningAt != status.nextOpeningAt ||
            _scheduleStatus?.messageFr != status.messageFr ||
            _scheduleStatus?.messageAr != status.messageAr;

        if (statusChanged) {
          setState(() {
            _scheduleStatus = status;
          });
        } else {
          _scheduleStatus = status;
        }

        if (status.isOpen) {
          if (!wasOpen || !_locationEvaluatedOnce) {
            _locationEvaluatedOnce = true;
            _evaluateLocation();
          }
          if (_locationTimer == null || !_locationTimer!.isActive) {
            _locationTimer?.cancel();
            _locationTimer = Timer.periodic(
              const Duration(seconds: 30),
              (_) => _evaluateLocation(),
            );
          }
        } else {
          _locationEvaluatedOnce = false;
          _locationTimer?.cancel();
          _locationTimer = null;
        }
      }
    } catch (_) {
    } finally {
      _isFetchingSchedule = false;
    }
  }

  Future<void> _loadScheduleStatus() async {
    await _fetchScheduleStatus();
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
      if (!kIsWeb && pos.accuracy > 50) {
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
      final schoolId = AuthSessionMemory.schoolId ??
          await _secureStorage.read(key: 'auth_school_id');
      final userId = AuthSessionMemory.userId ??
          await _secureStorage.read(key: 'auth_user_id');
      final token = AuthSessionMemory.token ??
          await _secureStorage.read(key: 'auth_token');

      if (!mounted) return;

      bool needsSetState = false;
      if (_schoolName != name || _schoolLogo != logo) {
        _schoolName = name;
        _schoolLogo = logo;
        needsSetState = true;
      }

      if (_reverbService == null && schoolId != null && userId != null) {
        _ownsReverbService = true;
        final service = ParentReverbService(
          schoolId: schoolId,
          userId: userId,
          arrivalRepository: context.read<ArrivalBloc>().arrivalRepository,
        );
        _reverbService = service;
        _connectionStream = service.connectionStream;
        _statusSubscription?.cancel();
        _statusSubscription = service.statusUpdatesStream.listen((data) {
          final status = data['status'] as String?;
          final childName = data['child_name'] as String?;
          if (status != null && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<ArrivalBloc>().add(
                      ArrivalRealtimeStatusUpdated(status, childName: childName),
                    );
              }
            });
          }
        });
        service.connect(authToken: token);
        needsSetState = true;
      }

      if (needsSetState && mounted) {
        setState(() {});
      }
    } catch (_) {}
  }

  void _initReverbService() {
    if (widget.reverbService != null) {
      _reverbService = widget.reverbService;
      _ownsReverbService = false;
      _connectionStream = _reverbService?.connectionStream;
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
        _connectionStream = _reverbService?.connectionStream;
        _reverbService?.connect(authToken: token);
      }
    }

    _statusSubscription?.cancel();
    _statusSubscription = _reverbService?.statusUpdatesStream.listen((data) {
      final status = data['status'] as String?;
      final childName = data['child_name'] as String?;
      if (status != null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<ArrivalBloc>().add(
                  ArrivalRealtimeStatusUpdated(status, childName: childName),
                );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _schedulePollingTimer?.cancel();
    _schedulePollingTimer = null;
    _locationTimer?.cancel();
    _locationTimer = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    if (_ownsReverbService) {
      _reverbService?.dispose();
    }
    super.dispose();
  }

  void _handleLogout() {
    try {
      context.read<AuthBloc>().add(const LogoutRequested());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_schoolLogo != null && _schoolLogo!.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    _schoolLogo!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.school_rounded, size: 24, color: SortieColors.primary),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsetsDirectional.only(end: 10.0),
                child: Icon(Icons.school_rounded, size: 24, color: SortieColors.primary),
              ),
            Flexible(
              child: Text(
                _schoolName ?? "Sortie d'école",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Indicateur WebSocket temps réel (En direct / Synchronisation...)
          StreamBuilder<bool>(
            key: const Key('parent_reverb_status_indicator'),
            stream: _connectionStream,
            initialData: _reverbService?.isConnected ?? false,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Container(
                margin: const EdgeInsetsDirectional.only(end: 8.0),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFFE6F4EA) : const Color(0xFFFEF7E0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isConnected ? const Color(0xFF137333) : const Color(0xFFB06000),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      isConnected ? 'En direct' : 'Synchronisation...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConnected ? const Color(0xFF137333) : const Color(0xFFB06000),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Container(
            margin: const EdgeInsetsDirectional.only(end: 6.0),
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EEF5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh_rounded, size: 20, color: SortieColors.textPrimary),
              onPressed: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _loadScheduleStatus();
                  context
                      .read<ArrivalBloc>()
                      .add(const RefreshArrivalStatusRequested());
                });
              },
            ),
          ),
          Container(
            margin: const EdgeInsetsDirectional.only(end: 12.0),
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EEF5),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              key: const Key('parent_logout_button'),
              padding: EdgeInsets.zero,
              tooltip: 'Déconnexion',
              icon: const Icon(Icons.logout_rounded, size: 18, color: SortieColors.textPrimary),
              onPressed: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _handleLogout();
                });
              },
            ),
          ),
        ],
      ),
      body: BlocConsumer<ArrivalBloc, ArrivalState>(
        listenWhen: (previous, current) {
          if (current is ArrivalSuccess) {
            return previous is ArrivalSubmitting;
          }
          if (current is ArrivalFailure) {
            return previous != current;
          }
          return false;
        },
        listener: (context, state) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (state is ArrivalSuccess) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text('Arrivée enregistrée avec succès !'), // hardcoded-ok
                  backgroundColor: SortieColors.success,
                  duration: Duration(seconds: 3),
                ),
              );
            } else if (state is ArrivalFailure) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: SortieColors.error,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          });
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildScheduleStatusBanner(),
                  _buildGpsErrorBanner(),
                  // En-tête informatif avec nom et logo de l'école (Style M3)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: SortieColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsetsDirectional.all(18.0),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: SortieColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: (_schoolLogo != null && _schoolLogo!.isNotEmpty)
                                ? Image.network(
                                    _schoolLogo!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.school_rounded,
                                      size: 26,
                                      color: SortieColors.primary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.school_rounded,
                                    size: 26,
                                    color: SortieColors.primary,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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
                              const SizedBox(height: 3),
                              const Text(
                                'Signalez votre arrivée dès que vous êtes à proximité de l\'école.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: SortieColors.textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
                    // État initial d'invitation à cliquer (Halo M3)
                    Container(
                      padding: const EdgeInsetsDirectional.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: SortieColors.border),
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
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: SortieColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.touch_app_rounded,
                              size: 38,
                              color: SortieColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Vous êtes devant l\'école ?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                              color: SortieColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Appuyez sur le bouton ci-dessous pour avertir l\'équipe scolaire de votre présence.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: SortieColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Progression en temps réel des 4 étapes de sortie
                  if (isSuccess) ...[
                    const SizedBox(height: 16),
                    _buildProgressTimeline(currentStatus),
                  ],

                  const SizedBox(height: 24),

                  // Bouton d'action principal (taille tactile ≥ 48dp)
                  Builder(
                    builder: (btnCtx) {
                      String buttonLabel = 'Je suis arrivé'; // hardcoded-ok
                      VoidCallback? onButtonClick;
                      IconData buttonIcon = Icons.near_me_rounded;

                      final isHandedOver = currentStatus == 'handed_over';

                      if (_scheduleStatus != null &&
                          !_scheduleStatus!.isOpen) {
                        buttonLabel = _scheduleStatus!.nextOpeningAt != null
                            ? 'La sortie commence à ${_scheduleStatus!.nextOpeningAt}'
                            : 'Sortie fermée'; // hardcoded-ok
                        buttonIcon = Icons.lock_clock_rounded;
                        onButtonClick = null;
                      } else if (isSuccess && isHandedOver) {
                        buttonLabel = 'Nouvelle sortie (Je suis arrivé)'; // hardcoded-ok
                        buttonIcon = Icons.near_me_rounded;
                        onButtonClick = () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            context
                                .read<ArrivalBloc>()
                                .add(const SignalArrivalRequested());
                          });
                        };
                      } else if (isSuccess) {
                        buttonLabel = 'Actualiser le statut'; // hardcoded-ok
                        buttonIcon = Icons.refresh_rounded;
                        onButtonClick = () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            context
                                .read<ArrivalBloc>()
                                .add(const RefreshArrivalStatusRequested());
                            _fetchScheduleStatus();
                          });
                        };
                      } else if (_locationEvaluation != null &&
                          !_locationEvaluation!.canSignalArrival) {
                        final dist = _locationEvaluation!.distanceMeters ?? 0;
                        final lim = _locationEvaluation!.perimeterRadius ?? 50;
                        buttonLabel =
                            'Vous êtes à $dist m, rapprochez-vous (limite : $lim m)';
                        buttonIcon = Icons.near_me_disabled_rounded;
                        onButtonClick = null;
                      } else {
                        buttonLabel = 'Je suis arrivé'; // hardcoded-ok
                        buttonIcon = Icons.near_me_rounded;
                        onButtonClick = () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            context
                                .read<ArrivalBloc>()
                                .add(const SignalArrivalRequested());
                          });
                        };
                      }

                      return SortiePrimaryButton(
                        label: buttonLabel,
                        icon: buttonIcon,
                        isLoading: isLoading,
                        onPressed: onButtonClick,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
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

    // Progression rigoureuse en 4 étapes
    int activeStepCount = 1;
    if (normalized == 'handed_over') {
      activeStepCount = 4;
    } else if (normalized == 'on_the_way') {
      activeStepCount = 3;
    } else if (normalized == 'class_notified') {
      activeStepCount = 2;
    } else {
      activeStepCount = 1;
    }

    final steps = [
      {
        'title': "Arrivée signalée (en attente d'appel)",
        'active': activeStepCount >= 1,
        'done': activeStepCount > 1,
        'icon': Icons.near_me_rounded,
      },
      {
        'title': "Classe prévenue — Votre enfant est appelé",
        'active': activeStepCount >= 2,
        'done': activeStepCount > 2,
        'icon': Icons.campaign_rounded,
      },
      {
        'title': "Enfant en chemin vers le portail",
        'active': activeStepCount >= 3,
        'done': activeStepCount > 3,
        'icon': Icons.directions_walk_rounded,
      },
      {
        'title': "Enfant remis — Bonne rentrée !",
        'active': activeStepCount >= 4,
        'done': activeStepCount >= 4,
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
        mainAxisSize: MainAxisSize.min,
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
    final color = isActive ? SortieColors.success : SortieColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
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
                isActive
                    ? (isDone ? Icons.check : icon)
                    : Icons.radio_button_unchecked_rounded,
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
      margin: const EdgeInsetsDirectional.only(bottom: 16),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFE6F4EA) : const Color(0xFFFEF7E0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen ? const Color(0xFFCEEAD6) : const Color(0xFFFEEFC3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFFCEEAD6) : const Color(0xFFFEEFC3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen ? Icons.check_circle_rounded : Icons.access_time_rounded,
              color: isOpen ? const Color(0xFF137333) : const Color(0xFFB06000),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isOpen ? const Color(0xFF137333) : const Color(0xFFB06000),
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
        mainAxisSize: MainAxisSize.min,
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
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _locationService.openLocationSettings(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    child: const Text('Ouvrir les réglages'), // hardcoded-ok
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _evaluateLocation();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SortieColors.error,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(64, 48),
                    ),
                    child: const Text('Réessayer'), // hardcoded-ok
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
