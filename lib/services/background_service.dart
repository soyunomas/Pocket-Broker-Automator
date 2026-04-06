import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/connection_profile.dart';
import '../models/dashboard_button.dart';
import '../models/automation_rule.dart';
import '../models/log_entry.dart';
import '../models/broker_config.dart';
import '../models/monitor_widget.dart';
import '../models/sensor_reading.dart';
import '../utils/debug_tracer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'mqtt_client_service.dart';
import 'log_service.dart';
import 'automation_engine.dart';

const notificationChannelId = 'pocket_broker_foreground';
const notificationId = 888;
const urlNotificationChannelId = 'pocket_broker_url_actions';
int _urlNotificationId = 9000;

class BackgroundServiceController {
  static final _service = FlutterBackgroundService();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    final plugin = FlutterLocalNotificationsPlugin();

    // Initialize the plugin properly before using it
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    const channel = AndroidNotificationChannel(
      notificationChannelId,
      'PocketBroker Service',
      description: 'Mantiene la conexión MQTT activa',
      importance: Importance.low,
    );

    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'PocketBroker Automator',
        initialNotificationContent: 'Iniciando…',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
      ),
    );

    _initialized = true;
  }

  static Future<bool> start() async {
    try {
      await initialize();
      await _service.startService();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> stop() async {
    _service.invoke('stop');
  }

  static Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  // --- IPC: UI → Service ---

  static void connectToProfile(Map<String, dynamic> profileMap) {
    _service.invoke('connect', profileMap);
  }

  static void disconnect() {
    _service.invoke('disconnect');
  }

  static void publish(String topic, String payload,
      {int qos = 0, bool retain = false}) {
    _service.invoke('publish', {
      'topic': topic,
      'payload': payload,
      'qos': qos,
      'retain': retain,
    });
  }

  static void subscribe(String topic) {
    _service.invoke('subscribe', {'topic': topic});
  }

  static void unsubscribe(String topic) {
    _service.invoke('unsubscribe', {'topic': topic});
  }

  static void updateRules(List<Map<String, dynamic>> rulesJson) {
    _service.invoke('updateRules', {'rules': rulesJson});
  }

  static void syncSubscriptions() {
    _service.invoke('syncSubscriptions');
  }

  static void requestState() {
    _service.invoke('requestState');
  }

  static void requestDebugTrace() {
    _service.invoke('requestDebugTrace');
  }

  static void clearDebugTrace() {
    _service.invoke('clearDebugTrace');
  }

  // --- IPC: Service → UI (streams) ---

  static Stream<Map<String, dynamic>?> on(String event) {
    return _service.on(event);
  }
}

// ======================================================================
// BACKGROUND ISOLATE — runs independently of UI
// ======================================================================

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final trace = DebugTracer.instance;
  trace.log('BG_SVC', '═══ BACKGROUND SERVICE STARTING ═══');

  // Init Hive in this isolate
  await Hive.initFlutter();
  _registerAdapters();
  trace.log('BG_SVC', 'Hive inicializado y adaptadores registrados');

  // Create services (logService first so notification callbacks can use it)
  final mqtt = MqttClientService();
  final logService = LogService();
  await logService.init();
  trace.log('BG_SVC', 'MQTT y LogService creados');

  // Create URL notification channel for clickable URL notifications
  final notifPlugin = FlutterLocalNotificationsPlugin();
  await notifPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (response) async {
      final url = response.payload;
      logService.log('action', 'Notificación tocada, payload: $url');
      if (url != null && url.isNotEmpty) {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          logService.log('action', 'URL abierta desde notificación: $url');
        } catch (e) {
          logService.log('error', 'Error abriendo URL desde notificación: $url → $e');
        }
      } else {
        logService.log('error', 'Notificación sin URL en payload');
      }
    },
  );
  await notifPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        urlNotificationChannelId,
        'Acciones URL',
        description: 'Notificaciones con URLs de reglas de automatización',
        importance: Importance.high,
      ));

  // Forward logs from background isolate to UI so LogProvider can refresh.
  // Skip 'received' type: the UI already creates those from the 'message' IPC event.
  logService.logStream.listen((entry) {
    if (entry.type == 'received') return;
    service.invoke('logEntry', {
      'type': entry.type,
      'message': entry.message,
    });
  });

  final engine = AutomationEngine(mqtt, logService);
  trace.log('BG_SVC', 'AutomationEngine creado');

  // Mutable set of monitor topics — used by the message forwarder to filter
  final activeMonitorTopics = <String>{};

  // Load saved monitor widgets and subscribe to their topics
  final monitorBox = await Hive.openBox<MonitorWidget>('monitor_widgets');
  activeMonitorTopics.addAll(monitorBox.values.map((w) => w.topic));
  trace.log('BG_SVC', 'Monitor topics cargados: $activeMonitorTopics');
  for (final topic in activeMonitorTopics) {
    mqtt.subscribe(topic);
  }
  logService.log('system',
      'Suscrito a ${activeMonitorTopics.length} topics de monitores al iniciar');

  // Load saved rules and start engine (protect monitor topics)
  final rulesBox = await Hive.openBox<AutomationRule>('automation_rules');
  final savedRules = rulesBox.values.toList();
  trace.log('BG_SVC', 'Reglas cargadas de Hive: ${savedRules.length}');
  for (final r in savedRules) {
    trace.log('BG_SVC', '  regla Hive: "${r.name}" topic="${r.topic}" enabled=${r.enabled}');
  }
  engine.loadRules(savedRules, protectedTopics: activeMonitorTopics);

  // Delegate intent/URL actions: try UI first, also show notification as fallback
  engine.onIntentAction = (url) {
    logService.log('action', 'Background: enviando launchUrl IPC a UI: $url');
    service.invoke('launchUrl', {'url': url});
    logService.log('action', 'Background: mostrando notificación clickable para: $url');
    _showUrlNotification(notifPlugin, url, logService);
  };

  engine.start();
  trace.log('BG_SVC', 'Engine iniciado');

  // Forward connection state to UI and re-subscribe all topics on reconnect
  mqtt.connectionStateStream.listen((state) {
    trace.log('BG_SVC', 'connectionState cambió: ${state.name}');
    service.invoke('connectionState', {'state': state.name});

    // When connection is (re)established, ensure monitor widget topics are subscribed
    // (rule topics are handled by the AutomationEngine's own listener)
    if (state == ClientConnectionState.connected) {
      for (final topic in activeMonitorTopics) {
        mqtt.subscribe(topic);
      }
    }

    // Update notification
    if (service is AndroidServiceInstance) {
      final alias = mqtt.activeProfile?.alias ?? '';
      switch (state) {
        case ClientConnectionState.connected:
          service.setForegroundNotificationInfo(
            title: 'PocketBroker Automator',
            content: 'Conectado a $alias',
          );
          break;
        case ClientConnectionState.connecting:
          service.setForegroundNotificationInfo(
            title: 'PocketBroker Automator',
            content: 'Reconectando a $alias…',
          );
          break;
        case ClientConnectionState.disconnected:
          service.setForegroundNotificationInfo(
            title: 'PocketBroker Automator',
            content: alias.isEmpty ? 'Sin conexión' : 'Desconectado',
          );
          break;
      }
    }
  });

  // Forward received messages to UI — ONLY if a monitor widget cares about this topic.
  // This avoids flooding the IPC channel and Hive with irrelevant messages
  // from public brokers.  Rule evaluation is handled by AutomationEngine
  // which has its own listener on the same messageStream.
  mqtt.messageStream.listen((msg) {
    // Check exact match first (O(1)), then wildcard monitor topics
    bool forward = activeMonitorTopics.contains(msg.topic);
    if (!forward) {
      for (final mt in activeMonitorTopics) {
        if ((mt.contains('+') || mt.contains('#')) &&
            _topicMatchesBg(mt, msg.topic)) {
          forward = true;
          break;
        }
      }
    }
    if (forward) {
      service.invoke('message', {
        'topic': msg.topic,
        'payload': msg.payload,
      });
    }
  });

  // --- Handle commands from UI ---

  service.on('connect').listen((event) async {
    if (event == null) return;
    trace.log('IPC', 'connect recibido: alias="${event['alias']}" host="${event['host']}:${event['port']}" ssl=${event['ssl']}');
    final profile = ConnectionProfile(
      id: event['id'] as String?,
      alias: event['alias'] as String? ?? '',
      host: event['host'] as String? ?? '',
      port: event['port'] as int? ?? 1883,
      username: event['username'] as String? ?? '',
      password: event['password'] as String? ?? '',
      clientId: event['clientId'] as String?,
      ssl: event['ssl'] as bool? ?? false,
    );
    final ok = await mqtt.connect(profile);
    trace.log('IPC', 'connect resultado: ${ok ? "OK" : "FAIL"} para ${profile.alias}');
    logService.log(
        ok ? 'system' : 'error',
        ok
            ? 'Conectado a ${profile.alias}'
            : 'Fallo conexión a ${profile.alias}');
  });

  service.on('disconnect').listen((_) async {
    final alias = mqtt.activeProfile?.alias ?? '';
    trace.log('IPC', 'disconnect recibido (alias actual: "$alias")');
    await mqtt.disconnect();
    trace.log('IPC', 'disconnect completado');
    logService.log('system', 'Desconectado de $alias');
  });

  service.on('publish').listen((event) {
    if (event == null) return;
    mqtt.publish(
      event['topic'] as String,
      event['payload'] as String,
      qos: event['qos'] as int? ?? 0,
      retain: event['retain'] as bool? ?? false,
    );
    logService.log('sent', '${event['topic']} → ${event['payload']}');
  });

  service.on('subscribe').listen((event) {
    if (event == null) return;
    mqtt.subscribe(event['topic'] as String);
  });

  service.on('unsubscribe').listen((event) {
    if (event == null) return;
    mqtt.unsubscribe(event['topic'] as String);
  });

  service.on('updateRules').listen((event) async {
    if (event == null) return;
    
    // Parse rules directly from IPC to avoid Hive memory cache stale data across isolates
    final rulesJson = event['rules'] as List<dynamic>? ?? [];
    trace.log('IPC', 'updateRules recibido: ${rulesJson.length} reglas en JSON');
    final rules = rulesJson
        .map((r) => AutomationRule.fromMap(Map<String, dynamic>.from(r)))
        .toList();
    for (final r in rules) {
      trace.log('IPC', '  regla IPC: "${r.name}" topic="${r.topic}" enabled=${r.enabled} cond=${r.condition.type}/${r.condition.value} actions=${r.actions.length}');
    }

    // Refresh monitor topics set and use as protected
    try {
      final mBox = Hive.box<MonitorWidget>('monitor_widgets');
      activeMonitorTopics
        ..clear()
        ..addAll(mBox.values.map((w) => w.topic));
    } catch (_) {}
    trace.log('IPC', 'Monitor topics protegidos: $activeMonitorTopics');

    engine.loadRules(rules, protectedTopics: activeMonitorTopics);
    trace.log('IPC', 'updateRules completado — engine.loadRules() llamado');
    logService.log('system',
        'Reglas actualizadas: ${rules.where((r) => r.enabled).length} activas');
  });

  // Sync all subscriptions (monitor widgets + rules) — triggered by UI
  service.on('syncSubscriptions').listen((_) async {
    // Re-read monitor widgets and refresh the activeMonitorTopics set
    try {
      final mBox = await Hive.openBox<MonitorWidget>('monitor_widgets');
      await mBox.close();
      final freshMBox = await Hive.openBox<MonitorWidget>('monitor_widgets');
      activeMonitorTopics
        ..clear()
        ..addAll(freshMBox.values.map((w) => w.topic));
      for (final topic in activeMonitorTopics) {
        mqtt.subscribe(topic);
      }
      trace.log('IPC', 'syncSubscriptions: activeMonitorTopics=$activeMonitorTopics');
      logService.log('system',
          'syncSubscriptions: ${activeMonitorTopics.length} topics de monitores sincronizados');
    } catch (e) {
      logService.log('error', 'syncSubscriptions: error leyendo monitores: $e');
    }
  });

  service.on('requestState').listen((_) {
    service.invoke('connectionState', {
      'state': mqtt.connectionState.name,
      'alias': mqtt.activeProfile?.alias ?? '',
      'host': mqtt.activeProfile?.host ?? '',
    });
  });

  service.on('clearDebugTrace').listen((_) {
    trace.log('IPC', 'clearDebugTrace recibido');
    trace.clear();
  });

  service.on('requestDebugTrace').listen((_) {
    trace.log('IPC', 'requestDebugTrace recibido — enviando ${trace.length} líneas');
    // Send trace in chunks to avoid IPC size limits
    final allLines = trace.lines();
    const chunkSize = 50;
    final totalChunks = (allLines.length / chunkSize).ceil();
    for (var i = 0; i < allLines.length; i += chunkSize) {
      final end = (i + chunkSize) > allLines.length ? allLines.length : i + chunkSize;
      final chunk = allLines.sublist(i, end).join('\n');
      final chunkIndex = (i / chunkSize).floor();
      service.invoke('debugTrace', {
        'chunk': chunk,
        'index': chunkIndex,
        'total': totalChunks,
        'totalLines': allLines.length,
      });
    }
    if (allLines.isEmpty) {
      service.invoke('debugTrace', {
        'chunk': '',
        'index': 0,
        'total': 1,
        'totalLines': 0,
      });
    }
  });

  service.on('stop').listen((_) async {
    engine.stop();
    engine.dispose();
    await mqtt.disconnect();
    mqtt.dispose();
    logService.dispose();
    if (service is AndroidServiceInstance) {
      service.stopSelf();
    }
  });

  // Set initial notification
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'PocketBroker Automator',
      content: 'Servicio activo — sin conexión',
    );
  }

  // Keep-alive timer: only logs status, reconnection is handled by MqttClientService
  Timer.periodic(const Duration(seconds: 60), (timer) {
    final state = mqtt.connectionState;
    final profile = mqtt.activeProfile;
    if (state == ClientConnectionState.disconnected &&
        profile != null &&
        !mqtt.isIntentionalDisconnect) {
      // The MqttClientService already handles reconnection via backoff.
      // This timer is just a safety net — it does NOT call connect() directly.
      logService.log('system',
          'Keep-alive check: desconectado de ${profile.alias}, reconexión pendiente');
    }
  });
}

