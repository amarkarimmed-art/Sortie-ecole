import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Service WebSocket pour Laravel Reverb.
///
/// Canal privé par école : `private-school.{schoolId}.queue` (ADR 0006).
///
/// Ce service est le SEUL point de contact WebSocket dans l'app.
/// Il gère :
/// - La connexion/reconnexion automatique
/// - L'écoute des événements temps réel (file d'attente, appels)
/// - La gestion de la perte de connexion
///
/// Utilisé uniquement dans :
///   app_ecole/lib/shared/services/reverb_service.dart
class ReverbService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final String _baseUrl;
  final String _schoolId;
  bool _isConnected = false;

  /// Callbacks pour les événements reçus.
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  ReverbService({
    required String baseUrl,
    required String schoolId,
  })  : _baseUrl = baseUrl,
        _schoolId = schoolId;

  /// Flux d'événements Reverb.
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  /// État de la connexion.
  bool get isConnected => _isConnected;

  /// Se connecter au canal privé de l'école.
  ///
  /// Canal : `private-school.{schoolId}.queue`
  Future<void> connect({required String authToken}) async {
    // TODO: Implémenter la connexion WebSocket vers Reverb
    // avec authentification Sanctum bearer token.
    //
    // 1. Établir la connexion WebSocket
    // 2. S'abonner au canal private-school.{_schoolId}.queue
    // 3. Écouter les événements et les diffuser via _eventController
    // 4. Gérer la reconnexion automatique en cas de perte
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
    await _eventController.close();
  }
}
