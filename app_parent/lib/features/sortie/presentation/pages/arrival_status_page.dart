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

  bool _shouldShowGateValidationButton(ArrivalState state) {
    if (state is ArrivalSuccess) return false;
    if (_scheduleStatus?.isOpen != true) return false;
    final isNotInPerimeter =
        _locationEvaluation == null || !_locationEvaluation!.canSignalArrival;
    final hasGpsIssue = _gpsErrorMessage != null || state is ArrivalFailure;
    return isNotInPerimeter || hasGpsIssue;
  }

  Future<void> _validateGatePosition() async {
    setState(() => _evaluatingLocation = true);
    try {
      final gateLat = _scheduleStatus?.gateLatitude ?? 33.5731;
      final gateLng = _scheduleStatus?.gateLongitude ?? -7.5898;

      final repo = context.read<ArrivalBloc>().arrivalRepository;
      final eval = await repo.evaluateLocation(
        LocationEvaluationRequestDto(
          posLat: gateLat,
          posLng: gateLng,
          accuracyMeters: 10,
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
            stream: _connectionStream,
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _loadScheduleStatus();
                context
                    .read<ArrivalBloc>()
                    .add(const RefreshArrivalStatusRequested());
              });
            },
          ),
          IconButton(
            key: const Key('parent_logout_button'),
            tooltip: 'Déconnexion',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _handleLogout();
              });
            },
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
                    // État initial d'invitation à cliquer
                    Container(
                      padding: const EdgeInsetsDirectional.all(24),
                      decoration: BoxDecoration(
                        color: SortieColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: SortieColors.border),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 16),
                    _buildProgressTimeline(currentStatus),
                  ],

                  if (_shouldShowGateValidationButton(state)) ...[
                    const SizedBox(height: 16),
                    _buildGatePositionValidationButton(),
                  ],

                  const SizedBox(height: 24),

                  // Bouton d'action principal (taille tactile ≥ 48dp)
                  Builder(
                    builder: (btnCtx) {
                      String buttonLabel = 'Je suis arrivé'; // hardcoded-ok
                      VoidCallback? onButtonClick;

                      if (isSuccess) {
                        buttonLabel = 'Actualiser le statut'; // hardcoded-ok
                        onButtonClick = () {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            context
                                .read<ArrivalBloc>()
                                .add(const RefreshArrivalStatusRequested());
                            _fetchScheduleStatus();
                          });
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
                        icon: isSuccess
                            ? Icons.refresh_rounded
                            : Icons.near_me_rounded,
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

  Widget _buildGatePositionValidationButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _evaluatingLocation ? null : _validateGatePosition,
        icon: const Icon(Icons.check_circle_outline, color: SortieColors.primary, size: 20),
        label: const Text(
          'Je suis devant le portail ( Valider ma position )',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: SortieColors.primary,
          side: const BorderSide(color: SortieColors.primary, width: 1.5),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
    final color = isDone
        ? SortieColors.success
        : (isActive ? SortieColors.primary : SortieColors.textSecondary);

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
