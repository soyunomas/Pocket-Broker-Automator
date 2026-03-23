import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // Initialize services
  final logService = LogService();
  await logService.init();
  await BackgroundServiceController.initialize();

  runApp(PocketBrokerApp(logService: logService));
}

class PocketBrokerApp extends StatelessWidget {
  final LogService logService;

  const PocketBrokerApp({super.key, required this.logService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(logService: logService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(logService: logService)..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => AutomationProvider()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => LogProvider(logService: logService),
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
