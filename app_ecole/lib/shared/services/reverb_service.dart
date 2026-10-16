import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../features/surveillance/domain/pickup_request_called_event.dart';
import '../../features/surveillance/domain/pickup_request_departed_event.dart';

/// Service WebSocket pour Laravel Reverb (ADR 0006).
///
/// Canal privé par école : `private-school.{schoolId}.queue`.
///
/// Ce service gère :
/// - La connexion / reconnexion WebSocket
/// - L'abonnement aux événements en temps réel (pickup.called, pickup.departed)
/// - L'émission du signal de resynchronisation lors d'une reconnexion (CA15)
class ReverbService {
  final String _baseUrl;
  final String _schoolId;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _wasPreviouslyConnected = false;

  final StreamController<PickupRequestCalledEvent> _calledController =
      StreamController<PickupRequestCalledEvent>.broadcast();

  final StreamController<PickupRequestDepartedEvent> _departedController =
      StreamController<PickupRequestDepartedEvent>.broadcast();

  final StreamController<void> _resyncController =
      StreamController<void>.broadcast();

  final StreamController<Map<String, dynamic>> _rawEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  ReverbService({
    required String baseUrl,
    required String schoolId,
  })  : _baseUrl = baseUrl,
        _schoolId = schoolId;

  /// URL de base Reverb (ex: ws://localhost:8080).
  String get baseUrl => _baseUrl;

  /// Identifiant UUID de l'école.
  String get schoolId => _schoolId;

  /// Nom du canal privé par école.
  String get channelName => 'private-school.$_schoolId.queue';

  /// Flux des événements pickup.called (sans polling, CA14).
  Stream<PickupRequestCalledEvent> get calledEvents => _calledController.stream;

  /// Flux des événements pickup.departed (B4).
  Stream<PickupRequestDepartedEvent> get departedEvents =>
      _departedController.stream;

  /// Flux de signalement de reconnexion pour rechargement complet (CA15).
  Stream<void> get resyncStream => _resyncController.stream;

  /// Flux d'événements bruts.
  Stream<Map<String, dynamic>> get events => _rawEventController.stream;

  /// État actuel de la connexion WebSocket.
  bool get isConnected => _isConnected;

  /// Se connecter au canal privé de l'école.
  Future<void> connect({String? authToken}) async {
    try {
      final wsUri = Uri.parse(_baseUrl);
      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel?.stream.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (error) {
          _handleDisconnection();
        },
        onDone: () {
          _handleDisconnection();
        },
      );

      _isConnected = true;

      // Si c'est une reconnexion après coupure, émettre le signal de resynchronisation (CA15)
      if (_wasPreviouslyConnected) {
        _resyncController.add(null);
      }
      _wasPreviouslyConnected = true;
    } catch (_) {
      _handleDisconnection();
    }
  }

  /// Traitement des messages reçus via WebSocket.
  void _handleMessage(dynamic data) {
    try {
      final raw = jsonDecode(data.toString()) as Map<String, dynamic>;
      _rawEventController.add(raw);

      final eventName = raw['event'] as String?;
      final payload = raw['data'];

      Map<String, dynamic> eventData = {};
      if (payload is String) {
        eventData = jsonDecode(payload) as Map<String, dynamic>;
      } else if (payload is Map<String, dynamic>) {
        eventData = payload;
      }

      if (eventName == 'pickup.called' || eventName == 'App\\Events\\PickupRequestCalled') {
        final calledEvent = PickupRequestCalledEvent.fromJson(eventData);
        _calledController.add(calledEvent);
      } else if (eventName == 'pickup.departed' ||
          eventName == 'App\\Events\\PickupRequestDeparted') {
        final departedEvent = PickupRequestDepartedEvent.fromJson(eventData);
        _departedController.add(departedEvent);
      }
    } catch (_) {
      // Ignorer les messages malformés
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
  }

  /// Injecter manuellement un événement (utile pour les tests ou simulation).
  void emitCalledEvent(PickupRequestCalledEvent event) {
    _calledController.add(event);
  }

  /// Injecter manuellement un événement de départ (utile pour les tests ou simulation).
  void emitDepartedEvent(PickupRequestDepartedEvent event) {
    _departedController.add(event);
  }

  /// Déclencher manuellement un signal de resynchronisation (simulation reconnexion).
  void triggerResync() {
    _resyncController.add(null);
  }

  /// Se déconnecter proprement.
  Future<void> disconnect() async {
    _isConnected = false;
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }

  /// Libérer les ressources.
  Future<void> dispose() async {
    await disconnect();
    await _calledController.close();
    await _departedController.close();
    await _resyncController.close();
    await _rawEventController.close();
  }
}
