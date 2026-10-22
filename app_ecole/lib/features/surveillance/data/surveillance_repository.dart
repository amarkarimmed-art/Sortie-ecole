import 'dart:async';

import 'package:dio/dio.dart';
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

  final List<SurveillanceItem> _currentItems = [];
  StreamSubscription<PickupRequestCalledEvent>? _calledSubscription;
  StreamSubscription<PickupRequestDepartedEvent>? _departedSubscription;
  StreamSubscription<void>? _resyncSubscription;

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
  List<SurveillanceItem> get currentItems => List.unmodifiable(_currentItems);
  ReverbService get reverbService => _reverbService;
  String get baseUrl => _baseUrl;

  void init() {
    // Écouter les événements temps réel pickup.called sans polling (CA14)
    _calledSubscription = _reverbService.calledEvents.listen((event) {
      _handleCalledEvent(event);
    });

    // Écouter les départs pour retirer les élèves de la liste locale (B4)
    _departedSubscription = _reverbService.departedEvents.listen((event) {
      _handleDepartedEvent(event);
    });

    // Écouter les reconnexions WebSocket pour recharger l'état complet (CA15)
    _resyncSubscription = _reverbService.resyncStream.listen((_) {
      reloadFromQueue(isResync: true);
    });
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
    // Ne retenir que les événements de la même école
    if (event.schoolId.isNotEmpty && event.schoolId != _schoolId) {
      return;
    }

    final index = _currentItems.indexWhere((i) => i.requestId == event.requestId);
    if (index >= 0) {
      // Déjà présent
      return;
    }

    final newItem = SurveillanceItem.fromCalledEvent(event);
    _currentItems.add(newItem);

    _stateController.add(SurveillanceLoaded(
      items: List.from(_currentItems),
      isResyncing: false,
    ));
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
    // Ne retenir que les événements de la même école
    if (event.schoolId.isNotEmpty && event.schoolId != _schoolId) {
      return;
    }

    removeDeparted(event.requestId);
  }

  /// Marquer le départ d'un élève (transition class_notified -> on_the_way).
  ///
  /// Envoie POST /api/v1/schools/{schoolId}/pickup-requests/{requestId}/depart
  /// avec Idempotency-Key (UUID v4) et Bearer token.
  /// Ne modifie pas l'état local directement : la file sera mise à jour
  /// via l'écoute de l'événement WebSocket pickup.departed (B1, B4).
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
    _resyncSubscription?.cancel();
    _stateController.close();
  }
}
