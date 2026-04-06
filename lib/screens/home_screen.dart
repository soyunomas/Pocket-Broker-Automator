import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/connection_provider.dart';
import '../providers/automation_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/monitor_provider.dart';
import '../services/mqtt_client_service.dart';
import '../services/background_service.dart';
import '../utils/config_exporter.dart';
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

  Future<void> _exportConfig() async {
    final selection = await _showSectionPicker('Exportar configuración');
    if (selection == null || !mounted) return;

    final connProv = context.read<ConnectionProvider>();
    final autoProv = context.read<AutomationProvider>();
    final dashProv = context.read<DashboardProvider>();
    final monProv = context.read<MonitorProvider>();

    try {
      final ok = await ConfigExporter.exportToFile(
        connections: selection.contains('connections') ? connProv.profiles : null,
        rules: selection.contains('rules') ? autoProv.rules : null,
        buttons: selection.contains('buttons') ? dashProv.buttons : null,
        monitors: selection.contains('monitors') ? monProv.widgets : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Configuración exportada' : 'Exportación cancelada'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al exportar: $e'),
      ));
    }
  }

  Future<void> _importConfig() async {
    try {
      final data = await ConfigExporter.importFromFile();
      if (data == null || !mounted) return;

      final connections = ConfigExporter.parseConnections(data);
      final rules = ConfigExporter.parseRules(data);
      final buttons = ConfigExporter.parseButtons(data);
      final monitors = ConfigExporter.parseMonitors(data);

      final parts = <String>[];
      if (connections.isNotEmpty) parts.add('${connections.length} conexiones');
      if (rules.isNotEmpty) parts.add('${rules.length} reglas');
      if (buttons.isNotEmpty) parts.add('${buttons.length} controles');
      if (monitors.isNotEmpty) parts.add('${monitors.length} monitores');
      if (parts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El archivo no contiene datos'),
          duration: Duration(seconds: 2),
        ));
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Importar configuración'),
          content: Text('Se añadirán:\n${parts.join(', ')}\n\n¿Continuar?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importar')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final connProv = context.read<ConnectionProvider>();
      final autoProv = context.read<AutomationProvider>();
      final dashProv = context.read<DashboardProvider>();
      final monProv = context.read<MonitorProvider>();
      if (connections.isNotEmpty) await connProv.importProfiles(connections);
      if (rules.isNotEmpty) await autoProv.importRules(rules);
      if (buttons.isNotEmpty) await dashProv.importButtons(buttons);
      if (monitors.isNotEmpty) await monProv.importWidgets(monitors);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Importado: ${parts.join(', ')}'),
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al importar: $e'),
      ));
    }
  }

  Future<Set<String>?> _showSectionPicker(String title) {
    final selected = <String>{'connections', 'rules', 'buttons', 'monitors'};
    return showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('Conexiones'),
                value: selected.contains('connections'),
                onChanged: (v) => setState(() => v! ? selected.add('connections') : selected.remove('connections')),
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Reglas'),
                value: selected.contains('rules'),
                onChanged: (v) => setState(() => v! ? selected.add('rules') : selected.remove('rules')),
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Controles'),
                value: selected.contains('buttons'),
                onChanged: (v) => setState(() => v! ? selected.add('buttons') : selected.remove('buttons')),
                dense: true,
              ),
              CheckboxListTile(
                title: const Text('Monitores'),
                value: selected.contains('monitors'),
                onChanged: (v) => setState(() => v! ? selected.add('monitors') : selected.remove('monitors')),
                dense: true,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.pop(ctx, Set<String>.from(selected)),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  bool _loadingTrace = false;

  void _showDebugTrace() async {
    if (_loadingTrace) return;
    _loadingTrace = true;

    final running = await BackgroundServiceController.isRunning();
    if (!running) {
      _loadingTrace = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('El servicio no está activo'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    final chunks = <int, String>{};
    int totalChunks = 1;
    int totalLines = 0;
    final completer = Completer<String>();

    final sub = BackgroundServiceController.on('debugTrace').listen((event) {
      if (event == null) return;
      final index = event['index'] as int? ?? 0;
      final total = event['total'] as int? ?? 1;
      totalChunks = total;
      totalLines = event['totalLines'] as int? ?? 0;
      chunks[index] = event['chunk'] as String? ?? '';
      if (chunks.length >= totalChunks && !completer.isCompleted) {
        final sorted = List.generate(totalChunks, (i) => chunks[i] ?? '');
        completer.complete(sorted.join('\n'));
      }
    });

    BackgroundServiceController.requestDebugTrace();

    final trace = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => '(timeout esperando traza del servicio)',
    );
    sub.cancel();
    _loadingTrace = false;

    if (!mounted) return;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _DebugTraceScreen(trace: trace, totalLines: totalLines),
    ));
  }

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
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
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
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          connProvider.activeAlias.isNotEmpty
                              ? connProvider.activeAlias
                              : 'Sin conex.',
                          style: TextStyle(fontSize: 11, color: statusColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  if (value == 'export') _exportConfig();
                  if (value == 'import') _importConfig();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'export', child: Text('Exportar configuración')),
                  PopupMenuItem(value: 'import', child: Text('Importar configuración')),
                ],
              ),
            ],
          ),
          body: body,
          floatingActionButton: SizedBox(
            width: 24,
            height: 24,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              hoverElevation: 0,
              focusElevation: 0,
              highlightElevation: 0,
              onPressed: _showDebugTrace,
              child: const Icon(Icons.bug_report, size: 12, color: Colors.white24),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
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

class _DebugTraceScreen extends StatelessWidget {
  final String trace;
  final int totalLines;

  const _DebugTraceScreen({required this.trace, required this.totalLines});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Trace ($totalLines líneas)', style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar todo',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: trace));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Traza copiada al portapapeles'), duration: Duration(seconds: 2)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Borrar traza',
            onPressed: () {
              BackgroundServiceController.clearDebugTrace();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Traza borrada'), duration: Duration(seconds: 2)),
              );
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: SelectableText(
          trace.isEmpty ? '(sin datos de traza)' : trace,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            color: Colors.greenAccent,
          ),
        ),
      ),
    );
  }
}
