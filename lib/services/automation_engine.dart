import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/automation_rule.dart';
import '../utils/debug_tracer.dart';
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

  // --- Topic index for O(1) dispatch ---
  /// Exact topic → list of enabled rules listening on that exact topic.
  final Map<String, List<AutomationRule>> _exactIndex = {};
  /// Rules with wildcard topics (containing '+' or '#').
  final List<AutomationRule> _wildcardRules = [];

  /// Callback to delegate URL/intent actions to the UI isolate.
  /// Set this when running in a background isolate that cannot launch URLs.
  void Function(String url)? _onIntentAction;

  final _trace = DebugTracer.instance;

  AutomationEngine(this._mqttService, this._logService) {
    _trace.log('ENGINE', 'AutomationEngine creado');
  }

  set onIntentAction(void Function(String url)? callback) =>
      _onIntentAction = callback;

  void loadRules(List<AutomationRule> rules, {Set<String>? protectedTopics}) {
    _trace.log('ENGINE', 'loadRules() llamado con ${rules.length} reglas (protectedTopics=${protectedTopics?.length ?? 0})');
    for (final r in rules) {
      _trace.log('ENGINE', '  regla: "${r.name}" topic="${r.topic}" enabled=${r.enabled} cond=${r.condition.type}/${r.condition.value} actions=${r.actions.length}');
    }

    // Compute new topics needed by enabled rules
    final newTopics = rules
        .where((r) => r.enabled)
        .map((r) => r.topic)
        .toSet();

    _trace.log('ENGINE', 'Topics nuevos requeridos: $newTopics');
    _trace.log('ENGINE', 'Topics suscritos anteriormente: $_subscribedRuleTopics');

    // Unsubscribe topics no longer needed by any enabled rule
    // but only if they're not protected (e.g. used by monitor widgets)
    final toRemove = _subscribedRuleTopics.difference(newTopics);
    _trace.log('ENGINE', 'Topics a eliminar: $toRemove');
    for (final topic in toRemove) {
      if (protectedTopics != null && protectedTopics.contains(topic)) {
        _trace.log('ENGINE', '  topic "$topic" protegido, no se desuscribe');
        continue;
      }
      _trace.log('ENGINE', '  desuscribiendo topic "$topic"');
      _mqttService.unsubscribe(topic);
    }

    _rules.clear();
    _rules.addAll(rules);
    _subscribedRuleTopics
      ..clear()
      ..addAll(newTopics);
    _rebuildIndex();
    _trace.log('ENGINE', 'Reglas cargadas: ${_rules.length} total, ${_rules.where((r) => r.enabled).length} activas');
    _trace.log('ENGINE', 'Índice: ${_exactIndex.length} topics exactos, ${_wildcardRules.length} reglas wildcard');
    _subscribeToRuleTopics();
  }

  void _rebuildIndex() {
    _exactIndex.clear();
    _wildcardRules.clear();
    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.topic.contains('+') || rule.topic.contains('#')) {
        _wildcardRules.add(rule);
      } else {
        _exactIndex.putIfAbsent(rule.topic, () => []).add(rule);
      }
    }
  }

  void start() {
    _trace.log('ENGINE', 'start() llamado — cancelando suscripciones anteriores');
    _messageSubscription?.cancel();
    _messageSubscription = _mqttService.messageStream.listen(_evaluateMessage);
    _trace.log('ENGINE', 'Escuchando messageStream');

    // Re-subscribe to rule topics whenever connection is (re)established
    _connectionSubscription?.cancel();
    _connectionSubscription =
        _mqttService.connectionStateStream.listen((state) {
      _trace.log('ENGINE', 'connectionStateStream evento: ${state.name}');
      if (state == ClientConnectionState.connected) {
        _trace.log('ENGINE', 'Conexión establecida — re-suscribiendo ${_rules.where((r) => r.enabled).length} reglas');
        _logService.log('system',
            'Conexión establecida — suscribiendo ${_rules.where((r) => r.enabled).length} reglas');
        _subscribeToRuleTopics();
      }
    });

    _subscribeToRuleTopics();
    _trace.log('ENGINE', 'start() completado');
  }

  void stop() {
    _trace.log('ENGINE', 'stop() llamado');
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
  }

  void _subscribeToRuleTopics() {
    _trace.log('ENGINE', '_subscribeToRuleTopics() — ${_rules.length} reglas totales');
    int subscribed = 0;
    for (final rule in _rules) {
      if (rule.enabled) {
        _trace.log('ENGINE', '  suscribiendo topic "${rule.topic}" (regla "${rule.name}")');
        _mqttService.subscribe(rule.topic);
        subscribed++;
      } else {
        _trace.log('ENGINE', '  SKIP regla deshabilitada "${rule.name}" topic="${rule.topic}"');
      }
    }
    _trace.log('ENGINE', '_subscribeToRuleTopics() completado — $subscribed topics suscritos');
  }

  void _evaluateMessage(ReceivedMqttMessage message) {
    // --- Pre-filter: build candidate list using the index (O(1) + O(wildcards)) ---
    final candidates = <AutomationRule>[];

    // O(1) exact lookup
    final exact = _exactIndex[message.topic];
    if (exact != null) candidates.addAll(exact);

    // O(wildcardRules) — typically very few
    for (final rule in _wildcardRules) {
      if (_topicMatches(rule.topic, message.topic)) {
        candidates.add(rule);
      }
    }

    // No candidates → skip entirely (no logging, no iteration)
    if (candidates.isEmpty) return;

    _trace.log('EVAL', '══════ MENSAJE CON CANDIDATOS ══════');
    _trace.log('EVAL', 'topic="${message.topic}" payload="${message.payload}" (${message.payload.length} chars)');
    _trace.log('EVAL', '${candidates.length} regla(s) candidata(s) (de ${_exactIndex.length} exact + ${_wildcardRules.length} wildcard)');

    int matched = 0;
    for (var i = 0; i < candidates.length; i++) {
      final rule = candidates[i];
      _trace.log('EVAL', '  [${i + 1}/${candidates.length}] "${rule.name}" topic="${rule.topic}" → TOPIC MATCH');
      final condResult = _conditionMatches(rule.condition, message.payload);
      _trace.log('EVAL', '    condición: type="${rule.condition.type}" value="${rule.condition.value}" → ${condResult ? "MATCH" : "NO MATCH"}');
      if (condResult) {
        final now = DateTime.now();
        final lastTime = _lastTriggered[rule.name];
        if (lastTime != null &&
            now.difference(lastTime).inMilliseconds < 1000) {
          final elapsed = now.difference(lastTime).inMilliseconds;
          _trace.log('EVAL', '    ⛔ COOLDOWN: ${elapsed}ms (< 1000ms)');
          continue;
        }
        _lastTriggered[rule.name] = now;
        matched++;
        _trace.log('EVAL', '    ✅ EJECUTANDO acciones (${rule.actions.length} acciones)');
        _executeActions(rule, message.payload);
      }
    }
    if (matched > 0) {
      _trace.log('EVAL', '$matched regla(s) activada(s) para ${message.topic}');
      _logService.log('system', '$matched regla(s) activada(s) para ${message.topic}');
    }
    _trace.log('EVAL', '══════ FIN ══════');
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
    _trace.log('ACTION', 'Fire-and-forget para regla "${rule.name}" con ${rule.actions.length} acciones');
    _executeActionsSequentially(rule, rawPayload);
  }

  Future<void> _executeActionsSequentially(
      AutomationRule rule, String rawPayload) async {
    _trace.log('ACTION', '▶ Inicio ejecución secuencial regla "${rule.name}" (${rule.actions.length} acciones)');
    await _logService.log('action',
        'Regla "${rule.name}" activada — ${rule.actions.length} acción(es)');
    for (var i = 0; i < rule.actions.length; i++) {
      final action = rule.actions[i];
      final label = '${action.type} [${i + 1}/${rule.actions.length}]';
      _trace.log('ACTION', '  acción ${i + 1}: type="${action.type}" params=${action.params}');
      try {
        await _logService.log('action', '↳ Ejecutando $label...');
        await _executeAction(action, rawPayload);
        _trace.log('ACTION', '  ✓ acción ${i + 1} completada');
        await _logService.log('action', '✓ $label completada');
      } catch (e, st) {
        _trace.log('ACTION', '  ✗ acción ${i + 1} EXCEPCIÓN: $e\n$st');
        await _logService.log('error', '✗ $label falló: $e');
      }
    }
    _trace.log('ACTION', '■ Fin ejecución regla "${rule.name}"');
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
