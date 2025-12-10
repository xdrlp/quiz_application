import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:quiz_application/services/app_lifecycle_listener.dart';
import 'package:quiz_application/models/violation_model.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/services/local_violation_store.dart';

class AntiCheatService {
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _deviceInfoSummary;

  AppLifecycleObserver? _lifecycleListener;
  String? _currentAttemptId;
  String? _currentUserId;
  int _violationCount = 0;
  Size? _lastScreenSize;
  bool _isQuizActive = false;
  DateTime? _lastViolationAt;
  ViolationType? _lastViolationType;
  DateTime? _pausedAt;

  static const Duration _violationDebounce = Duration(seconds: 2);

  // Minimum time the app must be backgrounded before counting as an app-switch
  // violation. Short blips (e.g., system overlays or quick sidebars) are
  // ignored to reduce false positives. Tweak as needed (milliseconds).
  static const Duration _minBackgroundDuration = Duration(seconds: 3);

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
    // Debug log
    // ignore: avoid_print
    print('[AntiCheat] startAntiCheat attempt=$attemptId user=$userId');

    // Setup lifecycle listener first so we still detect pauses/resumes even if
    // platform-specific APIs (like wakelock) fail to initialize.
    _lifecycleListener = AppLifecycleObserver(
      onShow: () => _handleAppResumed(),
      onHide: () => _handleAppPaused(),
      onResume: () => _handleAppResumed(),
      onPause: () => _handleAppPaused(),
    );

    // Enable wakelock if available. Wrap in try/catch because some devices
    // or build configurations may not have the wakelock platform channel
    // available, and we must not let that exception prevent anti-cheat from
    // working (we still detect lifecycle events via the listener).
    try {
      await WakelockPlus.enable();
    } catch (e, st) {
      // ignore: avoid_print
      print('[AntiCheat] Wakelock enable failed: $e\n$st');
    }

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
    if (_lifecycleListener != null) {
      _lifecycleListener!.dispose();
      _lifecycleListener = null;
    }
    try {
      await WakelockPlus.disable();
    } catch (e, st) {
      // ignore: avoid_print
      print('[AntiCheat] Wakelock disable failed: $e\n$st');
    }
    // reset any ephemeral state
    _lastScreenSize = null;
  }

  // Detect app switching/minimizing
  void _handleAppPaused() {
    if (_isQuizActive && _currentAttemptId != null) {
      // Record when the app was paused and log an immediate (warning)
      // violation. This ensures quick interactions with the system UI
      // (e.g. opening the recent-apps sidebar) generate a visible warning.
      // If the app stays backgrounded longer than the configured minimum,
      // we'll record a second, stronger violation on resume.
      _pausedAt = DateTime.now();
      _logViolation(
        ViolationType.appSwitch,
        'App was paused/minimized during quiz',
      );
      // ignore: avoid_print
      print('[AntiCheat] recorded pause at $_pausedAt and logged immediate warning');
    }
  }

  void _handleAppResumed() {
    if (_isQuizActive && _currentAttemptId != null) {
      final now = DateTime.now();
      if (_pausedAt == null) {
        // No recorded pause; ignore as we cannot determine duration.
        // ignore: avoid_print
        print('[AntiCheat] resume detected with no prior pause recorded');
        return;
      }

      final backgrounded = now.difference(_pausedAt!);
      _pausedAt = null;

      if (backgrounded >= _minBackgroundDuration) {
        _logViolation(
          ViolationType.appSwitch,
          'App was backgrounded for ${backgrounded.inSeconds}s during quiz',
        );
        // ignore: avoid_print
        print('[AntiCheat] detected app resumed (backgrounded ${backgrounded.inMilliseconds}ms) - counted as appSwitch');
      } else {
        // ignore: avoid_print
        print('[AntiCheat] detected app resumed after ${backgrounded.inMilliseconds}ms - ignored as transient');
      }
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

    // Debounce duplicate rapid violations of the same type. If a violation of
    // the same type was recorded recently, ignore this duplicate to avoid
    // inflating the violation count from lifecycle noise (pause/resume pairs,
    // transient onHide/onPause pairs, etc.).
    final now = DateTime.now();
    if (_lastViolationType == type && _lastViolationAt != null && now.difference(_lastViolationAt!) < _violationDebounce) {
      // ignore: avoid_print
      print('[AntiCheat] Ignoring duplicate violation of type=$type within debounce window');
      return;
    }
    _lastViolationAt = now;
    _lastViolationType = type;

    _violationCount++;

    // Debug log
    // ignore: avoid_print
    print('[AntiCheat] _logViolation type=$type count=$_violationCount details=$details');

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

    // Persist raw event locally for auditing and tuning.
    try {
      LocalViolationStore.logEvent({
        'attemptId': _currentAttemptId,
        'userId': _currentUserId,
        'type': type.toString(),
        'details': detailsWithDevice,
        'detectedAt': violation.detectedAt.toIso8601String(),
        'violationCount': _violationCount,
      });
    } catch (_) {}

    // Notify any UI listener about this violation so it can show an in-app warning.
    // Call the UI callback immediately (don't wait for Firestore) so the app
    // can react in real-time even if network is slow or unavailable.
    try {
      onViolation?.call(violation);
    } catch (_) {
      // Swallow UI callback errors; they should be handled by the caller.
    }

    // Log to Firestore asynchronously; don't block the UI notification.
    // Fire-and-forget the logging call.
    _firestoreService.logViolation(violation);
  }

  // Check if auto-submit should trigger
  bool shouldAutoSubmit() {
    return _violationCount >= maxViolationsBeforeAutoSubmit;
  }

  int getViolationCount() => _violationCount;

  bool isQuizActive() => _isQuizActive;
}
