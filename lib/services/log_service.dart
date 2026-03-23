import 'dart:async';
import 'package:hive/hive.dart';
import '../models/log_entry.dart';

class LogService {
  static const String _boxName = 'logs';
  static const int _maxEntries = 1000;
  Box<LogEntry>? _box;

  final _logController = StreamController<LogEntry>.broadcast();
  Stream<LogEntry> get logStream => _logController.stream;

  Future<void> init() async {
    _box = await Hive.openBox<LogEntry>(_boxName);
  }

  Future<void> log(String type, String message) async {
    final entry = LogEntry(type: type, message: message);
    await _box?.add(entry);
    _logController.add(entry);
    await _trimLogs();
  }

  Future<void> _trimLogs() async {
    if (_box == null) return;
    if (_box!.length > _maxEntries) {
      final excess = _box!.length - _maxEntries;
      for (var i = 0; i < excess; i++) {
        await _box!.deleteAt(0);
      }
    }
  }

  List<LogEntry> getAll() {
    return _box?.values.toList().reversed.toList() ?? [];
  }

  List<LogEntry> getByType(String type) {
    return getAll().where((e) => e.type == type).toList();
  }

  Future<void> clear() async {
    await _box?.clear();
  }

  void dispose() {
    _logController.close();
  }
}
