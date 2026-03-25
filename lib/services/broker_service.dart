import 'package:flutter/services.dart';

class BrokerService {
  static const _channel = MethodChannel('com.pocketbroker/mqtt_broker');

  Future<Map<String, dynamic>> startBroker({
    required int port,
    bool authEnabled = false,
    String username = '',
    String password = '',
    bool wsEnabled = false,
    int wsPort = 8083,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('startBroker', {
      'port': port,
      'authEnabled': authEnabled,
      'username': username,
      'password': password,
      'wsEnabled': wsEnabled,
      'wsPort': wsPort,
    });
    if (result == null) return {'success': false, 'error': 'No response'};
    // Cast ips list from native
    if (result.containsKey('ips')) {
      result['ips'] = List<String>.from(result['ips'] as List);
    }
    return result;
  }

  Future<void> stopBroker() async {
    await _channel.invokeMethod('stopBroker');
  }

  Future<bool> isBrokerRunning() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('isBrokerRunning');
    return result?['running'] as bool? ?? false;
  }
}
