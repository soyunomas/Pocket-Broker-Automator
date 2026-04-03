import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'monitor_widget.g.dart';

@HiveType(typeId: 7)
class MonitorWidget extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String label;

  @HiveField(2)
  String topic;

  @HiveField(3)
  String type; // 'gauge', 'chart', 'bars', 'counter', 'log'

  @HiveField(4)
  String unit;

  @HiveField(5)
  String? icon;

  @HiveField(6)
  double? minValue;

  @HiveField(7)
  double? maxValue;

  @HiveField(8)
  String color;

  MonitorWidget({
    String? id,
    required this.label,
    required this.topic,
    required this.type,
    this.unit = '',
    this.icon,
    this.minValue,
    this.maxValue,
    this.color = '#00BCD4',
  }) : id = id ?? const Uuid().v4();
}
