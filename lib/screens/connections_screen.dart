import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/connection_profile.dart';
import '../providers/connection_provider.dart';
import '../services/mqtt_client_service.dart';

class ConnectionsScreen extends StatelessWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: provider.profiles.isEmpty
              ? const Center(
                  child: Text(
                    'No hay conexiones configuradas',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: provider.profiles.length,
                  itemBuilder: (context, index) {
                    final profile = provider.profiles[index];
                    final isActive = provider.activeProfileId == profile.id;
                    final isConnected =
                        isActive && provider.connectionState == ClientConnectionState.connected;
                    final isConnecting =
                        isActive && provider.connectionState == ClientConnectionState.connecting;

                    return Card(
                      color: isConnected
                          ? Colors.green.withOpacity(0.15)
                          : Colors.grey[900],
                      child: ListTile(
                        leading: Icon(
                          Icons.dns,
                          color: isConnected
                              ? Colors.greenAccent
                              : isConnecting
                                  ? Colors.orangeAccent
                                  : Colors.grey,
                        ),
                        title: Text(
                          profile.alias,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${profile.host}:${profile.port}',
                          style: const TextStyle(color: Colors.white54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isConnecting)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            if (isConnected)
                              IconButton(
                                icon: const Icon(Icons.link_off, color: Colors.redAccent),
                                onPressed: () => provider.disconnect(),
                              )
                            else if (!isConnecting)
                              IconButton(
                                icon: const Icon(Icons.link, color: Colors.greenAccent),
                                onPressed: () => provider.connect(profile),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(context, provider, profile),
                            ),
                          ],
                        ),
                        onTap: () => _showEditDialog(context, provider, profile: profile),
                        onLongPress: () => _showEditDialog(context, provider, profile: profile),
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
      BuildContext context, ConnectionProvider provider, ConnectionProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar conexión'),
        content: Text('¿Eliminar "${profile.alias}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              provider.deleteProfile(profile);
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, ConnectionProvider provider,
      {ConnectionProfile? profile}) {
    final isEditing = profile != null;
    final aliasCtrl = TextEditingController(text: profile?.alias ?? '');
    final hostCtrl = TextEditingController(text: profile?.host ?? '');
    final portCtrl = TextEditingController(text: (profile?.port ?? 1883).toString());
    final userCtrl = TextEditingController(text: profile?.username ?? '');
    final passCtrl = TextEditingController(text: profile?.password ?? '');
    final clientIdCtrl = TextEditingController(text: profile?.clientId ?? '');
    bool ssl = profile?.ssl ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEditing ? 'Editar Conexión' : 'Nueva Conexión'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: aliasCtrl,
                  decoration: const InputDecoration(labelText: 'Alias'),
                ),
                TextField(
                  controller: hostCtrl,
                  decoration: const InputDecoration(labelText: 'Host'),
                ),
                TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(labelText: 'Puerto'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: clientIdCtrl,
                  decoration: const InputDecoration(labelText: 'Client ID (opcional)'),
                ),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario (opcional)'),
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Contraseña (opcional)'),
                  obscureText: true,
                ),
                SwitchListTile(
                  title: const Text('SSL/TLS'),
                  value: ssl,
                  onChanged: (v) => setState(() => ssl = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (aliasCtrl.text.isEmpty || hostCtrl.text.isEmpty) return;
                if (isEditing) {
                  profile.alias = aliasCtrl.text;
                  profile.host = hostCtrl.text;
                  profile.port = int.tryParse(portCtrl.text) ?? 1883;
                  profile.username = userCtrl.text;
                  profile.password = passCtrl.text;
                  profile.clientId = clientIdCtrl.text.isEmpty
                      ? profile.clientId
                      : clientIdCtrl.text;
                  profile.ssl = ssl;
                  provider.updateProfile(profile);
                } else {
                  provider.addProfile(ConnectionProfile(
                    alias: aliasCtrl.text,
                    host: hostCtrl.text,
                    port: int.tryParse(portCtrl.text) ?? 1883,
                    username: userCtrl.text,
                    password: passCtrl.text,
                    clientId: clientIdCtrl.text.isEmpty ? null : clientIdCtrl.text,
                    ssl: ssl,
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
}
