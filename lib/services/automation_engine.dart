import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/automation_rule.dart';
import 'mqtt_client_service.dart';
import 'log_service.dart';

class AutomationEngine {
  final MqttClientService _mqttService;
  final LogService _logService;
  final List<AutomationRule> _rules = [];
  StreamSubscription<ReceivedMqttMessage>? _messageSubscription;
  StreamSubscription<ClientConnectionState>? _connectionSubscription;

  /// Callback to delegate URL/intent actions to the UI isolate.
  /// Set this when running in a background isolate that cannot launch URLs.
  void Function(String url)? _onIntentAction;

  AutomationEngine(this._mqttService, this._logService);

  set onIntentAction(void Function(String url)? callback) =>
      _onIntentAction = callback;

  void loadRules(List<AutomationRule> rules) {
    _rules.clear();
    _rules.addAll(rules);
    _subscribeToRuleTopics();
  }

  void start() {
    _messageSubscription?.cancel();
    _messageSubscription = _mqttService.messageStream.listen(_evaluateMessage);

    // Re-subscribe to rule topics whenever connection is (re)established
    _connectionSubscription?.cancel();
    _connectionSubscription =
        _mqttService.connectionStateStream.listen((state) {
      if (state == ClientConnectionState.connected) {
        _logService.log('system',
            'Conexión establecida — suscribiendo ${_rules.where((r) => r.enabled).length} reglas');
        _subscribeToRuleTopics();
      }
    });

    _subscribeToRuleTopics();
  }

  void stop() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  void _subscribeToRuleTopics() {
    for (final rule in _rules) {
      if (rule.enabled) {
        _mqttService.subscribe(rule.topic);
      }
    }
  }

  void _evaluateMessage(ReceivedMqttMessage message) {
    // Snapshot the list so concurrent modifications don't skip rules
    final snapshot = List<AutomationRule>.of(_rules);
    _logService.log('system',
        'Evaluando mensaje: ${message.topic} = "${message.payload}" contra ${snapshot.where((r) => r.enabled).length} reglas activas');
    int matched = 0;
    for (final rule in snapshot) {
      if (!rule.enabled) continue;
      if (!_topicMatches(rule.topic, message.topic)) continue;
      final condResult = _conditionMatches(rule.condition, message.payload);
      _logService.log('system',
          'Regla "${rule.name}" [${rule.condition.type}="${rule.condition.value}"] → ${condResult ? "MATCH" : "no match"}');
      if (condResult) {
        matched++;
        _executeActions(rule);
      }
    }
    if (matched == 0) {
      _logService.log('system', 'Ninguna regla coincidió para ${message.topic}');
    } else {
      _logService.log('system', '$matched regla(s) activada(s) para ${message.topic}');
    }
  }

  bool _topicMatches(String ruleTopic, String messageTopic) {
    if (ruleTopic == messageTopic) return true;
    final ruleParts = ruleTopic.split('/');
    final msgParts = messageTopic.split('/');
    for (var i = 0; i < ruleParts.length; i++) {
      if (ruleParts[i] == '#') return true;
      if (i >= msgParts.length) return false;
      if (ruleParts[i] == '+') continue;
      if (ruleParts[i] != msgParts[i]) return false;
    }
    return ruleParts.length == msgParts.length;
  }

  bool _conditionMatches(RuleCondition condition, String payload) {
    switch (condition.type) {
      case 'any':
        return true;
      case 'equals':
        return payload == condition.value;
      case 'contains':
        return payload.contains(condition.value);
      case 'regex':
        try {
          return RegExp(condition.value).hasMatch(payload);
        } catch (_) {
          return false;
        }
      default:
        return false;
    }
  }

  Future<void> _executeActions(AutomationRule rule) async {
    _logService.log('action', 'Regla "${rule.name}" activada');
    for (final action in rule.actions) {
      try {
        await _executeAction(action);
      } catch (e) {
        _logService.log('error', 'Error ejecutando acción ${action.type}: $e');
      }
    }
  }

  Future<void> _executeAction(RuleAction action) async {
    switch (action.type) {
      case 'sound':
        final file = action.params['file'] ?? '';
        if (file.isNotEmpty) {
          final player = AudioPlayer();
          player.onPlayerComplete.listen((_) => player.dispose());
          await player.play(DeviceFileSource(file));
        }
        _logService.log(
            'action', 'Sonido reproducido: ${file.split('/').last}');
        break;

      case 'webhook':
        final url = action.params['url'] ?? '';
        final method = action.params['method'] ?? 'GET';
        final body = action.params['body'] ?? '';
        if (url.isEmpty) {
          _logService.log('error', 'Webhook: URL vacía');
          return;
        }

        try {
          final uri = Uri.parse(url);
          if (method.toUpperCase() == 'POST') {
            final response = await http
                .post(
                  uri,
                  headers: {'Content-Type': 'application/json'},
                  body: body.isNotEmpty ? body : null,
                )
                .timeout(const Duration(seconds: 15));
            _logService.log(
                'action', 'Webhook POST $url → ${response.statusCode}');
          } else {
            final response = await http
                .get(uri)
                .timeout(const Duration(seconds: 15));
            _logService.log(
                'action', 'Webhook GET $url → ${response.statusCode}');
          }
        } catch (e) {
          _logService.log('error', 'Webhook falló: $url → $e');
        }
        break;

      case 'intent':
        final urlStr = action.params['url'] ?? '';
        if (urlStr.isEmpty) {
          _logService.log('error', 'Intent: URL vacía, no se puede abrir');
          return;
        }
        _logService.log('action', 'Intent: preparando apertura de URL: $urlStr');
        if (_onIntentAction != null) {
          _logService.log('action', 'Intent: delegando a callback (notificación + IPC)');
          _onIntentAction!(urlStr);
        } else {
          try {
            final uri = Uri.parse(urlStr);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            _logService.log('action', 'Intent: URL abierta directamente: $urlStr');
          } catch (e) {
            _logService.log('error', 'Intent: error abriendo URL: $urlStr → $e');
          }
        }
        break;

      case 'publish':
        final topic = action.params['topic'] ?? '';
        final payload = action.params['payload'] ?? '';
        if (topic.isNotEmpty) {
          _mqttService.publish(topic, payload);
        }
        _logService.log('action', 'Publicado: $topic → $payload');
        break;
    }
  }

  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
