import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/broker_provider.dart';

class BrokerScreen extends StatelessWidget {
  const BrokerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BrokerProvider>(
      builder: (context, broker, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      broker.isRunning ? Icons.dns : Icons.dns_outlined,
                      size: 48,
                      color: broker.isRunning
                          ? Colors.greenAccent
                          : Colors.white24,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      broker.isRunning ? 'Broker Activo' : 'Broker Detenido',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (broker.isRunning) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'MQTT :${broker.config.port}'
                          '${broker.config.wsEnabled ? '  •  WS :${broker.config.wsPort}' : ''}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13),
                        ),
                      ),
                      if (broker.ips.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            children: broker.ips.expand((ip) {
                              final rows = <Widget>[
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.wifi,
                                        size: 14,
                                        color: Colors.greenAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'mqtt://$ip:${broker.config.port}',
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ];
                              if (broker.config.wsEnabled) {
                                rows.add(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.language,
                                        size: 14,
                                        color: Colors.cyanAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'ws://$ip:${broker.config.wsPort}/mqtt',
                                      style: const TextStyle(
                                        color: Colors.cyanAccent,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ));
                              }
                              return rows;
                            }).toList(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: broker.isLoading
                            ? null
                            : () => broker.isRunning
                                ? broker.stopBroker()
                                : broker.startBroker(),
                        icon: broker.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Icon(broker.isRunning
                                ? Icons.stop
                                : Icons.play_arrow),
                        label: Text(broker.isLoading
                            ? 'Procesando…'
                            : broker.isRunning
                                ? 'Detener Broker'
                                : 'Iniciar Broker'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Config card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuración',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _PortField(
                      label: 'Puerto MQTT',
                      initialValue: broker.config.port,
                      enabled: !broker.isRunning,
                      onChanged: (port) => broker.updateConfig(port: port),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('WebSocket'),
                      subtitle: const Text('Escuchar conexiones MQTT sobre WS'),
                      value: broker.config.wsEnabled,
                      contentPadding: EdgeInsets.zero,
                      onChanged: broker.isRunning
                          ? null
                          : (v) => broker.updateConfig(wsEnabled: v),
                    ),
                    if (broker.config.wsEnabled) ...[
                      const SizedBox(height: 8),
                      _PortField(
                        label: 'Puerto WebSocket',
                        initialValue: broker.config.wsPort,
                        enabled: !broker.isRunning,
                        onChanged: (port) => broker.updateConfig(wsPort: port),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Autenticación'),
                      subtitle: const Text('Requerir usuario y contraseña'),
                      value: broker.config.authEnabled,
                      contentPadding: EdgeInsets.zero,
                      onChanged: broker.isRunning
                          ? null
                          : (v) => broker.updateConfig(authEnabled: v),
                    ),
                    if (broker.config.authEnabled) ...[
                      const SizedBox(height: 8),
                      _AuthFields(
                        username: broker.config.username,
                        password: broker.config.password,
                        enabled: !broker.isRunning,
                        onUsernameChanged: (u) =>
                            broker.updateConfig(username: u),
                        onPasswordChanged: (p) =>
                            broker.updateConfig(password: p),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'El broker local permite que dispositivos IoT se conecten '
                      'directamente a este teléfono sin necesidad de un servidor '
                      'externo.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Los clientes MQTT pueden conectarse a la IP de este '
                      'dispositivo en la red local.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PortField extends StatefulWidget {
  final String label;
  final int initialValue;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _PortField({
    this.label = 'Puerto',
    required this.initialValue,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_PortField> createState() => _PortFieldState();
}

class _PortFieldState extends State<_PortField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.settings_ethernet),
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final port = int.tryParse(v);
        if (port != null && port > 0 && port <= 65535) {
          widget.onChanged(port);
        }
      },
    );
  }
}

class _AuthFields extends StatefulWidget {
  final String username;
  final String password;
  final bool enabled;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;

  const _AuthFields({
    required this.username,
    required this.password,
    required this.enabled,
    required this.onUsernameChanged,
    required this.onPasswordChanged,
  });

  @override
  State<_AuthFields> createState() => _AuthFieldsState();
}

class _AuthFieldsState extends State<_AuthFields> {
  late TextEditingController _userController;
  late TextEditingController _passController;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _userController = TextEditingController(text: widget.username);
    _passController = TextEditingController(text: widget.password);
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _userController,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'Usuario',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
          onChanged: widget.onUsernameChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passController,
          enabled: widget.enabled,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Contraseña',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onChanged: widget.onPasswordChanged,
        ),
      ],
    );
  }
}
