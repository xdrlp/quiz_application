import 'package:flutter/services.dart';

class ScreenProtector {
  static const MethodChannel _channel = MethodChannel('quiz_application/screen_protector');

  /// Enable or disable platform FLAG_SECURE to prevent screenshots.
  static Future<void> setSecure(bool enable) async {
    try {
      await _channel.invokeMethod('setSecure', {'enable': enable});
    } catch (e) {
      // Platform may not support this — ignore failures.
    }
  }
}
