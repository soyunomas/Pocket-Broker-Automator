import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'dashboard_button.g.dart';

@HiveType(typeId: 1)
class DashboardButton extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String label;

  @HiveField(2)
  String color;

  @HiveField(3)
  String topic;

  @HiveField(4)
  String payload;

  @HiveField(5)
  int qos;

  @HiveField(6)
  bool retain;

  @HiveField(7)
  String? icon;

  DashboardButton({
    String? id,
    required this.label,
    this.color = '#2196F3',
    required this.topic,
    required this.payload,
    this.qos = 0,
    this.retain = false,
    this.icon,
  }) : id = id ?? const Uuid().v4();
}
