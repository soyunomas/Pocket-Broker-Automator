import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dashboard_button.dart';
import '../providers/dashboard_provider.dart';
import '../providers/connection_provider.dart';
import '../services/mqtt_client_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<DashboardProvider, ConnectionProvider>(
      builder: (context, dashProvider, connProvider, _) {
        final isConnected =
            connProvider.connectionState == ClientConnectionState.connected;

        if (dashProvider.buttons.isEmpty) {
          return Scaffold(
            body: const Center(
              child: Text(
                'No hay botones configurados',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showEditDialog(context, dashProvider),
              child: const Icon(Icons.add),
            ),
          );
        }

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: dashProvider.buttons.length,
              itemBuilder: (context, index) {
                final btn = dashProvider.buttons[index];
                final color = _parseColor(btn.color);
                return GestureDetector(
                  onLongPress: () => _showEditDialog(context, dashProvider, button: btn),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? color : color.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: isConnected ? () => dashProvider.pressButton(btn) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (btn.icon != null)
                            Icon(_getIcon(btn.icon!), size: 24),
                          if (btn.icon != null) const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              btn.label,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            btn.topic,
                            style: const TextStyle(fontSize: 9, color: Colors.white70),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showEditDialog(context, dashProvider),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blue;
    }
  }

  IconData _getIcon(String name) {
    const icons = {
      'power': Icons.power_settings_new,
      'light': Icons.lightbulb,
      'lock': Icons.lock,
      'door': Icons.door_front_door,
      'fan': Icons.air,
      'temp': Icons.thermostat,
      'camera': Icons.videocam,
      'alarm': Icons.alarm,
      'toggle': Icons.toggle_on,
      'send': Icons.send,
    };
    return icons[name] ?? Icons.touch_app;
  }

  void _showEditDialog(BuildContext context, DashboardProvider provider,
      {DashboardButton? button}) {
    final isEditing = button != null;
    final labelCtrl = TextEditingController(text: button?.label ?? '');
    final topicCtrl = TextEditingController(text: button?.topic ?? '');
    final payloadCtrl = TextEditingController(text: button?.payload ?? '');
    final colorCtrl = TextEditingController(text: button?.color ?? '#2196F3');
    int qos = button?.qos ?? 0;
    bool retain = button?.retain ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEditing ? 'Editar Botón' : 'Nuevo Botón'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label'),
                ),
                TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(labelText: 'Topic'),
                ),
                TextField(
                  controller: payloadCtrl,
                  decoration: const InputDecoration(labelText: 'Payload'),
                ),
                GestureDetector(
                  onTap: () async {
                    final picked = await _showColorPicker(ctx, colorCtrl.text);
                    if (picked != null) {
                      setState(() => colorCtrl.text = picked);
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: colorCtrl,
                      decoration: InputDecoration(
                        labelText: 'Color (#HEX)',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(10),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _parseColor(colorCtrl.text),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                DropdownButtonFormField<int>(
                  value: qos,
                  decoration: const InputDecoration(labelText: 'QoS'),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('QoS 0')),
                    DropdownMenuItem(value: 1, child: Text('QoS 1')),
                    DropdownMenuItem(value: 2, child: Text('QoS 2')),
                  ],
                  onChanged: (v) => setState(() => qos = v ?? 0),
                ),
                SwitchListTile(
                  title: const Text('Retain'),
                  value: retain,
                  onChanged: (v) => setState(() => retain = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  provider.deleteButton(button);
                  Navigator.pop(ctx);
                },
                child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (labelCtrl.text.isEmpty || topicCtrl.text.isEmpty) return;
                if (isEditing) {
                  button.label = labelCtrl.text;
                  button.topic = topicCtrl.text;
                  button.payload = payloadCtrl.text;
                  button.color = colorCtrl.text;
                  button.qos = qos;
                  button.retain = retain;
                  provider.updateButton(button);
                } else {
                  provider.addButton(DashboardButton(
                    label: labelCtrl.text,
                    topic: topicCtrl.text,
                    payload: payloadCtrl.text,
                    color: colorCtrl.text,
                    qos: qos,
                    retain: retain,
                  ));
                }
                Navigator.pop(ctx);
              },
              child: Text(isEditing ? 'Guardar' : 'Crear'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showColorPicker(BuildContext context, String currentHex) {
    const presetColors = [
      '#F44336', '#E91E63', '#9C27B0', '#673AB7',
      '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
      '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
      '#FFEB3B', '#FFC107', '#FF9800', '#FF5722',
      '#795548', '#9E9E9E', '#607D8B', '#000000',
    ];
    final hexCtrl = TextEditingController(text: currentHex);

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Elegir color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: presetColors.length,
                itemBuilder: (_, i) {
                  final c = presetColors[i];
                  final selected = c.toUpperCase() == hexCtrl.text.toUpperCase();
                  return GestureDetector(
                    onTap: () => setState(() => hexCtrl.text = c),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _parseColor(c),
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : Border.all(color: Colors.white24),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: hexCtrl,
                decoration: InputDecoration(
                  labelText: 'HEX',
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _parseColor(hexCtrl.text),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white38),
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, hexCtrl.text),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );
  }
}
