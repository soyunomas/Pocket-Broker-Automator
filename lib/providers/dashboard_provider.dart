import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/dashboard_button.dart';
import '../services/log_service.dart';
import '../services/background_service.dart';

class DashboardProvider extends ChangeNotifier {
  final LogService logService;
  Box<DashboardButton>? _box;
  List<DashboardButton> _buttons = [];

  DashboardProvider({required this.logService});

  List<DashboardButton> get buttons => _buttons;

  Future<void> init() async {
    _box = await Hive.openBox<DashboardButton>('dashboard_buttons');
    _buttons = _box!.values.toList();
    notifyListeners();
  }

  Future<void> addButton(DashboardButton button) async {
    await _box?.add(button);
    _buttons = _box!.values.toList();
    notifyListeners();
  }

  Future<void> updateButton(DashboardButton button) async {
    await button.save();
    _buttons = _box!.values.toList();
    notifyListeners();
  }

  Future<void> deleteButton(DashboardButton button) async {
    await button.delete();
    _buttons = _box!.values.toList();
    notifyListeners();
  }

  Future<void> importButtons(List<DashboardButton> buttons) async {
    for (final b in buttons) {
      await _box?.add(b);
    }
    _buttons = _box!.values.toList();
    notifyListeners();
  }

  void pressButton(DashboardButton button) {
    BackgroundServiceController.publish(
      button.topic,
      button.payload,
      qos: button.qos,
      retain: button.retain,
    );
    logService.log('sent', '${button.topic} → ${button.payload}');
  }
}
