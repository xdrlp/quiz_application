import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quiz_application/services/app_lifecycle_listener.dart';
import 'package:quiz_application/services/accessibility_monitor.dart';
import 'dart:async';
import 'package:quiz_application/models/violation_model.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/services/local_violation_store.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:usage_stats/usage_stats.dart';

class _AppSwitchTimeline {
  _AppSwitchTimeline({
    this.primaryLabel,
    this.primaryPackage,
    required this.timelineLabels,
    required this.timelinePackages,
    this.trigger,
  });

  final String? primaryLabel;
  final String? primaryPackage;
  final List<String> timelineLabels;
  final List<String> timelinePackages;
  final String? trigger;
}

class _TimelineEvent {
  _TimelineEvent({required this.package, this.className});

  final String package;
  final String? className;
}

class AntiCheatService {
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final AccessibilityMonitor _accessibilityMonitor = AccessibilityMonitor.instance;
  // Subscription to the accessibility event stream while an attempt is active
  StreamSubscription? _accessibilitySubscription;
  final List<dynamic> _capturedAccessibilityEvents = [];
  final List<Map<String, dynamic>> _attemptOpenedApps = [];
  Timer? _foregroundSampler;
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
  String? _packageName;
  final Map<String, String> _appLabelCache = {};
  final Set<String> _appLabelMisses = {};

  static const Duration _violationDebounce = Duration(seconds: 2);

  // Minimum time the app must be backgrounded before counting as an app-switch
  // violation. Short blips (e.g., system overlays or quick sidebars) are
  // ignored to reduce false positives. Tweak as needed (milliseconds).
  static const Duration _minBackgroundDuration = Duration(seconds: 3);

  // Thresholds
  static const int maxViolationsBeforeAutoSubmit = 5;
  // How long (ms) to wait after detecting a switch before sampling system events
  static const int _postSwitchSamplingDelayMs = 2500;
  // How far back (seconds) to query usage/accessibility events when building a timeline
  static const int _usageLookbackSeconds = 120;

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

    await _accessibilityMonitor.initialize();
    _accessibilityMonitor.reset();

    // Start capturing accessibility events for the duration of the attempt so
    // we can include raw event timing in local logs for diagnostics.
    try {
      _accessibilitySubscription = _accessibilityMonitor.stream.listen((ev) {
        try {
          _capturedAccessibilityEvents.add({
            'package': ev.packageName,
            'class': ev.className,
            'type': ev.eventType,
            'ts': ev.timestamp,
          });
          // Keep memory bounded
          if (_capturedAccessibilityEvents.length > 1000) {
            _capturedAccessibilityEvents.removeRange(0, _capturedAccessibilityEvents.length - 1000);
          }
        } catch (_) {}
      });
    } catch (_) {}
      // Start a periodic sampler to capture foreground app via UsageStats as a
      // supplemental signal (some devices do not emit accessibility events).
      try {
        _foregroundSampler = Timer.periodic(const Duration(seconds: 5), (_) async {
          await _sampleForegroundAppAndPersist();
        });
      } catch (_) {}

