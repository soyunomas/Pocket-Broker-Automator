import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/automation_rule.dart';
import '../services/background_service.dart';

class AutomationProvider extends ChangeNotifier {
  Box<AutomationRule>? _box;
  List<AutomationRule> _rules = [];

  AutomationProvider();

  List<AutomationRule> get rules => _rules;

  Future<void> init() async {
    _box = await Hive.openBox<AutomationRule>('automation_rules');
    _rules = _box!.values.toList();
    notifyListeners();
  }

  void _notifyService() {
    BackgroundServiceController.updateRules(
      _rules.map((r) => r.toMap()).toList(),
    );
  }

  Future<void> addRule(AutomationRule rule) async {
    await _box?.add(rule);
    _rules = _box!.values.toList();
    _notifyService();
    notifyListeners();
  }

  Future<void> updateRule(AutomationRule rule) async {
    await rule.save();
    _rules = _box!.values.toList();
    _notifyService();
    notifyListeners();
  }

  Future<void> deleteRule(AutomationRule rule) async {
    await rule.delete();
    _rules = _box!.values.toList();
    _notifyService();
    notifyListeners();
  }

  Future<void> toggleRule(AutomationRule rule) async {
    rule.enabled = !rule.enabled;
    await rule.save();
    _rules = _box!.values.toList();
    _notifyService();
    notifyListeners();
  }
}
