import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/monitor_widget.dart';
import '../models/sensor_reading.dart';
import '../services/background_service.dart';

class MonitorProvider extends ChangeNotifier {
  Box<MonitorWidget>? _widgetsBox;
  Box<SensorReading>? _readingsBox;
  List<MonitorWidget> _widgets = [];

  // In-memory latest values per topic
  final Map<String, String> _latestValues = {};
  final Map<String, DateTime> _latestTimestamps = {};

  // In-memory readings cache for charts (last N per topic)
  final Map<String, List<SensorReading>> _readingsCache = {};
  static const int _maxCachedReadings = 10000;
  static const int _maxStoredReadings = 50000;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _connectionSubscription;

  List<MonitorWidget> get widgets => _widgets;
  Map<String, String> get latestValues => _latestValues;
  Map<String, DateTime> get latestTimestamps => _latestTimestamps;

  Future<void> init() async {
    _widgetsBox = await Hive.openBox<MonitorWidget>('monitor_widgets');
    _readingsBox = await Hive.openBox<SensorReading>('sensor_readings');
    _widgets = _widgetsBox!.values.toList();

    // Load latest values from stored readings
    for (final w in _widgets) {
      final readings = _getStoredReadings(w.topic);
      if (readings.isNotEmpty) {
        final latest = readings.last;
        _latestValues[w.topic] = latest.value;
        _latestTimestamps[w.topic] =
            DateTime.fromMillisecondsSinceEpoch(latest.timestamp);
      }
      _readingsCache[w.topic] = readings;
    }

    // Subscribe to topics in the background service
    _subscribeAll();

    // Listen for incoming MQTT messages from background service
    _messageSubscription =
        BackgroundServiceController.on('message').listen((event) {
      if (event == null) return;
      final topic = event['topic'] as String? ?? '';
      final payload = event['payload'] as String? ?? '';
      _onMessage(topic, payload);
    });

    // Re-subscribe all monitor topics when connection is (re)established
    _connectionSubscription =
        BackgroundServiceController.on('connectionState').listen((event) {
      if (event == null) return;
      final stateName = event['state'] as String? ?? 'disconnected';
      if (stateName == 'connected') {
        _subscribeAll();
      }
    });

    notifyListeners();
  }

  void _subscribeAll() {
    for (final w in _widgets) {
      BackgroundServiceController.subscribe(w.topic);
    }
  }

  void _onMessage(String incomingTopic, String payload) {
    // Find all widgets that match this topic (handling wildcards)
    final matchingWidgets = _widgets.where((w) => _topicMatches(w.topic, incomingTopic)).toList();
    if (matchingWidgets.isEmpty) return;

    final now = DateTime.now();

    for (final w in matchingWidgets) {
      // For log widgets using wildcards, show the source topic
      final isWildcardLog = (w.topic.contains('#') || w.topic.contains('+')) && w.type == 'log';
      final displayPayload = isWildcardLog ? '$incomingTopic: $payload' : payload;

      _latestValues[w.topic] = displayPayload;
      _latestTimestamps[w.topic] = now;

      // Store reading
      final reading = SensorReading(topic: w.topic, value: displayPayload);
      _readingsBox?.add(reading);

      // Update cache
      final cache = _readingsCache.putIfAbsent(w.topic, () => []);
      cache.add(reading);
      if (cache.length > _maxCachedReadings) {
        cache.removeAt(0);
      }
    }

    _trimStoredReadings();
    notifyListeners();
  }

  bool _topicMatches(String ruleTopic, String messageTopic) {
    if (ruleTopic == messageTopic) return true;
    final ruleParts = ruleTopic.split('/');
    final msgParts = messageTopic.split('/');
    for (var i = 0; i < ruleParts.length; i++) {
      if (ruleParts[i] == '#') return true;
      if (i >= msgParts.length) return false;
      if (ruleParts[i] == '+') continue;
      if (ruleParts[i] != msgParts[i]) return false;
    }
    return ruleParts.length == msgParts.length;
  }

