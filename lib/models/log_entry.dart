import 'package:hive/hive.dart';

part 'log_entry.g.dart';

@HiveType(typeId: 5)
class LogEntry extends HiveObject {
  @HiveField(0)
  int timestamp;

  @HiveField(1)
  String type; // 'sent', 'received', 'error', 'action', 'system'

  @HiveField(2)
  String message;

  LogEntry({
    int? timestamp,
    required this.type,
    required this.message,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}
