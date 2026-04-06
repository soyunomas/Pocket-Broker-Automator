import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../models/automation_rule.dart';
import '../models/connection_profile.dart';
import '../models/dashboard_button.dart';
import '../models/monitor_widget.dart';

class ConfigExporter {
  static Map<String, dynamic> buildExportData({
    List<ConnectionProfile>? connections,
    List<AutomationRule>? rules,
    List<DashboardButton>? buttons,
    List<MonitorWidget>? monitors,
  }) {
    final data = <String, dynamic>{
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
    };
    if (connections != null) {
      data['connections'] = connections.map((c) => {
        'id': c.id,
        'alias': c.alias,
        'host': c.host,
        'port': c.port,
        'username': c.username,
        'password': c.password,
        'clientId': c.clientId,
        'ssl': c.ssl,
      }).toList();
    }
    if (rules != null) {
      data['rules'] = rules.map((r) => r.toMap()).toList();
    }
    if (buttons != null) {
      data['buttons'] = buttons.map((b) => {
        'id': b.id,
        'label': b.label,
        'topic': b.topic,
        'payload': b.payload,
        'color': b.color,
        'qos': b.qos,
        'retain': b.retain,
        'icon': b.icon,
      }).toList();
    }
    if (monitors != null) {
      data['monitors'] = monitors.map((m) => {
        'id': m.id,
        'label': m.label,
        'topic': m.topic,
        'type': m.type,
        'unit': m.unit,
        'icon': m.icon,
        'minValue': m.minValue,
        'maxValue': m.maxValue,
        'color': m.color,
      }).toList();
    }
    return data;
  }

  static Future<bool> exportToFile({
    List<ConnectionProfile>? connections,
    List<AutomationRule>? rules,
    List<DashboardButton>? buttons,
    List<MonitorWidget>? monitors,
  }) async {
    final data = buildExportData(
      connections: connections,
      rules: rules,
      buttons: buttons,
      monitors: monitors,
    );
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(json);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar configuración',
      fileName: 'pocketbroker_config.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: Uint8List.fromList(bytes),
    );
    return path != null;
  }

  static Future<Map<String, dynamic>?> importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Importar configuración',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;

    final filePath = result.files.single.path;
    if (filePath == null) return null;

    final content = await File(filePath).readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    return data;
  }

  static List<ConnectionProfile> parseConnections(Map<String, dynamic> data) {
    final list = data['connections'] as List<dynamic>? ?? [];
    return list.map((c) {
      final m = Map<String, dynamic>.from(c);
      return ConnectionProfile(
        id: m['id'] as String?,
        alias: m['alias'] as String? ?? '',
        host: m['host'] as String? ?? '',
        port: m['port'] as int? ?? 1883,
        username: m['username'] as String? ?? '',
        password: m['password'] as String? ?? '',
        clientId: m['clientId'] as String?,
        ssl: m['ssl'] as bool? ?? false,
      );
    }).toList();
  }

  static List<AutomationRule> parseRules(Map<String, dynamic> data) {
    final list = data['rules'] as List<dynamic>? ?? [];
    return list
        .map((r) => AutomationRule.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  static List<DashboardButton> parseButtons(Map<String, dynamic> data) {
    final list = data['buttons'] as List<dynamic>? ?? [];
    return list.map((b) {
      final m = Map<String, dynamic>.from(b);
      return DashboardButton(
        id: m['id'] as String?,
        label: m['label'] as String? ?? '',
        topic: m['topic'] as String? ?? '',
        payload: m['payload'] as String? ?? '',
        color: m['color'] as String? ?? '#2196F3',
        qos: m['qos'] as int? ?? 0,
        retain: m['retain'] as bool? ?? false,
        icon: m['icon'] as String?,
      );
    }).toList();
  }

  static List<MonitorWidget> parseMonitors(Map<String, dynamic> data) {
    final list = data['monitors'] as List<dynamic>? ?? [];
    return list.map((m) {
      final d = Map<String, dynamic>.from(m);
      return MonitorWidget(
        id: d['id'] as String?,
        label: d['label'] as String? ?? '',
        topic: d['topic'] as String? ?? '',
        type: d['type'] as String? ?? 'gauge',
        unit: d['unit'] as String? ?? '',
        icon: d['icon'] as String?,
        minValue: (d['minValue'] as num?)?.toDouble(),
        maxValue: (d['maxValue'] as num?)?.toDouble(),
        color: d['color'] as String? ?? '#00BCD4',
      );
    }).toList();
  }
}
