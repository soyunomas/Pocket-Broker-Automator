import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../services/mqtt_client_service.dart';
import 'connections_screen.dart';
import 'dashboard_screen.dart';
import 'monitor_screen.dart';
import 'automations_screen.dart';
import 'logs_screen.dart';
import 'broker_screen.dart';

// Cambiamos el orden para que monitor sea el primero lógicamente
enum _PanelMode { monitor, controles }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  // Inicializamos en Monitor por defecto
  _PanelMode _panelMode = _PanelMode.monitor;

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

        Widget body;
        if (_currentIndex == 0) {
          // Cambiamos la condición de dibujado
          body = _panelMode == _PanelMode.monitor
              ? const MonitorScreen()
              : const DashboardScreen();
        } else {
          const screens = [
            SizedBox.shrink(), // placeholder, never shown
            ConnectionsScreen(),
            BrokerScreen(),
            AutomationsScreen(),
            LogsScreen(),
          ];
          body = screens[_currentIndex];
        }

        return Scaffold(
          appBar: AppBar(
            title: _currentIndex == 0
                ? SizedBox(
                    height: 32,
                    child: SegmentedButton<_PanelMode>(
                      // Invertimos el orden visual de los botones
                      segments: const [
                        ButtonSegment(
                          value: _PanelMode.monitor,
                          label: Text('Monitor', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.monitor_heart, size: 16),
                        ),
                        ButtonSegment(
                          value: _PanelMode.controles,
                          label: Text('Controles', style: TextStyle(fontSize: 12)),
                          icon: Icon(Icons.touch_app, size: 16),
                        ),
                      ],
                      selected: {_panelMode},
                      onSelectionChanged: (s) =>
                          setState(() => _panelMode = s.first),
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  )
                : Text(_titles[_currentIndex]),
            actions: [
              if (connProvider.serviceRunning)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.sync, color: Colors.greenAccent, size: 16),
                ),
              GestureDetector(
                onTap: () => setState(() => _currentIndex = 1),
                child: Container(
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
              ),
            ],
          ),
          body: body,
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
                label: 'Conex.',
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