  void _trimStoredReadings() {
    final box = _readingsBox;
    if (box == null || box.length <= _maxStoredReadings) return;
    final excess = box.length - _maxStoredReadings;
    for (var i = 0; i < excess; i++) {
      box.deleteAt(0);
    }
  }

  List<SensorReading> _getStoredReadings(String topic) {
    if (_readingsBox == null) return [];
    return _readingsBox!.values
        .where((r) => r.topic == topic)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get readings for a topic, optionally filtered by time window.
  List<SensorReading> getReadings(String topic, {Duration? window}) {
    final cached = _readingsCache[topic] ?? _getStoredReadings(topic);
    if (window == null) return cached;
    final cutoff =
        DateTime.now().subtract(window).millisecondsSinceEpoch;
    return cached.where((r) => r.timestamp >= cutoff).toList();
  }

  /// Get numeric values from readings for chart display.
  List<double> getNumericValues(String topic, {Duration? window}) {
    return getReadings(topic, window: window)
        .map((r) => double.tryParse(r.value))
        .where((v) => v != null)
        .cast<double>()
        .toList();
  }

  /// Get time labels from readings.
  List<String> getTimeLabels(String topic, {Duration? window}) {
    return getReadings(topic, window: window).map((r) {
      final t = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }).toList();
  }

  /// Count occurrences of a specific value (or any value) for counter widgets.
  int countEvents(String topic, {String? matchValue, Duration? window}) {
    final readings = getReadings(topic, window: window);
    if (matchValue == null) return readings.length;
    return readings.where((r) => r.value == matchValue).length;
  }

  /// Get hourly counts for bar chart display.
  Map<int, int> getHourlyCounts(String topic, {Duration? window}) {
    final readings =
        getReadings(topic, window: window ?? const Duration(hours: 24));
    final counts = <int, int>{};
    for (final r in readings) {
      final hour =
          DateTime.fromMillisecondsSinceEpoch(r.timestamp).hour;
      counts[hour] = (counts[hour] ?? 0) + 1;
    }
    return counts;
  }

  // --- CRUD ---

  Future<void> addWidget(MonitorWidget widget) async {
    await _widgetsBox?.add(widget);
    _widgets = _widgetsBox!.values.toList();
    BackgroundServiceController.subscribe(widget.topic);
    notifyListeners();
  }

  Future<void> updateWidget(MonitorWidget widget) async {
    await widget.save();
    _widgets = _widgetsBox!.values.toList();
    // Re-subscribe all to ensure the updated topic is active
    _subscribeAll();
    BackgroundServiceController.syncSubscriptions();
    notifyListeners();
  }

  Future<void> deleteWidget(MonitorWidget widget) async {
    // Check if other widgets use the same topic before unsubscribing
    final othersUseTopic =
        _widgets.any((w) => w.id != widget.id && w.topic == widget.topic);
    if (!othersUseTopic) {
      BackgroundServiceController.unsubscribe(widget.topic);
    }
    await widget.delete();
    _widgets = _widgetsBox!.values.toList();
    notifyListeners();
  }

  Future<void> importWidgets(List<MonitorWidget> widgets) async {
    for (final w in widgets) {
      await _widgetsBox?.add(w);
      BackgroundServiceController.subscribe(w.topic);
    }
    _widgets = _widgetsBox!.values.toList();
    notifyListeners();
  }

  Future<void> clearReadings(String topic) async {
    _readingsCache.remove(topic);
    // Remove from Hive
    final box = _readingsBox;
    if (box != null) {
      final keysToDelete = <dynamic>[];
      for (final entry in box.toMap().entries) {
        if (entry.value.topic == topic) {
          keysToDelete.add(entry.key);
        }
      }
      await box.deleteAll(keysToDelete);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }
}
