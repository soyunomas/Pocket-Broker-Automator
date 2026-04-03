import 'package:hive/hive.dart';

part 'sensor_reading.g.dart';

@HiveType(typeId: 8)
class SensorReading extends HiveObject {
  @HiveField(0)
  String topic;

  @HiveField(1)
  String value;

  @HiveField(2)
  int timestamp;

  SensorReading({
    required this.topic,
    required this.value,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}