Future<void> _showUrlNotification(
    FlutterLocalNotificationsPlugin plugin, String url, LogService logService) async {
  final id = _urlNotificationId++;
  try {
    await plugin.show(
      id,
      'Abrir URL',
      url,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          urlNotificationChannelId,
          'Acciones URL',
          channelDescription: 'Notificaciones con URLs de reglas de automatización',
          importance: Importance.high,
          priority: Priority.high,
          autoCancel: true,
        ),
      ),
      payload: url,
    );
    logService.log('action', 'Notificación URL mostrada (id=$id): $url');
  } catch (e) {
    logService.log('error', 'Error mostrando notificación URL: $url → $e');
  }
}

/// MQTT topic matching for the background isolate message forwarder.
bool _topicMatchesBg(String pattern, String topic) {
  if (pattern == topic) return true;
  final pp = pattern.split('/');
  final tp = topic.split('/');
  for (var i = 0; i < pp.length; i++) {
    if (pp[i] == '#') return true;
    if (i >= tp.length) return false;
    if (pp[i] == '+') continue;
    if (pp[i] != tp[i]) return false;
  }
  return pp.length == tp.length;
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ConnectionProfileAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(DashboardButtonAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(RuleConditionAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(RuleActionAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(AutomationRuleAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(LogEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(BrokerConfigAdapter());
  }
  if (!Hive.isAdapterRegistered(7)) {
    Hive.registerAdapter(MonitorWidgetAdapter());
  }
  if (!Hive.isAdapterRegistered(8)) {
    Hive.registerAdapter(SensorReadingAdapter());
  }
}
