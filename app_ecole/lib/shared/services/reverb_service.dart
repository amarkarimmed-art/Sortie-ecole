import 'dart:async';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';

import '../../features/surveillance/domain/pickup_request_called_event.dart';
import '../../features/surveillance/domain/pickup_request_departed_event.dart';

/// Service WebSocket pour Laravel Reverb (ADR 0006, protocole Pusher v7).
///
/// Canal privé par école : `private-school.{schoolId}.queue`.
///
/// Ce service gère :
/// - La connexion / reconnexion automatique au serveur Reverb via [PusherChannelsClient]
/// - L'authentification du canal privé auprès du backend Laravel via `POST /broadcasting/auth`
/// - L'abonnement aux événements en temps réel (`pickup.called`, `pickup.departed`)
/// - L'émission du signal de resynchronisation lors d'une reconnexion (CA15)
class ReverbService {
  final String _baseUrl;
  final String _schoolId;
  final String _authUrl;
  final String _appKey;
  final bool _enableConnection;

  PusherChannelsClient? _client;
  PrivateChannel? _privateChannel;
  StreamSubscription? _channelEventsSubscription;
  StreamSubscription? _lifecycleSubscription;

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
    String? authUrl,
    String? appKey,
    bool? enableConnection,
    PusherChannelsClient? client,
  })  : _baseUrl = baseUrl,
        _schoolId = schoolId,
        _authUrl = authUrl ?? _defaultAuthUrl(baseUrl),
        _appKey = appKey ?? 'sortie-reverb-key',
        _enableConnection = enableConnection ?? !_isTestEnvironment,
        _client = client;

  static bool get _isTestEnvironment =>
      const bool.fromEnvironment('flutter.test') ||
      Zone.current[#test.declarer] != null;

  static String _defaultAuthUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final host = (uri != null && uri.host.isNotEmpty) ? uri.host : 'localhost';
    final scheme = (uri != null && (uri.scheme == 'wss' || uri.scheme == 'https'))
        ? 'https'
        : 'http';
    return '$scheme://$host:8000/broadcasting/auth';
  }

  static String _resolveWsScheme(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && (uri.scheme == 'wss' || uri.scheme == 'https')) {
      return 'wss';
    }
    return 'ws';
  }

  static String _resolveHost(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.host.isNotEmpty) {
      return uri.host;
    }
    return 'localhost';
  }

  static int _resolvePort(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.hasPort) {
      return uri.port;
    }
    return 8080;
  }

  /// URL de base Reverb (ex: ws://localhost:8080).
  String get baseUrl => _baseUrl;

  /// URL d'authentification Laravel Broadcasting.
  String get authUrl => _authUrl;

  /// Clé d'application Pusher / Reverb.
  String get appKey => _appKey;

  /// Indique si la connexion réseau réelle est activée.
  bool get enableConnection => _enableConnection;

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

  /// Se connecter au canal privé de l'école avec signature Sanctum.
  Future<void> connect({String? authToken}) async {
    if (!_enableConnection) {
      return;
    }

    try {
      final options = PusherChannelsOptions.fromHost(
        scheme: _resolveWsScheme(_baseUrl),
        host: _resolveHost(_baseUrl),
        port: _resolvePort(_baseUrl),
        key: _appKey,
      );

      _client ??= PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          _isConnected = false;
        },
      );

      _lifecycleSubscription?.cancel();
      _lifecycleSubscription = _client!.lifecycleStream.listen((state) {
        if (state == PusherChannelsClientLifeCycleState.establishedConnection) {
          _isConnected = true;
          if (_wasPreviouslyConnected) {
            _resyncController.add(null);
          }
          _wasPreviouslyConnected = true;
          _privateChannel?.subscribeIfNotUnsubscribed();
        } else if (state == PusherChannelsClientLifeCycleState.disconnected ||
            state == PusherChannelsClientLifeCycleState.connectionError) {
          _isConnected = false;
        }
      });

      final authUri = Uri.parse(_authUrl);
      final authDelegate =
          EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
        authorizationEndpoint: authUri,
        headers: {
          'Accept': 'application/json',
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'Bearer $authToken',
        },
      );

      _privateChannel = _client!.privateChannel(
        channelName,
        authorizationDelegate: authDelegate,
      );

      _channelEventsSubscription?.cancel();
      _channelEventsSubscription =
          _privateChannel!.bindToAll().listen(_handleChannelEvent);

      await _client!.connect();
      _privateChannel!.subscribeIfNotUnsubscribed();
    } catch (_) {
      _isConnected = false;
    }
  }

  /// Traitement des événements reçus sur le canal privé.
  void _handleChannelEvent(ChannelReadEvent event) {
    try {
      final raw = event.rootObject;
      _rawEventController.add(raw);

      final eventName = event.name;
      final eventData = event.tryGetDataAsMap() ?? {};

      if (eventName == 'pickup.called' ||
          eventName == '.pickup.called' ||
          eventName == 'App\\Events\\PickupRequestCalled') {
        final calledEvent = PickupRequestCalledEvent.fromJson(eventData);
        _calledController.add(calledEvent);
      } else if (eventName == 'pickup.departed' ||
          eventName == '.pickup.departed' ||
          eventName == 'App\\Events\\PickupRequestDeparted') {
        final departedEvent = PickupRequestDepartedEvent.fromJson(eventData);
        _departedController.add(departedEvent);
      }
    } catch (_) {
      // Ignorer les messages malformés
    }
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
    await _channelEventsSubscription?.cancel();
    _channelEventsSubscription = null;
    await _lifecycleSubscription?.cancel();
    _lifecycleSubscription = null;
    if (_privateChannel != null) {
      _privateChannel!.unsubscribe();
      _privateChannel = null;
    }
    if (_client != null) {
      await _client!.disconnect();
    }
  }

  /// Libérer les ressources.
  Future<void> dispose() async {
    await disconnect();
    if (_client != null && !_client!.isDisposed) {
      _client!.dispose();
    }
    await _calledController.close();
    await _departedController.close();
    await _resyncController.close();
    await _rawEventController.close();
  }
}
