import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/connection_profile.dart';
import 'models/dashboard_button.dart';
import 'models/automation_rule.dart';
import 'models/log_entry.dart';
import 'models/broker_config.dart';

import 'services/log_service.dart';
import 'services/background_service.dart';

import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/automation_provider.dart';
import 'providers/log_provider.dart';
import 'providers/broker_provider.dart';

import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register Hive adapters
  Hive.registerAdapter(ConnectionProfileAdapter());
  Hive.registerAdapter(DashboardButtonAdapter());
  Hive.registerAdapter(RuleConditionAdapter());
  Hive.registerAdapter(RuleActionAdapter());
  Hive.registerAdapter(AutomationRuleAdapter());
  Hive.registerAdapter(LogEntryAdapter());
  Hive.registerAdapter(BrokerConfigAdapter());

  // Request notification permission early (Android 13+)
  final notifStatus = await Permission.notification.status;
  if (!notifStatus.isGranted) {
    await Permission.notification.request();
  }

  // Initialize notification plugin in main isolate to handle notification taps
  final notifPlugin = FlutterLocalNotificationsPlugin();
  await notifPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (response) async {
      final url = response.payload;
      if (url != null && url.isNotEmpty) {
        try {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (_) {}
      }
    },
  );

  // Check if app was launched by tapping a notification
  final launchDetails = await notifPlugin.getNotificationAppLaunchDetails();
  final launchPayload = launchDetails?.notificationResponse?.payload;

  // Initialize services
  final logService = LogService();
  await logService.init();
  await BackgroundServiceController.initialize();

  runApp(PocketBrokerApp(logService: logService, initialUrl: launchPayload));
}

class PocketBrokerApp extends StatefulWidget {
  final LogService logService;
  final String? initialUrl;

  const PocketBrokerApp({super.key, required this.logService, this.initialUrl});

  @override
  State<PocketBrokerApp> createState() => _PocketBrokerAppState();
}

class _PocketBrokerAppState extends State<PocketBrokerApp> {
  @override
  void initState() {
    super.initState();
    // If app was launched by tapping a URL notification, open the URL
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 500), () {
        launchUrl(Uri.parse(widget.initialUrl!),
            mode: LaunchMode.externalApplication);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              ConnectionProvider(logService: widget.logService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              DashboardProvider(logService: widget.logService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => AutomationProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => LogProvider(logService: widget.logService),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              BrokerProvider(logService: widget.logService)..init(),
        ),
      ],
      child: MaterialApp(
        title: 'PocketBroker Automator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardTheme: CardTheme(
            color: Colors.grey[900],
            elevation: 2,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
