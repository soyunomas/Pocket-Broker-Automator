import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/connection_profile.dart';
import '../services/mqtt_client_service.dart';
import '../services/log_service.dart';
import '../services/background_service.dart';
import '../utils/battery_optimizer.dart';

class ConnectionProvider extends ChangeNotifier {
  final LogService logService;
  Box<ConnectionProfile>? _box;
  List<ConnectionProfile> _profiles = [];
  ClientConnectionState _connectionState = ClientConnectionState.disconnected;
  String _activeAlias = '';
  String _activeProfileId = '';
  bool _serviceRunning = false;

  ConnectionProvider({required this.logService});

  List<ConnectionProfile> get profiles => _profiles;
  ClientConnectionState get connectionState => _connectionState;
  String get activeAlias => _activeAlias;
  String get activeProfileId => _activeProfileId;
  bool get serviceRunning => _serviceRunning;

  Future<void> init() async {
    _box = await Hive.openBox<ConnectionProfile>('connections');
    _profiles = _box!.values.toList();

    // Listen to background service events
    BackgroundServiceController.on('connectionState').listen((event) {
      if (event != null) {
        final stateName = event['state'] as String? ?? 'disconnected';
        _connectionState = ClientConnectionState.values.firstWhere(
            (e) => e.name == stateName,
            orElse: () => ClientConnectionState.disconnected);
        if (event.containsKey('alias')) {
          _activeAlias = event['alias'] as String? ?? _activeAlias;
        }
        notifyListeners();
      }
    });

    // Messages are forwarded selectively by the background service
    // (only monitor-relevant topics). No Hive write here — the
    // MonitorProvider handles its own persistence.
    BackgroundServiceController.on('message').listen((_) {});

    // Receive logs written by the background isolate and replay them
    // into the UI's LogService so LogProvider picks them up
    BackgroundServiceController.on('logEntry').listen((event) {
      if (event != null) {
        logService.log(
          event['type'] as String? ?? 'system',
          event['message'] as String? ?? '',
        );
      }
    });

    // Handle URL launch requests from background isolate
    BackgroundServiceController.on('launchUrl').listen((event) async {
      if (event != null) {
        final urlStr = event['url'] as String? ?? '';
        logService.log('action', 'UI: recibido launchUrl IPC: $urlStr');
        if (urlStr.isNotEmpty) {
          try {
            final uri = Uri.parse(urlStr);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            logService.log('action', 'UI: URL abierta correctamente: $urlStr');
          } catch (e) {
            logService.log('error', 'UI: error abriendo URL: $urlStr → $e');
          }
        } else {
          logService.log('error', 'UI: launchUrl recibido con URL vacía');
        }
      }
    });

    // Check if service is already running (app restart)
    _serviceRunning = await BackgroundServiceController.isRunning();
    if (_serviceRunning) {
      BackgroundServiceController.requestState();
    }

    notifyListeners();
  }

  // --- Ensure foreground service is running ---

  Future<void> _ensureServiceStarted() async {
    if (_serviceRunning) return;

    final started = await BackgroundServiceController.start();
    if (!started) return;

    _serviceRunning = true;
    // Give the isolate time to initialize
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  // --- CRUD profiles ---

  Future<void> addProfile(ConnectionProfile profile) async {
    await _box?.add(profile);
    _profiles = _box!.values.toList();
    notifyListeners();
  }

  Future<void> updateProfile(ConnectionProfile profile) async {
    await profile.save();
    _profiles = _box!.values.toList();
    notifyListeners();
  }

  Future<void> importProfiles(List<ConnectionProfile> profiles) async {
    for (final p in profiles) {
      await _box?.add(p);
    }
    _profiles = _box!.values.toList();
    notifyListeners();
  }

  Future<void> deleteProfile(ConnectionProfile profile) async {
    // If deleting the active connection, disconnect first
    if (profile.id == _activeProfileId) {
      await disconnect();
    }
    await profile.delete();
    _profiles = _box!.values.toList();
    notifyListeners();
  }

  // --- Connect / Disconnect (always via foreground service) ---

  Future<bool> connect(ConnectionProfile profile) async {
    // Request battery optimization exclusion on first connect (critical for Xiaomi/Samsung/Huawei)
    final isIgnoring = await BatteryOptimizer.isIgnoringBatteryOptimizations();
    if (!isIgnoring) {
      await BatteryOptimizer.requestDisableBatteryOptimization();
    }

    await _ensureServiceStarted();

    BackgroundServiceController.connectToProfile({
      'id': profile.id,
      'alias': profile.alias,
      'host': profile.host,
      'port': profile.port,
      'username': profile.username,
      'password': profile.password,
      'clientId': profile.clientId,
      'ssl': profile.ssl,
    });
    _activeAlias = profile.alias;
    _activeProfileId = profile.id;
    _connectionState = ClientConnectionState.connecting;
    notifyListeners();
    return true;
  }

  Future<void> disconnect() async {
    BackgroundServiceController.disconnect();
    _activeAlias = '';
    _activeProfileId = '';
    _connectionState = ClientConnectionState.disconnected;
    notifyListeners();

    // Stop the foreground service when no connection is needed
    await BackgroundServiceController.stop();
    _serviceRunning = false;
  }
}
