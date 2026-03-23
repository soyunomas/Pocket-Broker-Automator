import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/mqtt_client_service.dart';
import 'connections_screen.dart';
import 'dashboard_screen.dart';
import 'automations_screen.dart';
import 'logs_screen.dart';
import 'broker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    ConnectionsScreen(),
    BrokerScreen(),
    AutomationsScreen(),
    LogsScreen(),
  ];

  final _titles = const [
    'Panel',
    'Conexiones',
    'Broker',
    'Automatizaciones',
    'Logs',
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connProvider, _) {
        final isConnected =
            connProvider.connectionState == ClientConnectionState.connected;
        final statusColor = isConnected
            ? Colors.greenAccent
            : connProvider.connectionState == ClientConnectionState.connecting
                ? Colors.orangeAccent
                : Colors.redAccent;

        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_currentIndex]),
            actions: [
              if (connProvider.serviceRunning)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.sync, color: Colors.greenAccent, size: 16),
                ),
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connProvider.activeAlias.isNotEmpty
                          ? connProvider.activeAlias
                          : 'Sin conexión',
                      style: TextStyle(fontSize: 11, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: _screens[_currentIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Panel',
              ),
              NavigationDestination(
                icon: Icon(Icons.link_outlined),
                selectedIcon: Icon(Icons.link),
                label: 'Conexiones',
              ),
              NavigationDestination(
                icon: Icon(Icons.dns_outlined),
                selectedIcon: Icon(Icons.dns),
                label: 'Broker',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'Reglas',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Logs',
              ),
            ],
          ),
        );
      },
    );
  }
}
