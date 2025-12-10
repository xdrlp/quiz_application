import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:quiz_application/services/app_lifecycle_listener.dart';
import 'package:quiz_application/models/violation_model.dart';
import 'package:quiz_application/services/firestore_service.dart';

class AntiCheatService {
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _deviceInfoSummary;

  late AppLifecycleObserver _lifecycleListener;
  String? _currentAttemptId;
  String? _currentUserId;
  int _violationCount = 0;
  Size? _lastScreenSize;
  bool _isQuizActive = false;

  // Thresholds
  static const int maxViolationsBeforeAutoSubmit = 5;

  AntiCheatService();

  // Optional callback invoked when a violation is detected.
  void Function(ViolationModel)? onViolation;

  /// Set a callback to receive violation events.
  void setOnViolation(void Function(ViolationModel) cb) => onViolation = cb;

  // Initialize anti-cheat for current attempt
  void startAntiCheat(String attemptId, String userId) async {
    _currentAttemptId = attemptId;
    _currentUserId = userId;
    _violationCount = 0;
    _isQuizActive = true;

    // Enable wakelock
    await WakelockPlus.enable();

    // Set FLAG_SECURE on Android
    // Note: flutter_windowmanager setup goes here if already added
    // For now, we'll skip this as it's deprecated in the config

    // Setup lifecycle listener
    _lifecycleListener = AppLifecycleObserver(
      onShow: () => _handleAppResumed(),
      onHide: () => _handleAppPaused(),
      onResume: () => _handleAppResumed(),
      onPause: () => _handleAppPaused(),
    );

    // Collect a brief device summary for diagnostics
    try {
      final android = await _deviceInfo.androidInfo;
      _deviceInfoSummary = 'Android ${android.model} (SDK ${android.version.sdkInt})';
    } catch (_) {
      try {
        final ios = await _deviceInfo.iosInfo;
        _deviceInfoSummary = 'iOS ${ios.name} (${ios.systemVersion})';
      } catch (_) {
        _deviceInfoSummary = 'unknown';
      }
    }
  }

  // Stop anti-cheat after quiz submission
  void stopAntiCheat() async {
    _isQuizActive = false;
    _lifecycleListener.dispose();
    await WakelockPlus.disable();
    // reset any ephemeral state
    _lastScreenSize = null;
  }

  // Detect app switching/minimizing
  void _handleAppPaused() {
    if (_isQuizActive && _currentAttemptId != null) {
      _logViolation(
        ViolationType.appSwitch,
        'App was paused/minimized during quiz',
      );
    }
  }

  void _handleAppResumed() {
    if (_isQuizActive && _currentAttemptId != null) {
      _logViolation(
        ViolationType.appSwitch,
        'App was resumed during quiz',
      );
    }
  }

  // Detect screen resize/split-screen
  void onScreenSizeChanged(Size newSize) {
    if (!_isQuizActive || _currentAttemptId == null) return;

    if (_lastScreenSize != null && _lastScreenSize != newSize) {
      _logViolation(
        ViolationType.screenResize,
        'Screen size changed from $_lastScreenSize to $newSize',
      );
    }
    _lastScreenSize = newSize;
  }

  // Called when a question is answered. Rapid-response detection is disabled.
  void onQuestionAnswered() {
    if (!_isQuizActive || _currentAttemptId == null) return;
    // Previously we detected rapid response here; that check has been removed
    // to avoid false positives. We still record the timestamp for diagnostics
    // but do not log a violation.
    // timestamp intentionally not recorded to avoid storing per-answer timing
  }

  // Log violation to Firestore
  void _logViolation(ViolationType type, String details) async {
    if (_currentAttemptId == null || _currentUserId == null) return;

    _violationCount++;

    final detailsWithDevice = _deviceInfoSummary != null
        ? '$details | device: $_deviceInfoSummary'
        : details;

    final violation = ViolationModel(
      id: '', // Firestore will generate
      attemptId: _currentAttemptId!,
      userId: _currentUserId!,
      type: type,
      details: detailsWithDevice,
      detectedAt: DateTime.now(),
    );

    await _firestoreService.logViolation(violation);

    // Notify any UI listener about this violation so it can show an in-app warning.
    try {
      onViolation?.call(violation);
    } catch (_) {
      // Swallow UI callback errors; they should be handled by the caller.
    }
  }

  // Check if auto-submit should trigger
  bool shouldAutoSubmit() {
    return _violationCount >= maxViolationsBeforeAutoSubmit;
  }

  int getViolationCount() => _violationCount;

  bool isQuizActive() => _isQuizActive;
}
