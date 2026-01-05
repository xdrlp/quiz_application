import 'dart:async';

import 'package:flutter/services.dart';

class AccessibilityEventPayload {
  AccessibilityEventPayload({
    required this.packageName,
    required this.eventType,
    required this.timestamp,
    this.className,
  });

  final String packageName;
  final String eventType;
  final int timestamp;
  final String? className;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestamp);
}

class AccessibilityMonitor {
  AccessibilityMonitor._();

  static final AccessibilityMonitor instance = AccessibilityMonitor._();

  static const EventChannel _eventChannel = EventChannel('anti_cheat/accessibility_events');
  static const MethodChannel _methodChannel = MethodChannel('anti_cheat/accessibility_control');

  bool _initialized = false;
  final List<AccessibilityEventPayload> _recent = <AccessibilityEventPayload>[];
  final StreamController<AccessibilityEventPayload> _controller = StreamController<AccessibilityEventPayload>.broadcast();
  StreamSubscription? _eventSubscription;

  Stream<AccessibilityEventPayload> get stream => _controller.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      _handleEvent,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void reset() {
    _recent.clear();
  }

  void _handleEvent(dynamic data) {
    if (data is! Map) return;
    final type = data['type']?.toString();
    final timestamp = (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;

    if (type == 'accessibility_event') {
      final packageName = data['packageName']?.toString();
      if (packageName == null || packageName.isEmpty) return;
      final payload = AccessibilityEventPayload(
        packageName: packageName,
        className: data['className']?.toString(),
        eventType: data['eventType']?.toString() ?? 'unknown',
        timestamp: timestamp,
      );
      _recent.add(payload);
      _prune();
      _controller.add(payload);
    } else if (type == 'service_state') {
      // service state changes are useful for diagnostics but we do not store them in the recent list
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 120));
    _recent.removeWhere((event) => event.time.isBefore(cutoff));
  }

  List<AccessibilityEventPayload> recentEvents({DateTime? since, Duration window = const Duration(seconds: 120)}) {
    final now = DateTime.now();
    final effectiveSince = since ?? now.subtract(window);
    return _recent.where((event) => !event.time.isBefore(effectiveSince)).toList(growable: false);
  }

  Future<bool> isServiceEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isServiceEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod<void>('openAccessibilitySettings');
    } catch (_) {}
  }

  /// Dispose the underlying event subscription. Call when the app no longer
  /// needs accessibility events (e.g., after stopping anti-cheat) to avoid
  /// platform channels attempting to send events to a detached engine.
  Future<void> dispose() async {
    try {
      await _eventSubscription?.cancel();
    } catch (_) {}
    _eventSubscription = null;
    _initialized = false;
    // Do not close the controller so callers can re-use the stream after
    // re-initialization; only cancel the platform subscription.
  }

}
