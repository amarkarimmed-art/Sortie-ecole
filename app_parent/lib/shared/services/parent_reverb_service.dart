import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/widgets.dart';

import '../../../features/sortie/domain/repositories/arrival_repository.dart';

/// Service WebSocket pour Laravel Reverb dédié au parent.
///
/// Canal privé par parent : `private-school.{schoolId}.parent.{userId}`.
/// Événement écouté : `pickup.status.updated`.
class ParentReverbService {
  final String _baseUrl;
  final String _schoolId;
  final String _userId;
  final String _authUrl;
  final String _appKey;
  final String _cluster;
  final bool _enableConnection;
  final ArrivalRepository? _arrivalRepository;

  PusherChannelsClient? _client;
  PrivateChannel? _privateChannel;
  StreamSubscription? _channelEventsSubscription;
  StreamSubscription? _lifecycleSubscription;
  Timer? _syncTimer;

  bool _isConnected = false;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  final StreamController<Map<String, dynamic>> _statusUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  ParentReverbService({
    String? baseUrl,
    required String schoolId,
    required String userId,
    String? authUrl,
    String? appKey,
    String? cluster,
    bool? enableConnection,
    ArrivalRepository? arrivalRepository,
    PusherChannelsClient? client,
  })  : _baseUrl = baseUrl ?? 'ws://127.0.0.1:8080',
        _schoolId = schoolId,
        _userId = userId,
        _authUrl = authUrl ?? _defaultAuthUrl(baseUrl ?? 'ws://127.0.0.1:8080'),
        _appKey = appKey ?? 'sortie-reverb-key',
        _cluster = cluster ?? 'mt1',
        _enableConnection = enableConnection ?? !isTestEnvironment,
        _arrivalRepository = arrivalRepository,
        _client = client;

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

  String get channelName => 'private-school.$_schoolId.parent.$_userId';
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get statusUpdatesStream =>
      _statusUpdatesController.stream;
  bool get isConnected => _isConnected;

  /// Démarre la connexion WebSocket et le timer périodique de secours (5 secondes).
  Future<void> connect({String? authToken}) async {
    _startPeriodicSync();

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

  factory ParentReverbService.fromApiUrl({
    required String apiUrl,
    required String schoolId,
    required String userId,
    ArrivalRepository? arrivalRepository,
    String? appKey,
    String? cluster,
    bool? enableConnection,
    PusherChannelsClient? client,
  }) {
    final uri = Uri.tryParse(apiUrl);
    final host = (uri != null && uri.host.isNotEmpty) ? uri.host : '127.0.0.1';
    final isHttps = uri != null && (uri.scheme == 'https' || uri.scheme == 'wss');
    final wsScheme = isHttps ? 'wss' : 'ws';
    final httpScheme = isHttps ? 'https' : 'http';
    final reverbPort = 8080;
    final apiPort = (uri != null && uri.hasPort) ? uri.port : 8000;

    return ParentReverbService(
      baseUrl: '$wsScheme://$host:$reverbPort',
      schoolId: schoolId,
      userId: userId,
      authUrl: '$httpScheme://$host:$apiPort/broadcasting/auth',
      appKey: appKey,
      cluster: cluster,
      enableConnection: enableConnection,
      arrivalRepository: arrivalRepository,
      client: client,
    );
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    if (_arrivalRepository == null) return;

    // Polling de secours toutes les 10 secondes lorsque la connexion WebSocket est coupée
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_isConnected) return; // Priorité au temps réel Reverb
      try {
        final data = await _arrivalRepository.getArrivalStatus();
        final pickupRequests = (data['pickup_requests'] as List?) ?? [];
        if (pickupRequests.isNotEmpty) {
          final firstReq = Map<String, dynamic>.from(pickupRequests.first as Map);
          final status = firstReq['status'] as String?;
          final child = firstReq['child'] as Map<String, dynamic>?;
          final childName = child != null
              ? '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim()
              : null;

          if (status != null && !_statusUpdatesController.isClosed) {
            _statusUpdatesController.add({
              'request_id': firstReq['id'],
              'school_id': _schoolId,
              'status': status,
              'child_name': childName,
              'updated_at': firstReq['updated_at'],
            });
          }
        }
      } catch (_) {}
    });
  }

  void _handleChannelEvent(ChannelReadEvent event) {
    try {
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

      if (cleanName == 'pickup.status.updated' ||
          cleanName.endsWith('ParentPickupStatusUpdated') ||
          eventName.contains('pickup.status.updated')) {
        if (!_statusUpdatesController.isClosed) {
          _statusUpdatesController.add(eventData);
        }
      }
    } catch (_) {}
  }

  /// Injecte manuellement une mise à jour (simulation / test).
  void emitStatusUpdate(Map<String, dynamic> data) {
    if (!_statusUpdatesController.isClosed) {
      _statusUpdatesController.add(data);
    }
  }

  /// Arrête proprement la connexion et le timer.
  Future<void> disconnect() async {
    _syncTimer?.cancel();
    _syncTimer = null;
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

  Future<void> dispose() async {
    await disconnect();
    if (_client != null && !_client!.isDisposed) {
      _client!.dispose();
    }
    await _connectionController.close();
    await _statusUpdatesController.close();
  }
}
