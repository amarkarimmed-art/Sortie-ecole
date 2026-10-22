import 'dart:async';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:sortie_models/sortie_models.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/reverb_service.dart';
import '../domain/pickup_request_called_event.dart';
import '../domain/pickup_request_departed_event.dart';
import '../domain/surveillance_item.dart';
import '../domain/surveillance_state.dart';

/// Repository pour l'écran de surveillance (CA11, CA14, CA15).
///
/// Combine les appels REST (GET /queue) et le temps réel WebSocket (Reverb).
class SurveillanceRepository {
  final Dio? _dio;
  final String _baseUrl;
  final String _schoolId;
  final ReverbService _reverbService;

  final StreamController<SurveillanceState> _stateController =
      StreamController<SurveillanceState>.broadcast();

  final StreamController<ArrivalSignaledEvent> _newArrivalAlertController =
      StreamController<ArrivalSignaledEvent>.broadcast();

  final List<SurveillanceItem> _currentItems = [];
  StreamSubscription<PickupRequestCalledEvent>? _calledSubscription;
  StreamSubscription<PickupRequestDepartedEvent>? _departedSubscription;
  StreamSubscription<ArrivalSignaledEvent>? _arrivalSignaledSubscription;
  StreamSubscription<ParentApproachingEvent>? _parentApproachingSubscription;
  StreamSubscription<void>? _resyncSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _fallbackPollingTimer;

  String? _authToken;

  SurveillanceRepository({
    Dio? dio,
    required String baseUrl,
    required String schoolId,
    required ReverbService reverbService,
  })  : _dio = dio ?? (ReverbService.isTestEnvironment ? null : Dio()),
        _baseUrl = baseUrl,
        _schoolId = schoolId,
        _reverbService = reverbService;

  Stream<SurveillanceState> get state => _stateController.stream;
  Stream<ArrivalSignaledEvent> get newArrivalAlerts =>
      _newArrivalAlertController.stream;
  List<SurveillanceItem> get currentItems => List.unmodifiable(_currentItems);
  ReverbService get reverbService => _reverbService;
  String get baseUrl => _baseUrl;
  String get schoolId => _schoolId;

  void init() {
    // Écouter les événements temps réel pickup.called sans polling (CA14)
    _calledSubscription = _reverbService.calledEvents.listen((event) {
      _handleCalledEvent(event);
    });

    // Écouter les départs pour retirer les élèves de la liste locale (B4)
    _departedSubscription = _reverbService.departedEvents.listen((event) {
      _handleDepartedEvent(event);
    });

    // Écouter les arrivées signalées en direct (Étape 7)
    _arrivalSignaledSubscription =
        _reverbService.arrivalSignaledEvents.listen((event) {
      _handleArrivalSignaledEvent(event);
    });

    // Écouter les parents en approche en direct (Étape 7)
    _parentApproachingSubscription =
        _reverbService.parentApproachingEvents.listen((event) {
      _handleParentApproachingEvent(event);
    });

    // Écouter les reconnexions WebSocket pour recharger l'état complet (CA15)
    _resyncSubscription = _reverbService.resyncStream.listen((_) {
      reloadFromQueue(isResync: true);
    });

    // Polling de secours toutes les 10 secondes si la connexion WebSocket est coupée
    _connectionSubscription =
        _reverbService.connectionStream.listen((isConnected) {
      if (!isConnected) {
        _startFallbackPolling();
      } else {
        _stopFallbackPolling();
      }
    });
  }

