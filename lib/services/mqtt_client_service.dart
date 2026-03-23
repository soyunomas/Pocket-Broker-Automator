import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/connection_profile.dart';

enum ClientConnectionState { disconnected, connecting, connected }

class ReceivedMqttMessage {
  final String topic;
  final String payload;
  final DateTime timestamp;

  ReceivedMqttMessage({
    required this.topic,
    required this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class MqttClientService {
  MqttServerClient? _client;
  ConnectionProfile? _activeProfile;
  ClientConnectionState _connectionState = ClientConnectionState.disconnected;

  final _connectionStateController =
      StreamController<ClientConnectionState>.broadcast();
  final _messageController =
      StreamController<ReceivedMqttMessage>.broadcast();
  final _subscriptions = <String>{};

  // Reconnection state
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _intentionalDisconnect = false;
  static const _maxReconnectDelay = 60; // seconds
  static const _baseReconnectDelay = 2; // seconds

  // Network monitoring
  StreamSubscription? _connectivitySubscription;
  final _connectivity = Connectivity();

  Stream<ClientConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<ReceivedMqttMessage> get messageStream => _messageController.stream;
  ClientConnectionState get connectionState => _connectionState;
  ConnectionProfile? get activeProfile => _activeProfile;
  Set<String> get subscriptions => Set.unmodifiable(_subscriptions);
  bool get isIntentionalDisconnect => _intentionalDisconnect;

  MqttClientService() {
    _startNetworkMonitoring();
  }

  void _setConnectionState(ClientConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  // --- Network monitoring ---

  void _startNetworkMonitoring() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork &&
          _activeProfile != null &&
          _connectionState == ClientConnectionState.disconnected &&
          !_intentionalDisconnect) {
        _scheduleReconnect(immediate: true);
      }
    });
  }

  // --- Connection ---

  Future<bool> connect(ConnectionProfile profile) async {
    _intentionalDisconnect = false;
    _cancelReconnect();
    await _disconnectClient();
    _activeProfile = profile;
    _reconnectAttempt = 0;
    return _attemptConnect();
  }

  bool _isConnecting = false;

  Future<bool> _attemptConnect() async {
    final profile = _activeProfile;
    if (profile == null) return false;
    if (_isConnecting) return false; // Prevent concurrent connect attempts

    _isConnecting = true;
    _setConnectionState(ClientConnectionState.connecting);

    try {
      _client = MqttServerClient.withPort(
          profile.host, profile.clientId, profile.port);
      _client!.keepAlivePeriod = 30;
      _client!.connectTimeoutPeriod = 10000; // 10s timeout
      _client!.autoReconnect = false;
      _client!.onDisconnected = _onDisconnected;
      _client!.logging(on: false);

      if (profile.ssl) {
        _client!.secure = true;
        _client!.securityContext = SecurityContext.defaultContext;
      }

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(profile.clientId)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);

      if (profile.username.isNotEmpty) {
        connMessage.authenticateAs(profile.username, profile.password);
      }

      _client!.connectionMessage = connMessage;

      await _client!.connect();
      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        _reconnectAttempt = 0;
        _setConnectionState(ClientConnectionState.connected);
        _listenMessages();
        _resubscribeAll();
        _isConnecting = false;
        return true;
      }
    } catch (_) {
      // Connection failed
    }

    _isConnecting = false;
    _setConnectionState(ClientConnectionState.disconnected);
    if (!_intentionalDisconnect && _activeProfile != null) {
      _scheduleReconnect();
    }
    return false;
  }

  // --- Backoff exponencial ---

  void _scheduleReconnect({bool immediate = false}) {
    _cancelReconnect();
    if (_intentionalDisconnect || _activeProfile == null) return;

    final delay = immediate
        ? 1
        : min(
            _baseReconnectDelay * pow(2, _reconnectAttempt).toInt(),
            _maxReconnectDelay,
          );

    _reconnectAttempt++;
    _setConnectionState(ClientConnectionState.connecting);

    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      if (_intentionalDisconnect || _activeProfile == null) return;
      await _attemptConnect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // --- Message listener ---

  void _listenMessages() {
    _client?.updates?.listen((messages) {
      for (final msg in messages) {
        final pubMsg = msg.payload as MqttPublishMessage;
        final text = MqttPublishPayload.bytesToStringAsString(
          pubMsg.payload.message,
        );
        _messageController.add(ReceivedMqttMessage(
          topic: msg.topic,
          payload: text,
        ));
      }
    });
  }

  // --- Callbacks ---

  void _onDisconnected() {
    if (_isConnecting) return; // Don't trigger reconnect during active attempt
    _setConnectionState(ClientConnectionState.disconnected);
    if (!_intentionalDisconnect && _activeProfile != null) {
      _scheduleReconnect();
    }
  }

  // --- Subscriptions ---

  void _resubscribeAll() {
    for (final topic in _subscriptions) {
      _client?.subscribe(topic, MqttQos.atMostOnce);
    }
  }

  void subscribe(String topic, {MqttQos qos = MqttQos.atMostOnce}) {
    _subscriptions.add(topic);
    if (_connectionState == ClientConnectionState.connected) {
      _client?.subscribe(topic, qos);
    }
  }

  void unsubscribe(String topic) {
    _subscriptions.remove(topic);
    if (_connectionState == ClientConnectionState.connected) {
      _client?.unsubscribe(topic);
    }
  }

  // --- Publish ---

  void publish(String topic, String payload,
      {int qos = 0, bool retain = false}) {
    if (_client == null ||
        _connectionState != ClientConnectionState.connected) {
      return;
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(
      topic,
      qos == 0
          ? MqttQos.atMostOnce
          : (qos == 1 ? MqttQos.atLeastOnce : MqttQos.exactlyOnce),
      builder.payload!,
      retain: retain,
    );
  }

  // --- Disconnect ---

  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _isConnecting = false;
    _cancelReconnect();
    await _disconnectClient();
    _activeProfile = null;
    _reconnectAttempt = 0;
    _setConnectionState(ClientConnectionState.disconnected);
  }

  Future<void> _disconnectClient() async {
    _client?.autoReconnect = false;
    _client?.disconnect();
    _client = null;
  }

  void dispose() {
    _intentionalDisconnect = true;
    _cancelReconnect();
    _connectivitySubscription?.cancel();
    _disconnectClient();
    _connectionStateController.close();
    _messageController.close();
  }
}
