import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/automation_rule.dart';
import '../providers/automation_provider.dart';

class AutomationsScreen extends StatelessWidget {
  const AutomationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AutomationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: provider.rules.isEmpty
              ? const Center(
                  child: Text(
                    'No hay reglas de automatización',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.rules.length,
                  itemBuilder: (context, index) {
                    final rule = provider.rules[index];
                    return Card(
                      color: Colors.grey[900],
                      child: ListTile(
                        leading: Icon(
                          Icons.auto_awesome,
                          color: rule.enabled ? Colors.amberAccent : Colors.grey,
                        ),
                        title: Text(
                          rule.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${rule.topic} • ${rule.condition.type}: ${rule.condition.value}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: rule.enabled,
                              onChanged: (_) => provider.toggleRule(rule),
                              activeColor: Colors.greenAccent,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(context, provider, rule),
                            ),
                          ],
                        ),
                        onTap: () => _showEditDialog(context, provider, rule: rule),
                        onLongPress: () => _showEditDialog(context, provider, rule: rule),
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showEditDialog(context, provider),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, AutomationProvider provider, AutomationRule rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar regla'),
        content: Text('¿Eliminar "${rule.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              provider.deleteRule(rule);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, AutomationProvider provider,
      {AutomationRule? rule}) {
    final isEditing = rule != null;
    final nameCtrl = TextEditingController(text: rule?.name ?? '');
    final topicCtrl = TextEditingController(text: rule?.topic ?? '');
    final valueCtrl = TextEditingController(text: rule?.condition.value ?? '');
    String conditionType = rule?.condition.type ?? 'equals';

    // Actions state
    final actions = List<RuleAction>.from(rule?.actions ?? []);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEditing ? 'Editar Regla' : 'Nueva Regla'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: topicCtrl,
                  decoration: const InputDecoration(labelText: 'Topic'),
                ),
                DropdownButtonFormField<String>(
                  value: conditionType,
                  decoration: const InputDecoration(labelText: 'Condición'),
                  items: const [
                    DropdownMenuItem(value: 'equals', child: Text('Igual a')),
                    DropdownMenuItem(value: 'contains', child: Text('Contiene')),
                    DropdownMenuItem(value: 'regex', child: Text('Regex')),
                    DropdownMenuItem(value: 'any', child: Text('Cualquier mensaje')),
                  ],
                  onChanged: (v) => setState(() => conditionType = v ?? 'equals'),
                ),
                if (conditionType != 'any')
                  TextField(
                    controller: valueCtrl,
                    decoration: const InputDecoration(labelText: 'Valor'),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: () => _showAddActionDialog(ctx, actions, setState),
                    ),
                  ],
                ),
                ...actions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final a = entry.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_actionIcon(a.type), size: 18),
                    title: Text('${a.type}: ${a.params.values.first}',
                        style: const TextStyle(fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          size: 18, color: Colors.redAccent),
                      onPressed: () => setState(() => actions.removeAt(i)),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final topic = topicCtrl.text.trim();
                final condValue = valueCtrl.text.trim();
                if (name.isEmpty || topic.isEmpty) return;
                final condition = RuleCondition(
                  type: conditionType,
                  value: conditionType == 'any' ? '' : condValue,
                );
                if (isEditing) {
                  rule.name = name;
                  rule.topic = topic;
                  rule.condition = condition;
                  rule.actions = actions;
                  provider.updateRule(rule);
                } else {
                  provider.addRule(AutomationRule(
                    name: name,
                    topic: topic,
                    condition: condition,
                    actions: actions,
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

  void _showAddActionDialog(
      BuildContext context, List<RuleAction> actions, void Function(void Function()) setState) {
    String type = 'publish';
    final param1Ctrl = TextEditingController();
    final param2Ctrl = TextEditingController();
    String webhookMethod = 'GET';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Agregar Acción'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'publish', child: Text('Publicar MQTT')),
                  DropdownMenuItem(value: 'webhook', child: Text('Webhook')),
                  DropdownMenuItem(value: 'sound', child: Text('Sonido')),
                  DropdownMenuItem(value: 'intent', child: Text('Abrir URL/App')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? 'publish'),
              ),
              if (type == 'webhook')
                DropdownButtonFormField<String>(
                  value: webhookMethod,
                  decoration: const InputDecoration(labelText: 'Método HTTP'),
                  items: const [
                    DropdownMenuItem(value: 'GET', child: Text('GET')),
                    DropdownMenuItem(value: 'POST', child: Text('POST')),
                  ],
                  onChanged: (v) => setDialogState(() => webhookMethod = v ?? 'GET'),
                ),
              if (type == 'sound')
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        param1Ctrl.text.isEmpty
                            ? 'Ningún archivo seleccionado'
                            : param1Ctrl.text.split('/').last,
                        style: TextStyle(
                          color: param1Ctrl.text.isEmpty
                              ? Colors.white38
                              : Colors.white,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.audio_file, size: 18),
                      label: const Text('Elegir'),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.audio,
                        );
                        if (result != null && result.files.single.path != null) {
                          setDialogState(() {
                            param1Ctrl.text = result.files.single.path!;
                          });
                        }
                      },
                    ),
                  ],
                )
              else
                TextField(
                  controller: param1Ctrl,
                  decoration: InputDecoration(
                    labelText: type == 'publish'
                        ? 'Topic'
                        : type == 'webhook'
                            ? 'URL'
                            : 'URL',
                  ),
                ),
              if (type == 'publish' || type == 'webhook')
                TextField(
                  controller: param2Ctrl,
                  decoration: InputDecoration(
                    labelText: type == 'publish' ? 'Payload' : 'Body JSON',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final p1 = param1Ctrl.text.trim();
                final p2 = param2Ctrl.text.trim();
                Map<String, String> params;
                switch (type) {
                  case 'publish':
                    params = {'topic': p1, 'payload': p2};
                    break;
                  case 'webhook':
                    params = {
                      'url': p1,
                      'method': webhookMethod,
                      'body': p2,
                    };
                    break;
                  case 'sound':
                    params = {'file': p1};
                    break;
                  case 'intent':
                    params = {'url': p1};
                    break;
                  default:
                    params = {};
                }
                setState(() {
                  actions.add(RuleAction(type: type, params: params));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _actionIcon(String type) {
    switch (type) {
      case 'publish':
        return Icons.send;
      case 'webhook':
        return Icons.webhook;
      case 'sound':
        return Icons.volume_up;
      case 'intent':
        return Icons.open_in_new;
      default:
        return Icons.play_arrow;
    }
  }
}
