import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import '../services/log_service.dart';

class LogProvider extends ChangeNotifier {
  final LogService logService;
  List<LogEntry> _entries = [];
  String _filterType = 'all';
  StreamSubscription<LogEntry>? _subscription;

  LogProvider({required this.logService}) {
    _entries = logService.getAll();
    _subscription = logService.logStream.listen((_) {
      _refreshEntries();
    });
  }

  List<LogEntry> get entries {
    if (_filterType == 'all') return _entries;
    return _entries.where((e) => e.type == _filterType).toList();
  }

  String get filterType => _filterType;

  void setFilter(String type) {
    _filterType = type;
    notifyListeners();
  }

  void _refreshEntries() {
    _entries = logService.getAll();
    notifyListeners();
  }

  Future<void> clearLogs() async {
    await logService.clear();
    _refreshEntries();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
