import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/monitor_widget.dart';
import '../providers/monitor_provider.dart';
import '../utils/chart_painters.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MonitorProvider>(
      builder: (context, provider, _) {
        if (provider.widgets.isEmpty) {
          return Scaffold(
            body: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      size: 48, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('No hay monitores configurados',
                      style: TextStyle(color: Colors.white54)),
                  SizedBox(height: 4),
                  Text('Añade un widget para visualizar datos MQTT',
                      style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddWidgetDialog(context, provider),
              child: const Icon(Icons.add),
            ),
          );
        }

        return Scaffold(
          body: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: provider.widgets.length,
            itemBuilder: (context, index) {
              final widget = provider.widgets[index];
              return _buildWidgetCard(context, provider, widget);
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddWidgetDialog(context, provider),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildWidgetCard(
      BuildContext context, MonitorProvider provider, MonitorWidget mw) {
    final color = _parseColor(mw.color);
    final latestValue = provider.latestValues[mw.topic];
    final latestTime = provider.latestTimestamps[mw.topic];
    final timeStr = latestTime != null
        ? '${latestTime.hour.toString().padLeft(2, '0')}:${latestTime.minute.toString().padLeft(2, '0')}:${latestTime.second.toString().padLeft(2, '0')}'
        : '--:--:--';

    return GestureDetector(
      onLongPress: () => _showAddWidgetDialog(context, provider, widget: mw),
      onTap: () => _showDetailSheet(context, provider, mw),
      child: Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  if (mw.icon != null)
                    Icon(_getIcon(mw.icon!), color: color, size: 20),
                  if (mw.icon != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(mw.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Text(timeStr,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              // Widget body based on type
              _buildWidgetBody(provider, mw, color, latestValue),
              // Topic subtitle
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(mw.topic,
                    style:
                        const TextStyle(color: Colors.white24, fontSize: 10)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetBody(MonitorProvider provider, MonitorWidget mw,
      Color color, String? latestValue) {
    switch (mw.type) {
      case 'gauge':
        return _buildGaugeBody(provider, mw, color, latestValue);
      case 'chart':
        return _buildChartBody(provider, mw, color);
      case 'bars':
        return _buildBarsBody(provider, mw, color);
      case 'counter':
        return _buildCounterBody(provider, mw, color);
      case 'log':
        return _buildLogBody(provider, mw, color);
      default:
        return _buildGaugeBody(provider, mw, color, latestValue);
    }
  }

  Widget _buildGaugeBody(MonitorProvider provider, MonitorWidget mw,
      Color color, String? latestValue) {
    final numValue = double.tryParse(latestValue ?? '');
    final displayValue = numValue?.toStringAsFixed(1) ?? latestValue ?? '—';
    final minV = mw.minValue ?? 0;
    final maxV = mw.maxValue ?? 100;
    final progress = numValue != null && maxV > minV
        ? ((numValue - minV) / (maxV - minV)).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(displayValue,
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: color)),
            if (mw.unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(mw.unit,
                    style: TextStyle(fontSize: 16, color: color.withOpacity(0.7))),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${minV.toStringAsFixed(0)}${mw.unit}',
                style: const TextStyle(color: Colors.white30, fontSize: 10)),
            Text('${maxV.toStringAsFixed(0)}${mw.unit}',
                style: const TextStyle(color: Colors.white30, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildChartBody(
      MonitorProvider provider, MonitorWidget mw, Color color) {
    final values =
        provider.getNumericValues(mw.topic, window: const Duration(hours: 1));
    final timeLabels =
        provider.getTimeLabels(mw.topic, window: const Duration(hours: 1));

    if (values.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('Esperando datos…',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ),
      );
    }

    final minV = mw.minValue ?? values.reduce((a, b) => a < b ? a : b);
    final maxV = mw.maxValue ?? values.reduce((a, b) => a > b ? a : b);
    final adjustedMin = minV == maxV ? minV - 1 : minV;
    final adjustedMax = minV == maxV ? maxV + 1 : maxV;

    return SizedBox(
      height: 120,
      child: CustomPaint(
        size: Size.infinite,
        painter: LineChartPainter(
          values: values,
          minValue: adjustedMin,
          maxValue: adjustedMax,
          lineColor: color,
          timeLabels: timeLabels,
        ),
      ),
    );
  }

  Widget _buildBarsBody(
      MonitorProvider provider, MonitorWidget mw, Color color) {
    final hourlyCounts = provider.getHourlyCounts(mw.topic);

    if (hourlyCounts.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text('Esperando datos…',
              style: TextStyle(color: Colors.white30, fontSize: 12)),
        ),
      );
    }

    // Show last 12 hours
    final now = DateTime.now().hour;
    final hours = List.generate(12, (i) => (now - 11 + i) % 24);
    final values = hours.map((h) => (hourlyCounts[h] ?? 0).toDouble()).toList();
    final labels = hours.map((h) => '${h.toString().padLeft(2, '0')}h').toList();
    final maxVal =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 100,
      child: CustomPaint(
        size: Size.infinite,
        painter: BarChartPainter(
          values: values,
          labels: labels,
          maxValue: maxVal == 0 ? 1 : maxVal,
          barColor: color,
        ),
      ),
    );
  }

  Widget _buildCounterBody(
      MonitorProvider provider, MonitorWidget mw, Color color) {
    final totalCount = provider.countEvents(mw.topic);
    final todayCount = provider.countEvents(mw.topic,
        window: Duration(
            hours: DateTime.now().hour,
            minutes: DateTime.now().minute));
    final lastHourCount =
        provider.countEvents(mw.topic, window: const Duration(hours: 1));
    final latestValue = provider.latestValues[mw.topic];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(totalCount.toString(),
                  style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const Text('total',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _counterStat('Hoy', todayCount.toString(), color),
              const SizedBox(height: 4),
              _counterStat('Última hora', lastHourCount.toString(), color),
              if (latestValue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _counterStat('Último', latestValue, color),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _counterStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLogBody(
      MonitorProvider provider, MonitorWidget mw, Color color) {
    final readings =
        provider.getReadings(mw.topic, window: const Duration(hours: 24));
    final recent = readings.reversed.take(5).toList();

    if (recent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Sin datos recibidos',
            style: TextStyle(color: Colors.white30, fontSize: 12)),
      );
    }

    return Column(
      children: recent.map((r) {
        final t = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        final ts =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: [
              Text(ts,
                  style:
                      const TextStyle(color: Colors.white30, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.value,
                    style: TextStyle(color: color, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showDetailSheet(
      BuildContext context, MonitorProvider provider, MonitorWidget mw) {
    final color = _parseColor(mw.color);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollController) {
          final readings = provider.getReadings(mw.topic);
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Row(
                children: [
                  if (mw.icon != null)
                    Icon(_getIcon(mw.icon!), color: color, size: 24),
                  if (mw.icon != null) const SizedBox(width: 8),
                  Expanded(
                    child: Text(mw.label,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep,
                        color: Colors.redAccent, size: 20),
                    onPressed: () {
                      provider.clearReadings(mw.topic);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Text(mw.topic,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              // Stats row
              _buildStatsRow(provider, mw, color),
              const SizedBox(height: 16),
              // Chart if numeric data
              if (mw.type != 'log') ...[
                const Text('Tendencia (1h)',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: _buildChartBody(provider, mw, color),
                ),
                const SizedBox(height: 16),
              ],
              // History
              Row(
                children: [
                  const Expanded(
                    child: Text('Historial',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  Text('${readings.length} registros',
                      style: const TextStyle(
                          color: Colors.white30, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              ...readings.reversed.take(50).map((r) {
                final t =
                    DateTime.fromMillisecondsSinceEpoch(r.timestamp);
                final dateStr =
                    '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
                final timeStr =
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
                final displayValue = '${r.value}${mw.unit.isNotEmpty ? ' ${mw.unit}' : ''}';
                return GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.value));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Copiado: ${r.value}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(dateStr,
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 10)),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(timeStr,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(displayValue,
                              style: TextStyle(color: color, fontSize: 12)),
                        ),
                        const Icon(Icons.copy, size: 12, color: Colors.white12),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(
      MonitorProvider provider, MonitorWidget mw, Color color) {
    final values = provider.getNumericValues(mw.topic);
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;

    return Row(
      children: [
        _statChip('Mín', '${min.toStringAsFixed(1)}${mw.unit}', Colors.blue),
        const SizedBox(width: 8),
        _statChip('Media', '${avg.toStringAsFixed(1)}${mw.unit}', color),
        const SizedBox(width: 8),
        _statChip('Máx', '${max.toStringAsFixed(1)}${mw.unit}', Colors.orange),
        const SizedBox(width: 8),
        _statChip('Total', '${values.length}', Colors.white38),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(color: Colors.white38, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  // --- Add/Edit Widget Dialog ---

  void _showAddWidgetDialog(BuildContext context, MonitorProvider provider,
      {MonitorWidget? widget}) {
    final isEditing = widget != null;
    final labelCtrl = TextEditingController(text: widget?.label ?? '');
    final topicCtrl = TextEditingController(text: widget?.topic ?? '');
    final unitCtrl = TextEditingController(text: widget?.unit ?? '');
    final minCtrl =
        TextEditingController(text: widget?.minValue?.toString() ?? '');
    final maxCtrl =
        TextEditingController(text: widget?.maxValue?.toString() ?? '');
    final colorCtrl =
        TextEditingController(text: widget?.color ?? '#00BCD4');
    String type = widget?.type ?? 'gauge';
    String? icon = widget?.icon;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(isEditing ? 'Editar Monitor' : 'Nuevo Monitor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                TextField(
                  controller: topicCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Topic MQTT'),
                ),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Tipo de widget'),
                  items: const [
                    DropdownMenuItem(value: 'gauge', child: Text('Valor / Gauge')),
                    DropdownMenuItem(value: 'chart', child: Text('Gráfica líneas')),
                    DropdownMenuItem(value: 'bars', child: Text('Barras por hora')),
                    DropdownMenuItem(value: 'counter', child: Text('Contador')),
                    DropdownMenuItem(value: 'log', child: Text('Historial texto')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'gauge'),
                ),
                TextField(
                  controller: unitCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Unidad (°C, %, lux…)'),
                ),
                DropdownButtonFormField<String?>(
                  value: icon,
                  decoration: const InputDecoration(labelText: 'Icono'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Ninguno')),
                    DropdownMenuItem(value: 'temp', child: Text('🌡️ Temperatura')),
                    DropdownMenuItem(value: 'light', child: Text('💡 Luz')),
                    DropdownMenuItem(value: 'fan', child: Text('🌀 Ventilador')),
                    DropdownMenuItem(value: 'door', child: Text('🚪 Puerta')),
                    DropdownMenuItem(value: 'alarm', child: Text('🔔 Alarma/PIR')),
                    DropdownMenuItem(value: 'camera', child: Text('📹 Cámara')),
                    DropdownMenuItem(value: 'power', child: Text('⚡ Energía')),
                    DropdownMenuItem(value: 'send', child: Text('📡 Sensor')),
                  ],
                  onChanged: (v) => setState(() => icon = v),
                ),
                if (type == 'gauge' || type == 'chart') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minCtrl,
                          decoration: const InputDecoration(labelText: 'Mín'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxCtrl,
                          decoration: const InputDecoration(labelText: 'Máx'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                TextField(
                  controller: colorCtrl,
                  readOnly: true,
                  onTap: () async {
                    final picked = await _showColorPicker(ctx, colorCtrl.text);
                    if (picked != null) {
                      colorCtrl.text = picked;
                      setState(() {});
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Color',
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
              ],
            ),
          ),
          actions: [
            if (isEditing)
              TextButton(
                onPressed: () {
                  provider.deleteWidget(widget);
                  Navigator.pop(ctx);
                },
                child: const Text('Eliminar',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final label = labelCtrl.text.trim();
                final topic = topicCtrl.text.trim();
                final unit = unitCtrl.text.trim();
                if (label.isEmpty || topic.isEmpty) return;
                if (isEditing) {
                  widget.label = label;
                  widget.topic = topic;
                  widget.type = type;
                  widget.unit = unit;
                  widget.icon = icon;
                  widget.minValue = double.tryParse(minCtrl.text);
                  widget.maxValue = double.tryParse(maxCtrl.text);
                  widget.color = colorCtrl.text;
                  provider.updateWidget(widget);
                } else {
                  provider.addWidget(MonitorWidget(
                    label: label,
                    topic: topic,
                    type: type,
                    unit: unit,
                    icon: icon,
                    minValue: double.tryParse(minCtrl.text),
                    maxValue: double.tryParse(maxCtrl.text),
                    color: colorCtrl.text,
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
          // FIX: Limitamos el ancho a double.maxFinite para evitar layout errors en el GridView
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
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
                    final selected =
                        c.toUpperCase() == hexCtrl.text.toUpperCase();
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

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.cyan;
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
      'alarm': Icons.sensors,
      'toggle': Icons.toggle_on,
      'send': Icons.cell_tower,
    };
    return icons[name] ?? Icons.monitor_heart;
  }
}