  void _startFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_reverbService.isConnected) {
        reloadFromQueue();
      }
    });
  }

  void _stopFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
  }

  /// Récupérer le statut des horaires de l'école (Étape 7)
  Future<ScheduleStatusDto?> getScheduleStatus({String? token}) async {
    final dio = _dio;
    if (dio == null) return null;
    try {
      final effectiveToken = token ?? _authToken;
      final headers = <String, dynamic>{
        'Accept': 'application/json',
        if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
      };
      final response = await dio.get(
        '$_baseUrl/api/v1/schools/$_schoolId/schedule-status',
        options: Options(headers: headers),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return ScheduleStatusDto.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Charger la file d'attente initiale depuis GET /schools/{schoolId}/queue.
  Future<void> loadInitialQueue({String? token}) async {
    if (token != null) {
      _authToken = token;
    }
    _stateController.add(const SurveillanceLoading());
    await reloadFromQueue(token: _authToken);
  }

  /// Recharger l'état complet depuis GET /queue (CA15).
  Future<void> reloadFromQueue({String? token, bool isResync = false}) async {
    try {
      final effectiveToken = token ?? _authToken;

      if (isResync && _currentItems.isNotEmpty) {
        _stateController.add(SurveillanceLoaded(
          items: List.from(_currentItems),
          isResyncing: true,
        ));
      }

      if (_dio != null) {
        final headers = <String, dynamic>{
          'Accept': 'application/json',
          if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
        };

        final response = await _dio.get(
          '$_baseUrl/api/v1/schools/$_schoolId/queue',
          options: Options(headers: headers),
        );

        if (response.statusCode == 200 && response.data is List) {
          final list = response.data as List;
          _currentItems.clear();
          for (final raw in list) {
            if (raw is Map<String, dynamic>) {
              final item = SurveillanceItem.fromJson(raw);
              if (item.status == 'class_notified') {
                _currentItems.add(item);
              }
            }
          }
        }
      }

      _stateController.add(SurveillanceLoaded(
        items: List.from(_currentItems),
        isResyncing: false,
      ));
    } catch (e) {
      if (_currentItems.isEmpty) {
        _stateController.add(SurveillanceError(e.toString()));
      } else {
        // En cas d'erreur lors d'une resynchronisation, conserver l'état existant
        _stateController.add(SurveillanceLoaded(
          items: List.from(_currentItems),
          isResyncing: false,
        ));
      }
    }
  }

  void _handleCalledEvent(PickupRequestCalledEvent event) {
    if (event.schoolId.isNotEmpty && event.schoolId != _schoolId) {
      return;
    }

    final index =
        _currentItems.indexWhere((i) => i.requestId == event.requestId);
    if (index >= 0) {
      return;
    }

    final newItem = SurveillanceItem.fromCalledEvent(event);
    _currentItems.add(newItem);

    _stateController.add(SurveillanceLoaded(
      items: List.from(_currentItems),
      isResyncing: false,
    ));
  }

  void _handleArrivalSignaledEvent(ArrivalSignaledEvent event) {
    final index = _currentItems.indexWhere(
      (i) =>
          i.requestId == event.arrivalId ||
          (event.studentId != null &&
              event.studentId!.isNotEmpty &&
              i.childId == event.studentId),
    );

    if (index >= 0) {
      // Déjà présent : mise à jour
      final existing = _currentItems[index];
      _currentItems[index] = existing.copyWith(
        liveDistanceMeters: event.liveDistanceMeters,
        proximityState: event.proximityState,
        parentName: event.parentName ?? existing.parentName,
        arrivedAt: event.arrivedAt ?? existing.arrivedAt,
      );
    } else {
      final rawName = event.studentName ?? '';
      final initial = rawName.isNotEmpty ? '${rawName[0]}.' : '';
      final newItem = SurveillanceItem(
        requestId: event.arrivalId,
        childId: event.studentId ?? '',
        childInitial: initial,
        childName: rawName.isNotEmpty ? rawName : initial,
        className: event.className ?? '',
        calledAt: clock.now(),
        status: 'class_notified',
        parentName: event.parentName,
        liveDistanceMeters: event.liveDistanceMeters,
        proximityState: event.proximityState,
        arrivedAt: event.arrivedAt,
      );
      _currentItems.add(newItem);
      _newArrivalAlertController.add(event);
    }

    _stateController.add(SurveillanceLoaded(
      items: List.from(_currentItems),
      isResyncing: false,
    ));
  }

  void _handleParentApproachingEvent(ParentApproachingEvent event) {
    bool updated = false;
    for (int i = 0; i < _currentItems.length; i++) {
      final item = _currentItems[i];
      final isChildApproaching = event.children.any(
        (c) => c.toString() == item.childId || (c is Map && c['id'] == item.childId),
      );
      if (isChildApproaching || item.parentName == event.parentName) {
        _currentItems[i] = item.copyWith(
          liveDistanceMeters: event.distanceMeters,
          proximityState: event.proximityState,
          parentName: event.parentName ?? item.parentName,
        );
        updated = true;
      }
    }

    if (updated) {
      _stateController.add(SurveillanceLoaded(
        items: List.from(_currentItems),
        isResyncing: false,
      ));
    }
  }

  /// Retirer une demande marquée partie de la file locale et notifier les écouteurs.
  void removeDeparted(String requestId) {
    final index = _currentItems.indexWhere(
      (i) => i.requestId == requestId || i.id == requestId,
    );
    if (index >= 0) {
      _currentItems.removeAt(index);
      _stateController.add(SurveillanceLoaded(
        items: List.from(_currentItems),
        isResyncing: false,
      ));
    }
  }

  void _handleDepartedEvent(PickupRequestDepartedEvent event) {
    if (event.schoolId.isNotEmpty && event.schoolId != _schoolId) {
      return;
    }

    removeDeparted(event.requestId);
  }

  /// Marquer le départ d'un élève (transition class_notified -> on_the_way).
  Future<void> markDepart(String requestId, {String? token}) async {
    final dio = _dio;
    if (dio == null) return;

    final effectiveToken = token ?? _authToken;
    final idempotencyKey = const Uuid().v4();
    final headers = <String, dynamic>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Idempotency-Key': idempotencyKey,
      if (effectiveToken != null) 'Authorization': 'Bearer $effectiveToken',
    };

    await dio.post(
      '$_baseUrl/api/v1/schools/$_schoolId/pickup-requests/$requestId/depart',
      options: Options(headers: headers),
    );
  }

  /// Ajouter directement un item (pour tests).
  void addItemForTesting(SurveillanceItem item) {
    _currentItems.add(item);
    _stateController.add(SurveillanceLoaded(
      items: List.from(_currentItems),
      isResyncing: false,
    ));
  }

  void dispose() {
    _calledSubscription?.cancel();
    _departedSubscription?.cancel();
    _arrivalSignaledSubscription?.cancel();
    _parentApproachingSubscription?.cancel();
    _resyncSubscription?.cancel();
    _connectionSubscription?.cancel();
    _fallbackPollingTimer?.cancel();
    _newArrivalAlertController.close();
    _stateController.close();
  }
}
