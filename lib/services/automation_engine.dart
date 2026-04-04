import 'dart:async';
import 'dart:convert';
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
  final Set<String> _subscribedRuleTopics = {};
  final Map<String, DateTime> _lastTriggered = {};
  StreamSubscription<ReceivedMqttMessage>? _messageSubscription;
  StreamSubscription<ClientConnectionState>? _connectionSubscription;

  /// Callback to delegate URL/intent actions to the UI isolate.
  /// Set this when running in a background isolate that cannot launch URLs.
  void Function(String url)? _onIntentAction;

  AutomationEngine(this._mqttService, this._logService);

  set onIntentAction(void Function(String url)? callback) =>
      _onIntentAction = callback;

  void loadRules(List<AutomationRule> rules, {Set<String>? protectedTopics}) {
    // Compute new topics needed by enabled rules
    final newTopics = rules
        .where((r) => r.enabled)
        .map((r) => r.topic)
        .toSet();

    // Unsubscribe topics no longer needed by any enabled rule
    // but only if they're not protected (e.g. used by monitor widgets)
    final toRemove = _subscribedRuleTopics.difference(newTopics);
    for (final topic in toRemove) {
      if (protectedTopics != null && protectedTopics.contains(topic)) continue;
      _mqttService.unsubscribe(topic);
    }

    _rules.clear();
    _rules.addAll(rules);
    _subscribedRuleTopics
      ..clear()
      ..addAll(newTopics);
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
        final now = DateTime.now();
        final lastTime = _lastTriggered[rule.name];
        if (lastTime != null &&
            now.difference(lastTime).inMilliseconds < 1000) {
          _logService.log('system',
              'Regla "${rule.name}" bloqueada por cooldown (< 1s desde última ejecución)');
          continue;
        }
        _lastTriggered[rule.name] = now;
        matched++;
        _executeActions(rule, message.payload);
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

  void _executeActions(AutomationRule rule, String rawPayload) {
    // Fire-and-forget a nivel de regla: no bloquea _evaluateMessage,
    // pero las acciones dentro de la misma regla se ejecutan en secuencia
    // para evitar conflictos (ej. dos sonidos simultáneos).
    _executeActionsSequentially(rule, rawPayload);
  }

  Future<void> _executeActionsSequentially(
      AutomationRule rule, String rawPayload) async {
    await _logService.log('action',
        'Regla "${rule.name}" activada — ${rule.actions.length} acción(es)');
    for (var i = 0; i < rule.actions.length; i++) {
      final action = rule.actions[i];
      final label = '${action.type} [${i + 1}/${rule.actions.length}]';
      try {
        await _logService.log('action', '↳ Ejecutando $label...');
        await _executeAction(action, rawPayload);
        await _logService.log('action', '✓ $label completada');
      } catch (e) {
        await _logService.log('error', '✗ $label falló: $e');
      }
    }
    await _logService.log('action',
        'Regla "${rule.name}" — todas las acciones procesadas');
  }

  Future<String> _interpolate(String template, String rawPayload) async {
    var result = template.replaceAll('{{payload}}', rawPayload);

    Map<String, dynamic>? jsonMap;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is Map<String, dynamic>) {
        jsonMap = decoded;
      }
    } catch (e) {
      if (template.contains('{{') && template.contains('}}') && template != '{{payload}}') {
        await _logService.log('warning',
            'Payload no es JSON válido, no se pueden resolver variables de plantilla: $e');
      }
    }

    if (jsonMap != null) {
      for (final entry in jsonMap.entries) {
        result = result.replaceAll('{{${entry.key}}}', entry.value.toString());
      }
    }

    if (result != template) {
      await _logService.log('action', 'Interpolando variables en la acción: $result');
    }

    return result;
  }

  Future<void> _executeAction(RuleAction action, String rawPayload) async {
    switch (action.type) {
      case 'sound':
        final file = await _interpolate(action.params['file'] ?? '', rawPayload);
        if (file.isNotEmpty) {
          final player = AudioPlayer();
          player.onPlayerComplete.listen((_) => player.dispose());
          await player.play(DeviceFileSource(file));
        }
        await _logService.log(
            'action', 'Sonido reproducido: ${file.split('/').last}');
        break;

      case 'webhook':
        final url = await _interpolate(action.params['url'] ?? '', rawPayload);
        final method = action.params['method'] ?? 'GET';
        final body = await _interpolate(action.params['body'] ?? '', rawPayload);
        if (url.isEmpty) {
          await _logService.log('error', 'Webhook: URL vacía');
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
            await _logService.log(
                'action', 'Webhook POST $url → ${response.statusCode}');
          } else {
            final response = await http
                .get(uri)
                .timeout(const Duration(seconds: 15));
            await _logService.log(
                'action', 'Webhook GET $url → ${response.statusCode}');
          }
        } catch (e) {
          await _logService.log('error', 'Webhook falló: $url → $e');
        }
        break;

      case 'intent':
        final urlStr = await _interpolate(action.params['url'] ?? '', rawPayload);
        if (urlStr.isEmpty) {
          await _logService.log('error', 'Intent: URL vacía, no se puede abrir');
          return;
        }
        await _logService.log('action', 'Intent: preparando apertura de URL: $urlStr');
        if (_onIntentAction != null) {
          await _logService.log('action', 'Intent: delegando a callback (notificación + IPC)');
          _onIntentAction!(urlStr);
        } else {
          try {
            final uri = Uri.parse(urlStr);
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            await _logService.log('action', 'Intent: URL abierta directamente: $urlStr');
          } catch (e) {
            await _logService.log('error', 'Intent: error abriendo URL: $urlStr → $e');
          }
        }
        break;

      case 'publish':
        final topic = await _interpolate(action.params['topic'] ?? '', rawPayload);
        final payload = await _interpolate(action.params['payload'] ?? '', rawPayload);
        if (topic.isNotEmpty) {
          _mqttService.publish(topic, payload);
        }
        await _logService.log('action', 'Publicado: $topic → $payload');
        break;
    }
  }

  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
  }
}
