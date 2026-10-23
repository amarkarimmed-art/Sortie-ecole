import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/widgets.dart';

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
  final String _cluster;
  final bool _enableConnection;

  PusherChannelsClient? _client;
  PrivateChannel? _privateChannel;
  StreamSubscription? _channelEventsSubscription;
  StreamSubscription? _lifecycleSubscription;

  bool _isConnected = false;
  bool _wasPreviouslyConnected = false;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  final StreamController<PickupRequestCalledEvent> _calledController =
      StreamController<PickupRequestCalledEvent>.broadcast();

  final StreamController<PickupRequestDepartedEvent> _departedController =
      StreamController<PickupRequestDepartedEvent>.broadcast();

  final StreamController<ArrivalSignaledEvent> _arrivalSignaledController =
      StreamController<ArrivalSignaledEvent>.broadcast();

  final StreamController<ParentApproachingEvent> _parentApproachingController =
      StreamController<ParentApproachingEvent>.broadcast();

  final StreamController<void> _resyncController =
      StreamController<void>.broadcast();

  final StreamController<Map<String, dynamic>> _rawEventController =
      StreamController<Map<String, dynamic>>.broadcast();

  ReverbService({
    String? baseUrl,
    required String schoolId,
    String? authUrl,
    String? appKey,
    String? cluster,
    bool? enableConnection,
    PusherChannelsClient? client,
  })  : _baseUrl = baseUrl ?? 'ws://127.0.0.1:8080',
        _schoolId = schoolId,
        _authUrl = authUrl ?? _defaultAuthUrl(baseUrl ?? 'ws://127.0.0.1:8080'),
        _appKey = appKey ?? 'sortie-reverb-key',
        _cluster = cluster ?? 'mt1',
        _enableConnection = enableConnection ?? !isTestEnvironment,
        _client = client;

  factory ReverbService.fromApiUrl({
    required String apiUrl,
    required String schoolId,
    String? appKey,
    String? cluster,
    bool? enableConnection,
  }) {
    final uri = Uri.parse(apiUrl);
    final host = uri.host.isNotEmpty
        ? (uri.host == 'localhost' ? '127.0.0.1' : uri.host)
        : '127.0.0.1';
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final baseUrl = '$wsScheme://$host:8080';
    final authUrl = '${uri.scheme}://$host:${uri.hasPort ? uri.port : 8000}/api/v1/broadcasting/auth';
    return ReverbService(
      baseUrl: baseUrl,
      schoolId: schoolId,
      authUrl: authUrl,
      appKey: appKey,
      cluster: cluster,
      enableConnection: enableConnection,
    );
  }

  static bool get isTestEnvironment {
    if (const bool.fromEnvironment('flutter.test')) return true;
    if (Zone.current[#test.declarer] != null) return true;
    try {
      if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _defaultAuthUrl(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    final host = (uri != null && uri.host.isNotEmpty)
        ? (uri.host == 'localhost' ? '127.0.0.1' : uri.host)
        : '127.0.0.1';
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
      if (uri.host == 'localhost') {
        return '127.0.0.1';
      }
      return uri.host;
    }
    return '127.0.0.1';
  }

  static int _resolvePort(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri != null && uri.hasPort) {
      return uri.port;
    }
    return 8080;
  }

  /// URL de base Reverb (ex: ws://127.0.0.1:8080).
  String get baseUrl => _baseUrl;

  /// URL d'authentification Laravel Broadcasting.
  String get authUrl => _authUrl;

  /// Clé d'application Pusher / Reverb.
  String get appKey => _appKey;

  /// Cluster Pusher (défaut 'mt1').
  String get cluster => _cluster;

  /// Indique si la connexion réseau réelle est activée.
  bool get enableConnection => _enableConnection;

  /// Identifiant UUID de l'école.
  String get schoolId => _schoolId;

  /// Nom du canal privé par école.
  String get channelName => 'private-school.$_schoolId.queue';

  /// Flux d'état de connexion WebSocket (true = connecté, false = déconnecté).
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Flux des événements pickup.called (sans polling, CA14).
  Stream<PickupRequestCalledEvent> get calledEvents => _calledController.stream;

  /// Flux des événements pickup.departed (B4).
  Stream<PickupRequestDepartedEvent> get departedEvents =>
      _departedController.stream;

  /// Flux des événements d'arrivée signalée.
  Stream<ArrivalSignaledEvent> get arrivalSignaledEvents =>
      _arrivalSignaledController.stream;

  /// Flux des événements de parent en approche.
  Stream<ParentApproachingEvent> get parentApproachingEvents =>
      _parentApproachingController.stream;

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
      final host = _resolveHost(_baseUrl);
      final port = _resolvePort(_baseUrl);
      final scheme = _resolveWsScheme(_baseUrl);

      final options = PusherChannelsOptions.custom(
        uriResolver: (metadata) => Uri(
          scheme: scheme,
          host: host,
          port: port,
          path: '/app/$_appKey',
          queryParameters: {
            ...metadata.getQueryParameters(),
            'cluster': _cluster,
          },
        ),
      );

      _client ??= PusherChannelsClient.websocket(
        options: options,
        connectionErrorHandler: (exception, trace, refresh) {
          _isConnected = false;
          _connectionController.add(false);
        },
      );

      _lifecycleSubscription?.cancel();
      _lifecycleSubscription = _client!.lifecycleStream.listen((state) {
        if (state == PusherChannelsClientLifeCycleState.establishedConnection) {
          _isConnected = true;
          _connectionController.add(true);
          if (_wasPreviouslyConnected) {
            _resyncController.add(null);
          }
          _wasPreviouslyConnected = true;
          _privateChannel?.subscribeIfNotUnsubscribed();
        } else if (state == PusherChannelsClientLifeCycleState.disconnected ||
            state == PusherChannelsClientLifeCycleState.connectionError) {
          _isConnected = false;
          _connectionController.add(false);
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
      _connectionController.add(false);
    }
  }

  /// Traitement des événements reçus sur le canal privé.
  void _handleChannelEvent(ChannelReadEvent event) {
    try {
      final raw = event.rootObject;
      _rawEventController.add(raw);

      final eventName = event.name;
      Map<String, dynamic> eventData = event.tryGetDataAsMap() ?? {};
      if (eventData.isEmpty && event.data is String) {
        try {
          final decoded = jsonDecode(event.data as String);
          if (decoded is Map<String, dynamic>) {
            eventData = decoded;
          }
        } catch (_) {}
      }

      final cleanName =
          eventName.startsWith('.') ? eventName.substring(1) : eventName;

      if (cleanName == 'pickup.called' ||
          cleanName.endsWith('PickupRequestCalled') ||
          eventName.contains('pickup.called')) {
        final calledEvent = PickupRequestCalledEvent.fromJson(eventData);
        _calledController.add(calledEvent);
      } else if (cleanName == 'pickup.departed' ||
          cleanName.endsWith('PickupRequestDeparted') ||
          eventName.contains('pickup.departed')) {
        final departedEvent = PickupRequestDepartedEvent.fromJson(eventData);
        _departedController.add(departedEvent);
      } else if (cleanName == 'arrival.signaled' ||
          cleanName.endsWith('ArrivalSignaledEvent') ||
          eventName.contains('arrival.signaled')) {
        final arrivalEvent = ArrivalSignaledEvent.fromJson(eventData);
        _arrivalSignaledController.add(arrivalEvent);
      } else if (cleanName == 'parent.approaching' ||
          cleanName.endsWith('ParentApproachingEvent') ||
          eventName.contains('parent.approaching')) {
        final approachingEvent = ParentApproachingEvent.fromJson(eventData);
        _parentApproachingController.add(approachingEvent);
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

  /// Injecter manuellement un événement d'arrivée signalée.
  void emitArrivalSignaledEvent(ArrivalSignaledEvent event) {
    _arrivalSignaledController.add(event);
  }

  /// Injecter manuellement un événement de parent en approche.
  void emitParentApproachingEvent(ParentApproachingEvent event) {
    _parentApproachingController.add(event);
  }

  /// Déclencher manuellement un signal de resynchronisation (simulation reconnexion).
  void triggerResync() {
    _resyncController.add(null);
  }

  /// Se déconnecter proprement.
  Future<void> disconnect() async {
    _isConnected = false;
    _connectionController.add(false);
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
      if (!_client!.isDisposed) {
        _client!.dispose();
      }
      _client = null;
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
    await _arrivalSignaledController.close();
    await _parentApproachingController.close();
    await _resyncController.close();
    await _rawEventController.close();
    await _connectionController.close();
  }
}

class ArrivalSignaledEvent {
  final String arrivalId;
  final String? requestId;
  final String? studentId;
  final String? studentName;
  final String? className;
  final String? parentName;
  final int? liveDistanceMeters;
  final String proximityState;
  final String? arrivedAt;
  final List<dynamic> children;

  const ArrivalSignaledEvent({
    required this.arrivalId,
    this.requestId,
    this.studentId,
    this.studentName,
    this.className,
    this.parentName,
    this.liveDistanceMeters,
    this.proximityState = 'in_perimeter',
    this.arrivedAt,
    this.children = const [],
  });

  factory ArrivalSignaledEvent.fromJson(Map<String, dynamic> json) {
    final arrival = json['arrival'] is Map<String, dynamic>
        ? json['arrival'] as Map<String, dynamic>
        : json;
    final firstChild = (json['children'] is List && (json['children'] as List).isNotEmpty && (json['children'] as List).first is Map<String, dynamic>)
        ? (json['children'] as List).first as Map<String, dynamic>
        : null;
    final student = json['student'] is Map<String, dynamic>
        ? json['student'] as Map<String, dynamic>
        : firstChild;

    final studentName = student != null
        ? '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'.trim()
        : (json['student_name'] as String? ?? json['child_name'] as String?);

    final reqId = json['request_id']?.toString() ??
        firstChild?['request_id']?.toString() ??
        student?['request_id']?.toString();

    return ArrivalSignaledEvent(
      arrivalId: arrival['id']?.toString() ?? json['arrival_id']?.toString() ?? '',
      requestId: reqId,
      studentId: student?['id']?.toString() ?? json['student_id']?.toString(),
      studentName: studentName,
      className: student?['class_name']?.toString() ?? json['class_name']?.toString(),
      parentName: json['parent_name']?.toString(),
      liveDistanceMeters: (json['live_distance_meters'] as num?)?.toInt() ??
          (json['distance_meters'] as num?)?.toInt(),
      proximityState: json['proximity_state']?.toString() ?? 'in_perimeter',
      arrivedAt: arrival['arrived_at']?.toString() ?? json['arrived_at']?.toString(),
      children: (json['children'] as List<dynamic>?) ?? [],
    );
  }
}

class ParentApproachingEvent {
  final String parentId;
  final String? parentName;
  final List<dynamic> children;
  final int? distanceMeters;
  final String proximityState;
  final String timestamp;

  const ParentApproachingEvent({
    required this.parentId,
    this.parentName,
    this.children = const [],
    this.distanceMeters,
    this.proximityState = 'approaching',
    required this.timestamp,
  });

  factory ParentApproachingEvent.fromJson(Map<String, dynamic> json) {
    return ParentApproachingEvent(
      parentId: json['parent_id']?.toString() ?? '',
      parentName: json['parent_name']?.toString(),
      children: (json['children'] as List<dynamic>?) ?? [],
      distanceMeters: (json['distance_meters'] as num?)?.toInt(),
      proximityState: json['proximity_state']?.toString() ?? 'approaching',
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}