    if (Platform.isAndroid && _packageName == null) {
      try {
        final info = await PackageInfo.fromPlatform();
        _packageName = info.packageName;
      } catch (_) {
        _packageName = null;
      }
    }

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
      await _accessibilitySubscription?.cancel();
    } catch (_) {}
    _accessibilitySubscription = null;
    _capturedAccessibilityEvents.clear();
    try {
      _foregroundSampler?.cancel();
    } catch (_) {}
    _foregroundSampler = null;

    // Persist final opened apps timeline for this attempt
    try {
      await _persistOpenedApps();
    } catch (_) {}
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
        backgroundSince: _pausedAt,
        captureTimeline: false,
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

      final pauseStarted = _pausedAt;
      final backgrounded = now.difference(_pausedAt!);
      _pausedAt = null;

      if (backgrounded >= _minBackgroundDuration) {
        _logViolation(
          ViolationType.appSwitch,
          'App was backgrounded for ${backgrounded.inSeconds}s during quiz',
          backgroundSince: pauseStarted,
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

  Future<String?> _resolveLastForegroundApp() async {
    if (!Platform.isAndroid) return null;
    try {
      final granted = await UsageStats.checkUsagePermission();
      if (granted != true) return null;

      final end = DateTime.now();
      final start = end.subtract(Duration(seconds: _usageLookbackSeconds));
      final events = await UsageStats.queryEvents(start, end);
      if (events.isEmpty) return null;

      events.sort((a, b) {
        final bt = int.tryParse(b.timeStamp ?? '0') ?? 0;
        final at = int.tryParse(a.timeStamp ?? '0') ?? 0;
        return bt.compareTo(at);
      });

      for (final event in events) {
        final pkg = event.packageName;
        if (pkg == null || pkg.isEmpty) continue;
        if (pkg == _packageName) continue;
        final type = int.tryParse(event.eventType ?? '');
        if (type == 1) {
          return pkg;
        }
      }
      for (final event in events) {
        final pkg = event.packageName;
        if (pkg == null || pkg.isEmpty) continue;
        if (pkg == _packageName) continue;
        return pkg;
      }
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[AntiCheat] Failed to resolve foreground app: $e');
      return null;
    }
  }

  Future<String?> _resolveAppLabel(String package) async {
    if (!Platform.isAndroid) return null;
    if (_appLabelCache.containsKey(package)) return _appLabelCache[package];
    if (_appLabelMisses.contains(package)) return null;

    try {
      final info = await InstalledApps.getAppInfo(package);
      final label = info?.name.trim();
      if (label != null && label.isNotEmpty) {
        _appLabelCache[package] = label;
        return label;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[AntiCheat] Failed to resolve app label for $package: $e');
    }

    _appLabelMisses.add(package);
    return null;
  }

  Future<void> _recordOpenedApp(String package, int timestampMs) async {
    if (package == _packageName) return;
    if (package.isEmpty) return;
    try {
      // Avoid consecutive duplicates within short window
      if (_attemptOpenedApps.isNotEmpty) {
        final last = _attemptOpenedApps.last;
        if (last['package'] == package) {
          final lastTs = (last['ts'] as int?) ?? 0;
          if ((timestampMs - lastTs).abs() < 2000) return;
        }
      }
      _attemptOpenedApps.add({'package': package, 'ts': timestampMs});
      // Keep bounded
      if (_attemptOpenedApps.length > 1000) {
        _attemptOpenedApps.removeRange(0, _attemptOpenedApps.length - 1000);
      }
    } catch (_) {}
  }

  Future<void> _sampleForegroundAppAndPersist() async {
    try {
      // Sample usage stats for recent foreground app
      final granted = await UsageStats.checkUsagePermission();
      if (granted == true) {
        final end = DateTime.now();
        final start = end.subtract(const Duration(seconds: 6));
        final events = await UsageStats.queryEvents(start, end);
        if (events.isNotEmpty) {
          events.sort((a, b) {
            final at = int.tryParse(a.timeStamp ?? '0') ?? 0;
            final bt = int.tryParse(b.timeStamp ?? '0') ?? 0;
            return at.compareTo(bt);
          });
          for (var i = events.length - 1; i >= 0; i--) {
            final ev = events[i];
            final type = int.tryParse(ev.eventType ?? '') ?? 0;
            if (type != 1) continue;
            final pkg = ev.packageName ?? '';
            if (pkg.isEmpty || pkg == _packageName) continue;
            final ts = int.tryParse(ev.timeStamp ?? '') ?? DateTime.now().millisecondsSinceEpoch;
            await _recordOpenedApp(pkg, ts);
            break;
          }
        }
      }

      // Also ingest any accessibility events that occurred since the last
      // persisted entry.
      final acc = _accessibilityMonitor.recentEvents(window: Duration(seconds: _usageLookbackSeconds));
      acc.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      for (final ev in acc) {
        final pkg = ev.packageName;
        if (pkg == _packageName) continue;
        await _recordOpenedApp(pkg, ev.timestamp);
      }

      // Persist a snapshot (best-effort)
      await _persistOpenedApps();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _persistOpenedApps() async {
    if (_currentAttemptId == null) return;
    try {
      // Resolve labels for the timeline
      final resolved = <Map<String, dynamic>>[];
      for (final e in _attemptOpenedApps) {
        final pkg = e['package'] as String? ?? '';
        final ts = e['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
        final label = await _resolveAppLabel(pkg) ?? pkg;
        resolved.add({'package': pkg, 'label': label, 'ts': DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String()});
      }
      await _firestoreService.patchAttempt(_currentAttemptId!, {'openedApps': resolved});
    } catch (_) {}
  }

  Future<_AppSwitchTimeline?> _collectAppSwitchTimeline(DateTime? since) async {
    if (!Platform.isAndroid) return null;
    try {
      final granted = await UsageStats.checkUsagePermission();
      if (granted != true) return null;

      final end = DateTime.now();
      final windowStart = since ?? end.subtract(Duration(seconds: _usageLookbackSeconds));
      final start = windowStart.subtract(const Duration(seconds: 1));
      final events = await UsageStats.queryEvents(start, end);
      if (events.isEmpty) return null;

      final startMs = windowStart.millisecondsSinceEpoch;
      final endMs = end.millisecondsSinceEpoch;

      events.sort((a, b) {
        final at = int.tryParse(a.timeStamp ?? '0') ?? 0;
        final bt = int.tryParse(b.timeStamp ?? '0') ?? 0;
        return at.compareTo(bt);
      });

      final timeline = <_TimelineEvent>[];
      for (final event in events) {
        final pkg = event.packageName;
        if (pkg == null || pkg.isEmpty) continue;
        if (pkg == _packageName) continue;
        final type = int.tryParse(event.eventType ?? '');
        if (type != 1) continue;
        final tsRaw = int.tryParse(event.timeStamp ?? '');
        if (tsRaw == null) continue;
        if (tsRaw < startMs || tsRaw > endMs) continue;
        if (timeline.isEmpty || timeline.last.package != pkg) {
          timeline.add(_TimelineEvent(package: pkg, className: event.className));
        }
      }

      if (timeline.isEmpty) return null;

      final labels = <String>[];
      final packages = <String>[];
      String? primaryLabel;
      String? primaryPackage;

      for (final entry in timeline) {
        final label = await _formatSwitchLabel(entry.package, entry.className);
        labels.add(label);
        packages.add(entry.package);
        if (primaryLabel == null && !_isLikelyLauncher(entry.package, entry.className)) {
          primaryLabel = label;
          primaryPackage = entry.package;
        }
      }

      primaryLabel ??= labels.first;
      primaryPackage ??= packages.first;

      final trigger = _inferLauncherAction(timeline.first);

      return _AppSwitchTimeline(
        primaryLabel: primaryLabel,
        primaryPackage: primaryPackage,
        timelineLabels: labels,
        timelinePackages: packages,
        trigger: trigger,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[AntiCheat] Failed to build app switch timeline: $e');
      return null;
    }
  }

  Future<String> _formatSwitchLabel(String package, String? className) async {
    if (package == 'com.android.systemui') {
      final lower = (className ?? '').toLowerCase();
      if (lower.contains('recents') || lower.contains('overview')) return 'System UI (Recents)';
      if (lower.contains('home') || lower.contains('launcher')) return 'System UI (Home)';
      if (lower.contains('assist')) return 'System UI (Assistant)';
      if (lower.contains('globalactions')) return 'System UI (Power menu)';
      return 'System UI';
    }

    final label = await _resolveAppLabel(package);
    if (label != null && label.isNotEmpty) {
      return '$label ($package)';
    }

    if (_isLikelyLauncher(package, className)) {
      return 'Home launcher ($package)';
    }

    return package;
  }

  bool _isLikelyLauncher(String package, String? className) {
    final lowerPackage = package.toLowerCase();
    final lowerClass = (className ?? '').toLowerCase();
    if (package == 'com.android.systemui') return true;
    if (lowerPackage.contains('launcher') || lowerPackage.contains('home')) return true;
    if (lowerClass.contains('launcher') || lowerClass.contains('home')) return true;
    return false;
  }

  String? _inferLauncherAction(_TimelineEvent event) {
    final lowerClass = (event.className ?? '').toLowerCase();
    if (event.package == 'com.android.systemui') {
      if (lowerClass.contains('recents') || lowerClass.contains('overview')) return 'Recents button';
      if (lowerClass.contains('home') || lowerClass.contains('launcher')) return 'Home button';
      if (lowerClass.contains('assist')) return 'Assistant gesture';
      if (lowerClass.contains('globalactions')) return 'Power menu';
      return 'System UI';
    }
    if (_isLikelyLauncher(event.package, event.className)) {
      return 'Home button';
    }
    return null;
  }

  // Log violation to Firestore
  void _logViolation(ViolationType type, String details, {DateTime? backgroundSince, bool captureTimeline = true}) async {
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

    var augmentedDetails = details;
    if (type == ViolationType.appSwitch) {
      if (captureTimeline) {
        // Give the system a brief moment to emit accessibility/usage events for the switched-to apps.
        // Without this, we often only see the launcher before the user actually opens another app.
        await Future.delayed(Duration(milliseconds: _postSwitchSamplingDelayMs));
      }
      String? switchDescriptor;
      _AppSwitchTimeline? timeline;
      List<String> openedApps = [];

      if (captureTimeline) {
        timeline = await _collectAppSwitchTimeline(backgroundSince);
        if (timeline != null) {
          switchDescriptor = timeline.primaryLabel;
          if (timeline.timelineLabels.length > 1) {
            augmentedDetails = '$augmentedDetails | switchPath: ${timeline.timelineLabels.join(' -> ')}';
          }
          if (timeline.trigger != null && timeline.trigger!.isNotEmpty) {
            augmentedDetails = '$augmentedDetails | trigger: ${timeline.trigger}';
          }
          openedApps.addAll(timeline.timelineLabels);
        }

        final accessibilityNarrative = await _buildAccessibilityNarrative(backgroundSince);
        if (accessibilityNarrative != null && accessibilityNarrative.isNotEmpty) {
          augmentedDetails = '$augmentedDetails | accessibilityPath: $accessibilityNarrative';
          openedApps.addAll(accessibilityNarrative.split(' -> '));
        }

        if (openedApps.isNotEmpty) {
          // dedupe while preserving order
          final seen = <String>{};
          final ordered = <String>[];
          for (final app in openedApps) {
            final key = app.trim();
            if (key.isEmpty) continue;
            if (seen.add(key)) ordered.add(key);
          }

          // If the only entry we captured looks like the launcher/system home,
          // consult the accessibility event buffer for any subsequent app
          // launches that may have been missed by UsageStats on some devices.
          final onlyLauncher = ordered.length == 1 && _isLikelyLauncher(ordered.first, null);
          if (onlyLauncher) {
            try {
              final events = _accessibilityMonitor.recentEvents(since: backgroundSince, window: Duration(seconds: _usageLookbackSeconds));
              // Order by timestamp ascending
              events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              for (final ev in events) {
                final pkg = ev.packageName;
                if (pkg.isEmpty) continue;
                if (pkg == _packageName) continue;
                if (_isLikelyLauncher(pkg, ev.className)) continue;
                final label = await _resolveAppLabel(pkg);
                final readable = (label != null && label.isNotEmpty) ? '$label ($pkg)' : pkg;
                if (seen.add(readable)) ordered.add(readable);
              }
            } catch (_) {}
          }

          if (ordered.isNotEmpty) {
            augmentedDetails = '$augmentedDetails | openedApps: ${ordered.join(' | ')}';
          }
        }
      }

      if (switchDescriptor == null) {
        String? switchedTo = timeline?.primaryPackage ?? await _resolveLastForegroundApp();

        // If the resolved package looks like the launcher or is null, try the
        // accessibility event buffer for a later app that the user opened.
        if (switchedTo == null || _isLikelyLauncher(switchedTo, null)) {
          try {
            final events = _accessibilityMonitor.recentEvents(since: backgroundSince, window: Duration(seconds: _usageLookbackSeconds));
            events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            for (final ev in events) {
              final pkg = ev.packageName;
              if (pkg.isEmpty) continue;
              if (pkg == _packageName) continue;
              if (_isLikelyLauncher(pkg, ev.className)) continue;
              switchedTo = pkg;
              break;
            }
          } catch (_) {}
        }

        if (switchedTo != null) {
          final label = await _resolveAppLabel(switchedTo);
          switchDescriptor = (label != null && label.isNotEmpty && label.toLowerCase() != switchedTo.toLowerCase())
              ? '$label ($switchedTo)'
              : switchedTo;
        }
      }

      if (switchDescriptor != null) {
        augmentedDetails = '$augmentedDetails | switchedTo: $switchDescriptor';
      }

      if (captureTimeline) {
        final accessibilityNarrative = await _buildAccessibilityNarrative(backgroundSince);
        if (accessibilityNarrative != null && accessibilityNarrative.isNotEmpty) {
          augmentedDetails = '$augmentedDetails | accessibilityPath: $accessibilityNarrative';
        }
      }
    }

    if (_deviceInfoSummary != null) {
      augmentedDetails = '$augmentedDetails | device: $_deviceInfoSummary';
    }

    final violation = ViolationModel(
      id: '', // Firestore will generate
      attemptId: _currentAttemptId!,
      userId: _currentUserId!,
      type: type,
      details: augmentedDetails,
      detectedAt: DateTime.now(),
    );

    // Persist raw event locally for auditing and tuning.
    try {
      final rawSample = _capturedAccessibilityEvents.isEmpty
          ? null
          : _capturedAccessibilityEvents.length <= 50
              ? List<dynamic>.from(_capturedAccessibilityEvents)
              : List<dynamic>.from(_capturedAccessibilityEvents.sublist(_capturedAccessibilityEvents.length - 50));

      LocalViolationStore.logEvent({
        'attemptId': _currentAttemptId,
        'userId': _currentUserId,
        'type': type.toString(),
        'details': augmentedDetails,
        'detectedAt': violation.detectedAt.toIso8601String(),
        'violationCount': _violationCount,
        'rawAccessibility': rawSample,
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

  Future<String?> _buildAccessibilityNarrative(DateTime? since) async {
    final events = _accessibilityMonitor.recentEvents(
      since: since,
      window: const Duration(seconds: 45),
    );
    if (events.isEmpty) return null;

    events.sort((a, b) => a.time.compareTo(b.time));

    final labels = <String>[];
    for (final event in events) {
      final label = await _formatAccessibilityEvent(event);
      if (label == null) continue;
      labels.add(label);
    }

    if (labels.isEmpty) return null;
    return labels.join(' -> ');
  }

  Future<String?> _formatAccessibilityEvent(AccessibilityEventPayload event) async {
    final package = event.packageName;
    final className = event.className?.toLowerCase() ?? '';

    if (package == 'com.android.systemui') {
      if (className.contains('recents') || className.contains('overview')) {
        return 'System UI (Recents)';
      }
      if (className.contains('home') || className.contains('launcher')) {
        return 'System UI (Home)';
      }
      if (className.contains('assist')) {
        return 'System UI (Assistant)';
      }
      return 'System UI';
    }

    final label = await _resolveAppLabel(package);
    if (label != null && label.isNotEmpty && label.toLowerCase() != package.toLowerCase()) {
      return '$label ($package)';
    }

    if (package.toLowerCase().contains('launcher')) {
      return 'Launcher ($package)';
    }

    return package;
  }
  // Check if auto-submit should trigger
  bool shouldAutoSubmit() {
    return _violationCount >= maxViolationsBeforeAutoSubmit;
  }

  int getViolationCount() => _violationCount;

  bool isQuizActive() => _isQuizActive;
}
