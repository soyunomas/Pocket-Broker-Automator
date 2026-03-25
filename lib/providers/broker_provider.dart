import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/broker_config.dart';
import '../services/broker_service.dart';
import '../services/log_service.dart';

class BrokerProvider extends ChangeNotifier {
  final BrokerService _brokerService = BrokerService();
  final LogService logService;
  Box<BrokerConfig>? _box;
  BrokerConfig _config = BrokerConfig();
  bool _isRunning = false;
  bool _isLoading = false;
  List<String> _ips = [];

  BrokerProvider({required this.logService});

  BrokerConfig get config => _config;
  bool get isRunning => _isRunning;
  bool get isLoading => _isLoading;
  List<String> get ips => _ips;

  Future<void> init() async {
    _box = await Hive.openBox<BrokerConfig>('broker_config');
    if (_box!.isNotEmpty) {
      _config = _box!.getAt(0)!;
    } else {
      _config = BrokerConfig();
      await _box!.add(_config);
    }
    _isRunning = await _brokerService.isBrokerRunning();
    notifyListeners();
  }

  Future<bool> startBroker() async {
    _isLoading = true;
    notifyListeners();

    final result = await _brokerService.startBroker(
      port: _config.port,
      authEnabled: _config.authEnabled,
      username: _config.username,
      password: _config.password,
      wsEnabled: _config.wsEnabled,
      wsPort: _config.wsPort,
    );

    final success = result['success'] as bool? ?? false;
    if (success) {
      _isRunning = true;
      _ips = (result['ips'] as List<String>?) ?? [];
      _config.enabled = true;
      await _config.save();
      final ipsStr = _ips.isNotEmpty ? _ips.join(', ') : 'desconocida';
      final wsInfo = _config.wsEnabled ? ' + WS:${_config.wsPort}' : '';
      logService.log('system', 'Broker local iniciado en puerto ${_config.port}$wsInfo — IPs: $ipsStr');
    } else {
      final error = result['error'] as String? ?? 'Error desconocido';
      logService.log('error', 'Error al iniciar broker: $error');
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  Future<void> stopBroker() async {
    _isLoading = true;
    notifyListeners();

    await _brokerService.stopBroker();
    _isRunning = false;
    _ips = [];
    _config.enabled = false;
    await _config.save();
    logService.log('system', 'Broker local detenido');

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateConfig({
    int? port,
    bool? authEnabled,
    String? username,
    String? password,
    bool? wsEnabled,
    int? wsPort,
  }) async {
    if (port != null) _config.port = port;
    if (authEnabled != null) _config.authEnabled = authEnabled;
    if (username != null) _config.username = username;
    if (password != null) _config.password = password;
    if (wsEnabled != null) _config.wsEnabled = wsEnabled;
    if (wsPort != null) _config.wsPort = wsPort;
    await _config.save();
    notifyListeners();
  }
}
