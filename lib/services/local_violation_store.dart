import 'package:hive_flutter/hive_flutter.dart';

class LocalViolationStore {
  static const String _boxName = 'violations';
  static Box? _box;

  /// Initialize Hive and open the box. Call this at app startup.
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// Log a raw event (map) to the local store. The map should be JSON-serializable.
  static Future<void> logEvent(Map<String, dynamic> event) async {
    if (_box == null) return;
    try {
      await _box!.add(event);
    } catch (_) {
      // ignore write failures; store is best-effort for diagnostics
    }
  }

  /// Retrieve all events (for debugging / upload)
  static List<Map> getAllEvents() {
    if (_box == null) return [];
    return _box!.values.cast<Map>().toList();
  }

  /// Clear all stored events (admin/debug)
  static Future<void> clear() async {
    if (_box == null) return;
    await _box!.clear();
  }
}
