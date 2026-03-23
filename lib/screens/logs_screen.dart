import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/log_provider.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LogProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _filterChips(provider)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                    onPressed: () => provider.clearLogs(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.entries.isEmpty
                  ? const Center(
                      child: Text('Sin logs', style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: provider.entries.length,
                      itemBuilder: (context, index) {
                        final entry = provider.entries[index];
                        final time = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
                        final timeStr =
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
                        return Card(
                          color: Colors.grey[900],
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              _iconForType(entry.type),
                              color: _colorForType(entry.type),
                              size: 20,
                            ),
                            title: Text(
                              entry.message,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: Text(
                              timeStr,
                              style: const TextStyle(fontSize: 11, color: Colors.white38),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _filterChips(LogProvider provider) {
    const filters = ['all', 'sent', 'received', 'error', 'action', 'system'];
    return filters.map((f) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: FilterChip(
          label: Text(f, style: const TextStyle(fontSize: 11)),
          selected: provider.filterType == f,
          onSelected: (_) => provider.setFilter(f),
          selectedColor: Colors.tealAccent.withOpacity(0.3),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      );
    }).toList();
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'sent':
        return Icons.arrow_upward;
      case 'received':
        return Icons.arrow_downward;
      case 'error':
        return Icons.error_outline;
      case 'action':
        return Icons.play_circle_outline;
      case 'system':
        return Icons.info_outline;
      default:
        return Icons.circle;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'sent':
        return Colors.lightBlueAccent;
      case 'received':
        return Colors.greenAccent;
      case 'error':
        return Colors.redAccent;
      case 'action':
        return Colors.orangeAccent;
      case 'system':
        return Colors.white54;
      default:
        return Colors.grey;
    }
  }
}
