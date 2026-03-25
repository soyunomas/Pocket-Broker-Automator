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

  static void requestState() {
    _service.invoke('requestState');
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

  // Init Hive in this isolate
  await Hive.initFlutter();
  _registerAdapters();

  // Create services (logService first so notification callbacks can use it)
  final mqtt = MqttClientService();
  final logService = LogService();
  await logService.init();

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

  final engine = AutomationEngine(mqtt, logService);

  // Load saved rules and start engine
  final rulesBox = await Hive.openBox<AutomationRule>('automation_rules');
  engine.loadRules(rulesBox.values.toList());

  // Delegate intent/URL actions: try UI first, also show notification as fallback
  engine.onIntentAction = (url) {
    logService.log('action', 'Background: enviando launchUrl IPC a UI: $url');
    service.invoke('launchUrl', {'url': url});
    logService.log('action', 'Background: mostrando notificación clickable para: $url');
    _showUrlNotification(notifPlugin, url, logService);
  };

  engine.start();

  // Forward connection state to UI
  mqtt.connectionStateStream.listen((state) {
    service.invoke('connectionState', {'state': state.name});

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

  // Forward received messages to UI
  mqtt.messageStream.listen((msg) {
    logService.log('received', '${msg.topic} → ${msg.payload}');
    service.invoke('message', {
      'topic': msg.topic,
      'payload': msg.payload,
    });
  });

  // --- Handle commands from UI ---

  service.on('connect').listen((event) async {
    if (event == null) return;
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
    logService.log(
        ok ? 'system' : 'error',
        ok
            ? 'Conectado a ${profile.alias}'
            : 'Fallo conexión a ${profile.alias}');
  });

  service.on('disconnect').listen((_) async {
    final alias = mqtt.activeProfile?.alias ?? '';
    await mqtt.disconnect();
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
    // Re-read from Hive — close and reopen to get fresh data from UI isolate
    final box = await Hive.openBox<AutomationRule>('automation_rules');
    await box.close();
    final freshBox = await Hive.openBox<AutomationRule>('automation_rules');
    final rules = freshBox.values.toList();
    engine.loadRules(rules);
    logService.log('system',
        'Reglas actualizadas: ${rules.where((r) => r.enabled).length} activas');
  });

  service.on('requestState').listen((_) {
    service.invoke('connectionState', {
      'state': mqtt.connectionState.name,
      'alias': mqtt.activeProfile?.alias ?? '',
      'host': mqtt.activeProfile?.host ?? '',
    });
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
}
