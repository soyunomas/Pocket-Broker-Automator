import 'package:permission_handler/permission_handler.dart';

class BatteryOptimizer {
  static Future<bool> isIgnoringBatteryOptimizations() async {
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  static Future<bool> requestDisableBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }
}
