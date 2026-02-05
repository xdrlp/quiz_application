import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/violation_model.dart';
import 'package:quiz_application/services/anti_cheat_service.dart';
import 'package:quiz_application/services/accessibility_monitor.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/utils/answer_utils.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/local_violation_store.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:quiz_application/services/screen_protector.dart';

class TakeQuizPage extends StatefulWidget {
  final String quizId;
  const TakeQuizPage({super.key, required this.quizId});

  @override
  State<TakeQuizPage> createState() => _TakeQuizPageState();
}

class _TakeQuizPageState extends State<TakeQuizPage>
    with WidgetsBindingObserver {
  final FirestoreService _firestore = FirestoreService();
  final AntiCheatService _antiCheat = AntiCheatService();

  bool _loading = true;
  String? _quizTitle;
  List<QuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  final Map<String, String> _answers = {}; // questionId -> response
  final Map<String, List<String>> _multiAnswers = {}; // for checkbox
  String? _attemptId;
  Timer? _timer;
  int? _remainingSeconds;
  Size? _reportedScreenSize;
  DateTime? _questionStartTime;
  final Map<String, AttemptAnswerModel> _answerModels = {};
  final Set<String> _flaggedQuestionIds = {};
  final Set<String> _lockedQuestionIds = {};
  DateTime? _attemptStartedAt;
  final TextEditingController _textController = TextEditingController();
  final List<ViolationModel> _pendingViolations = [];
  bool _isShowingViolationDialog = false;
  bool? _usageAccessGranted;
  bool? _accessibilityServiceEnabled;

  String? _extractDetailValue(String? details, String key) {
    if (details == null || details.isEmpty) return null;
    final prefix = '${key.toLowerCase()}:';
    for (final part in details.split('|')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      if (lower.startsWith(prefix)) {
        return trimmed.substring(prefix.length).trim();
      }
    }
    return null;
  }

  String? _extractSwitchedToApp(String? details) {
    final value = _extractDetailValue(details, 'switchedTo');
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'^(.*)\(([^)]+)\)$').firstMatch(value);
    if (match != null) {
      final label = match.group(1)?.trim();
      final pkg = match.group(2)?.trim();
      if (pkg != null && pkg.contains('.')) {
        if (label != null && label.isNotEmpty) {
          return '$label [$pkg]';
        }
        return pkg;
      }
    }
    return value;
  }

  String? _extractSwitchPath(String? details) =>
      _extractDetailValue(details, 'switchPath');

  String? _extractTrigger(String? details) =>
      _extractDetailValue(details, 'trigger');

  String? _extractAccessibilityPath(String? details) =>
      _extractDetailValue(details, 'accessibilityPath');

  String? _extractOpenedApps(String? details) =>
      _extractDetailValue(details, 'openedApps');

  String _violationMessage(ViolationModel v) {
    switch (v.type) {
      case ViolationType.appSwitch:
        final target = _extractSwitchedToApp(v.details);
        final sequence = _extractSwitchPath(v.details);
        final trigger = _extractTrigger(v.details);
        final accessibilityPath = _extractAccessibilityPath(v.details);
        final openedApps = _extractOpenedApps(v.details);
        final extras = <String>[];
        // Prefer showing the ordered list of opened apps first so the UI
        // always displays a sequence the user opened (even if it's just the
        // system home). This helps post-hoc review and answers the user's
        // expectation for a list.
        if (openedApps != null && openedApps.isNotEmpty) {
          extras.add('Opened apps (ordered): $openedApps.');
        } else if (target != null) {
          // Fallback to single-package description when openedApps not present
          extras.add('Detected switch to: $target.');
        }
        if (sequence != null && sequence.isNotEmpty) {
          extras.add('Observed sequence: $sequence.');
        }
        if (trigger != null && trigger.isNotEmpty) {
          extras.add('Likely action: $trigger.');
        }
        if (accessibilityPath != null && accessibilityPath.isNotEmpty) {
          extras.add('Accessibility trace: $accessibilityPath.');
        }
        final suffix = extras.isNotEmpty ? '\n\n${extras.join('\n')}' : '';
        return 'You left the quiz screen or switched to another app. Please remain on the quiz screen until you finish the attempt.$suffix';
      case ViolationType.screenResize:
        return 'Your screen size changed (split-screen or rotation). Please keep the app fullscreen while taking the quiz.';
      default:
        return 'We detected possible policy-violating behavior: ${v.type.toString().split('.').last}. Please remain on the quiz screen.';
    }
  }

  Future<void> _showDebugInfoDialog() async {
    final flagged = _flaggedQuestionIds.toList();
    final answersMap = _answerModels.map((k, v) => MapEntry(k, v.toMap()));
    final events = LocalViolationStore.getAllEvents();
    final payload = {
      'flagged': flagged,
      'answers': answersMap,
      'localEvents': events,
    };
    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    if (!mounted) {
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Debug: Anti-cheat state'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: Text(pretty)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showViolationAlert(ViolationModel v) async {
    if (!mounted) return;
    if (_isShowingViolationDialog) return;
    _isShowingViolationDialog = true;
    try {
      final base = _violationMessage(v);
      // Determine current violation count so we can show the exact consequence
      final count = _antiCheat.getViolationCount();
      String consequence;
      if (count <= 1) {
        consequence = 'This is a warning. Please remain on the quiz screen.';
      } else if (count == 2) {
        consequence =
            'Second violation: the current question will be flagged as incorrect.';
      } else {
        consequence =
            'Final violation: your attempt will be automatically submitted.';
      }
      final message = '$base\n\n$consequence';
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Policy notice'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      // Apply consequences after user acknowledges
      _applyViolationConsequences();
    } catch (e, st) {
      // If dialog failed due to routing races, buffer the violation instead
      // and apply consequences when the user returns.
      // ignore: avoid_print
      print('[TakeQuizPage] _showViolationAlert failed: $e\n$st');
      if (mounted) {
        _pendingViolations.add(v);
      }
    } finally {
      _isShowingViolationDialog = false;
    }
  }

  Future<void> _refreshMonitoringPrereqs() async {
    if (!Platform.isAndroid) {
      if (!mounted) return;
      setState(() {
        _usageAccessGranted = true;
        _accessibilityServiceEnabled = true;
      });
      return;
    }

    final usageGranted = (await UsageStats.checkUsagePermission()) == true;
    final monitor = AccessibilityMonitor.instance;
    await monitor.initialize();
    final accessibilityEnabled = await monitor.isServiceEnabled();

    if (!mounted) return;
    setState(() {
      _usageAccessGranted = usageGranted;
      _accessibilityServiceEnabled = accessibilityEnabled;
    });
  }

  Future<bool> _ensureAccessibilityService() async {
    if (!Platform.isAndroid) {
      await _refreshMonitoringPrereqs();
      return true;
    }

    final monitor = AccessibilityMonitor.instance;
    await monitor.initialize();
    if (await monitor.isServiceEnabled()) {
      await _refreshMonitoringPrereqs();
      return true;
    }

    if (!mounted) return false;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accessibility monitoring required'),
        content: const Text(
          'To monitor which apps are opened during the quiz, enable the accessibility service for this app, then return here.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await monitor.openAccessibilitySettings();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final recheck = await monitor.isServiceEnabled();
    await _refreshMonitoringPrereqs();

    if (!recheck && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Accessibility service not enabled. Please turn it on and try again.',
          ),
        ),
      );
    }

    return recheck;
  }

  Future<void> _openUsageAccessSettings() async {
    if (!Platform.isAndroid) return;
    await UsageStats.grantUsagePermission();
  }

  Future<void> _openAccessibilitySettings() async {
    if (!Platform.isAndroid) return;
    final monitor = AccessibilityMonitor.instance;
    await monitor.initialize();
    await monitor.openAccessibilitySettings();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshMonitoringPrereqs();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _antiCheat.stopAntiCheat();
    WidgetsBinding.instance.removeObserver(this);
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final quiz = await _firestore.getQuiz(widget.quizId);
    if (quiz == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (quiz.password != null && quiz.password!.isNotEmpty) {
      // Enforce password for everyone to ensure security and allow creators to test it.
      if (mounted) {
        bool authenticated = false;
        while (!authenticated) {
          final String? input = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              final ctrl = TextEditingController();
              return AlertDialog(
                title: const Text('Password Required'),
                content: TextField(
                  controller: ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Enter quiz password',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, ctrl.text),
                    child: const Text('Submit'),
                  ),
                ],
              );
            },
          );

          if (input == null) {
            if (mounted) Navigator.of(context).pop();
            return;
          }

          if (input == quiz.password) {
            authenticated = true;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Incorrect password')),
              );
            }
          }
        }
      }
    }

    var qs = await _firestore.getQuizQuestions(widget.quizId);

    // Apply randomization logic
    if (quiz.randomizeQuestions) {
      qs.shuffle();
    }

    if (quiz.randomizeOptions) {
      qs = qs.map((q) {
        // Only shuffle choices for questions that have them
        if (q.choices.isNotEmpty) {
          final shuffledChoices = List<Choice>.from(q.choices)..shuffle();
          return q.copyWith(choices: shuffledChoices);
        }
        return q;
      }).toList();
    }

    setState(() {
      _quizTitle = quiz.title;
      _questions = qs;
      _loading = false;
    });
  }

  Future<bool> _ensureUsageAccessPermission() async {
    if (!Platform.isAndroid) {
      await _refreshMonitoringPrereqs();
      return true;
    }
    final granted = (await UsageStats.checkUsagePermission()) == true;
    if (granted) {
      await _refreshMonitoringPrereqs();
      return true;
    }

    if (!mounted) return false;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usage access required'),
        content: const Text(
          'To detect app switching, the app needs Usage Access permission. Tap Continue to open system settings, enable the permission for this app, then return to restart the attempt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await UsageStats.grantUsagePermission();
      // give the system a moment; user may still be in settings when this completes
      await Future.delayed(const Duration(milliseconds: 500));
    }

    final recheck = (await UsageStats.checkUsagePermission()) == true;
    await _refreshMonitoringPrereqs();
    if (recheck) {
      return true;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Usage Access permission not granted. Please enable it in system settings and then try again.',
          ),
        ),
      );
    }
    return false;
  }

  Future<void> _startAttempt() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    final totalPoints = _questions.fold<int>(0, (s, q) => s + q.points);
    final attempt = AttemptModel(
      id: '',
      quizId: widget.quizId,
      userId: user.uid,
      startedAt: DateTime.now(),
      score: 0,
      totalPoints: totalPoints,
      answers: [],
      totalViolations: 0,
    );

    final id = await _firestore.createAttempt(attempt);
    setState(() {
      _attemptId = id;
      _currentQuestionIndex = 0;
      _questionStartTime = DateTime.now();
      _attemptStartedAt = attempt.startedAt;
      _syncTextControllerToCurrentQuestion();
    });

    // Enable screenshot protection for the duration of the attempt.
    try {
      await ScreenProtector.setSecure(true);
    } catch (_) {}

    // Register the UI handler before starting anti-cheat to avoid races.
    _antiCheat.setOnViolation((violation) async {
      // Debug: log that the UI callback was invoked
      // ignore: avoid_print
      print('[TakeQuizPage] onViolation callback invoked: ${violation.type}');
      if (!mounted) {
        return;
      }
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (isCurrentRoute) {
        // Show a single, descriptive alert dialog for the violation.
        await _showViolationAlert(violation);
      } else {
        // Buffer for consolidated display when the user returns.
        // Debug
        // ignore: avoid_print
        print('[TakeQuizPage] Not current route, buffering violation');
        _pendingViolations.add(violation);
      }
    });

    _antiCheat.startAntiCheat(id, user.uid);
    // quick confirmation so tester knows monitoring is active
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anti-cheat monitoring enabled'),
          duration: Duration(seconds: 1),
        ),
      );
    }
    await _refreshMonitoringPrereqs();

    final quiz = await _firestore.getQuiz(widget.quizId);
    final tl = quiz?.timeLimitSeconds ?? 0;
    if (tl > 0) {
      setState(() {
        _remainingSeconds = tl;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remainingSeconds == null) return;
        if (_remainingSeconds! <= 0) {
          _submitAttempt();
          t.cancel();
        } else {
          setState(() => _remainingSeconds = _remainingSeconds! - 1);
        }
      });
    }
  }

  /// Show a policy/violation notice to the user before starting the attempt.
  /// Requires user acknowledgement (checkbox) before enabling Start.
  Future<void> _confirmStartAttempt() async {
    await _refreshMonitoringPrereqs();
    if (!mounted) return;
    var acknowledged = false;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Violation Policy Notice'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please read and acknowledge the exam conduct policy before starting. Violations such as collaboration, screen sharing, use of unauthorised resources, or attempting to circumvent monitoring may be detected and penalised.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'If you understand and agree to abide by the policy, check the box below to enable Start.',
                    ),
                    const SizedBox(height: 12),
                    _monitoringStatusRow(
                      'Usage access permission required',
                      _usageAccessGranted == true,
                      () async {
                        await _openUsageAccessSettings();
                        await Future.delayed(const Duration(milliseconds: 500));
                        await _refreshMonitoringPrereqs();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 6),
                    _monitoringStatusRow(
                      'Accessibility service required',
                      _accessibilityServiceEnabled == true,
                      () async {
                        await _openAccessibilitySettings();
                        await Future.delayed(const Duration(milliseconds: 500));
                        await _refreshMonitoringPrereqs();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: acknowledged,
                      onChanged: (v) =>
                          setState(() => acknowledged = v ?? false),
                      title: const Text(
                        'I have read and agree to the conduct policy',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: acknowledged
                      ? () {
                          Navigator.of(ctx).pop(true);
                        }
                      : null,
                  child: const Text('Start Attempt'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;

    if (res == true) {
      final usageAllowed = await _ensureUsageAccessPermission();
      if (!usageAllowed) return;
      final accessibilityAllowed = await _ensureAccessibilityService();
      if (!accessibilityAllowed) return;
      await _startAttempt();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshMonitoringPrereqs();
    }
    if (state == AppLifecycleState.resumed &&
        _pendingViolations.isNotEmpty &&
        mounted) {
      // Consolidate pending violations into a single alert to avoid spamming the user.
      final toShow = List<ViolationModel>.from(_pendingViolations);
      _pendingViolations.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showViolationsSummary(toShow);
      });
    }
  }

  Future<void> _showViolationsSummary(List<ViolationModel> list) async {
    if (!mounted) return;
    if (_isShowingViolationDialog) return;
    _isShowingViolationDialog = true;
    try {
      // Build a friendly summary with counts per type
      final Map<String, int> counts = {};
      for (var v in list) {
        final key = v.type.toString().split('.').last;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      final parts = counts.entries.map((e) => '${e.value}× ${e.key}').toList();
      final summary = parts.join(', ');
      var message =
          'Detected ${list.length} anti-cheat event(s): $summary. Please remain on the quiz screen.';
      final switchedTargets = list
          .map((v) => _extractSwitchedToApp(v.details))
          .whereType<String>()
          .toSet()
          .toList();
      if (switchedTargets.isNotEmpty) {
        message += '\n\nRecent app switches: ${switchedTargets.join(', ')}.';
      }
      final sequences = list
          .map((v) => _extractSwitchPath(v.details))
          .whereType<String>()
          .toSet()
          .toList();
      if (sequences.isNotEmpty) {
        message += '\nObserved sequences: ${sequences.join(' | ')}.';
      }
      final triggers = list
          .map((v) => _extractTrigger(v.details))
          .whereType<String>()
          .toSet()
          .toList();
      if (triggers.isNotEmpty) {
        message += '\nLikely actions: ${triggers.join(', ')}.';
      }
      final accessibilityPaths = list
          .map((v) => _extractAccessibilityPath(v.details))
          .whereType<String>()
          .toSet()
          .toList();
      if (accessibilityPaths.isNotEmpty) {
        message += '\nAccessibility traces: ${accessibilityPaths.join(' | ')}.';
      }
      final openedApps = list
          .map((v) => _extractOpenedApps(v.details))
          .whereType<String>()
          .toSet()
          .toList();
      if (openedApps.isNotEmpty) {
        message += '\nOpened apps: ${openedApps.join(' | ')}.';
      }
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Policy notice'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      _applyViolationConsequences();
    } catch (e, st) {
      // ignore: avoid_print
      print('[TakeQuizPage] _showViolationsSummary failed: $e\n$st');
      // If dialog couldn't be shown, keep the list empty (we already cleared it) and return.
    } finally {
      _isShowingViolationDialog = false;
    }
  }

  Widget _monitoringStatusRow(
    String label,
    bool ready,
    Future<void> Function()? onPressed,
  ) {
    final icon = ready ? Icons.check_circle : Icons.warning_amber_rounded;
    final color = ready ? const Color(0xFF222222) : Colors.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)),
            ),
          ),
          if (!ready)
            TextButton(
              onPressed: onPressed == null
                  ? null
                  : () async {
                      await onPressed();
                    },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF222222)),
              child: const Text('Open settings'),
            ),
        ],
      ),
    );
  }

  Widget _buildMonitoringBanner() {
    final usageReady = _usageAccessGranted == true;
    final accessibilityReady = _accessibilityServiceEnabled == true;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          const BoxShadow(
            color: Colors.white,
            offset: Offset(-4, -4),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(4, 4),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Enable monitoring protections',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF222222)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Usage access and accessibility monitoring must be enabled before starting the quiz.',
            style: TextStyle(color: Color(0xFF7F8C8D)),
          ),
          const SizedBox(height: 12),
          _monitoringStatusRow(
            'Usage access permission',
            usageReady,
            () async {
              await _openUsageAccessSettings();
            },
          ),
          const SizedBox(height: 6),
          _monitoringStatusRow(
            'Accessibility service',
            accessibilityReady,
            () async {
              await _openAccessibilitySettings();
            },
          ),
        ],
      ),
    );
  }

  void _nextQuestion() {
    if (_currentQuestionIndex + 1 < _questions.length) {
      setState(() {
        _currentQuestionIndex = _currentQuestionIndex + 1;
        _questionStartTime = DateTime.now();
        _syncTextControllerToCurrentQuestion();
      });
    } else {
      _submitAttempt();
    }
  }

  void _syncTextControllerToCurrentQuestion() {
    if (_questions.isEmpty) return;
    final q = _questions[_currentQuestionIndex];
    if (q.type == QuestionType.shortAnswer ||
        q.type == QuestionType.paragraph) {
      final text = _answers[q.id] ?? '';
      // avoid reassigning if same text to reduce cursor jumps
      if (_textController.text != text) {
        _textController.text = text;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length),
        );
      }
    } else {
      // clear controller when not a text-type question to avoid visual carryover
      if (_textController.text.isNotEmpty) {
        _textController.clear();
      }
    }
  }

  String _formatRemaining(int seconds) {
    if (seconds < 0) seconds = 0;
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    final mm = mins.toString().padLeft(2, '0');
    final ss = secs.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _recordCurrentAnswerIfNeeded() {
    if (_questions.isEmpty) return;
    final q = _questions[_currentQuestionIndex];
    final qid = q.id;
    final now = DateTime.now();
    final duration = _questionStartTime != null
        ? now.difference(_questionStartTime!).inSeconds
        : 0;

    if (q.type == QuestionType.multipleChoice ||
        q.type == QuestionType.dropdown) {
      // already recorded in _answerSingle
      return;
    }

    String userResp;
    if (q.type == QuestionType.checkbox) {
      userResp = (_multiAnswers[qid] ?? []).join(',');
    } else {
      userResp = _answers[qid] ?? '';
    }

    final existing = _answerModels[qid];
    final model = AttemptAnswerModel(
      questionId: qid,
      selectedChoiceId: userResp,
      timeTakenSeconds: duration,
      answeredAt: now,
      isCorrect: false,
      forceIncorrect:
          (existing?.forceIncorrect ?? false) ||
          _flaggedQuestionIds.contains(qid),
    );
    _answerModels[qid] = model;
    // debug: log each write to answer models for diagnostics
    // ignore: avoid_print
    print(
      '[TakeQuizPage] _recordCurrentAnswerIfNeeded wrote for qid=$qid model=$model flagged=${_flaggedQuestionIds.contains(qid)}',
    );
  }

  // Previously used a MaterialBanner for violations. We now present a single
  // AlertDialog per violation (or a consolidated dialog on resume) for a
  // cleaner, less noisy UX. The banner implementation has been removed.

  // Flag the current question as incorrect immediately (used as a penalty).
  /// Marks the current question as forcibly incorrect. Returns true if the
  /// question was newly flagged, false if it was already flagged.
  bool _flagCurrentQuestionIncorrect() {
    if (_questions.isEmpty) return false;
    final q = _questions[_currentQuestionIndex];
    final qid = q.id;

    // If already flagged, do nothing.
    if (_flaggedQuestionIds.contains(qid)) return false;

    final now = DateTime.now();
    final duration = _questionStartTime != null
        ? now.difference(_questionStartTime!).inSeconds
        : 0;

    String userResp = '';
    if (q.type == QuestionType.checkbox) {
      userResp = (_multiAnswers[qid] ?? []).join(',');
    } else {
      userResp = _answers[qid] ?? '';
    }

    final penalized = AttemptAnswerModel(
      questionId: qid,
      selectedChoiceId: userResp,
      timeTakenSeconds: duration,
      answeredAt: now,
      isCorrect: false,
      forceIncorrect: true,
    );
    setState(() {
      _answerModels[qid] = penalized;
      _flaggedQuestionIds.add(qid);
      _lockedQuestionIds.add(qid);
    });
    // debug: log the penalized model for diagnostics
    // ignore: avoid_print
    print(
      '[TakeQuizPage] _flagCurrentQuestionIncorrect applied for qid=$qid penalized=$penalized',
    );
    // ignore: avoid_print
    print('[TakeQuizPage] flagged set now=${_flaggedQuestionIds.toList()}');
    // persist flagged id to Firestore so server-side record exists (best-effort)
    try {
      if (_attemptId != null) {
        _firestore.patchAttempt(_attemptId!, {
          'flaggedQuestionIds': FieldValue.arrayUnion([qid]),
        });
      }
    } catch (e) {
      // ignore persistence failures
      // ignore: avoid_print
      print('[TakeQuizPage] failed to persist flagged id to firestore: $e');
    }
    return true;
  }

  // Apply consequences depending on the current violation count.
  // 1st violation: warning only (already shown)
  // 2nd violation: flag current question incorrect
  // 3rd+ violation: auto-submit attempt (unanswered default to incorrect)
  void _applyViolationConsequences() {
    final count = _antiCheat.getViolationCount();
    if (count <= 1) {
      // nothing more than the warning
      return;
    }
    if (count == 2) {
      final flagged = _flagCurrentQuestionIncorrect();
      if (flagged && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Current question flagged as incorrect due to policy violation',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        // advance the user automatically so they can't change the flagged answer
        Future.microtask(() {
          if (mounted) _nextQuestion();
        });
      }
      return;
    }
    // count >= 3 -> auto-submit
    // ensure current question is flagged as incorrect as well
    final flagged = _flagCurrentQuestionIncorrect();
    if (flagged && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Current question flagged as incorrect due to policy violation',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
    // small delay so the snackbar/changes have a moment to settle
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _submitAttempt();
    });
  }

  void _answerCheckbox(String qid, String choiceId, bool selected) {
    if (_lockedQuestionIds.contains(qid)) {
      // ignore changes to locked (flagged) questions
      // ignore: avoid_print
      print('[TakeQuizPage] _answerCheckbox ignored for locked qid=$qid');
      return;
    }
    final list = _multiAnswers[qid] ?? [];
    if (selected) {
      list.add(choiceId);
    } else {
      list.remove(choiceId);
    }
    _multiAnswers[qid] = list;
    _antiCheat.onQuestionAnswered();
  }

  void _answerSingle(String qid, String choiceId) {
    if (_lockedQuestionIds.contains(qid)) {
      // ignore single-choice changes for locked questions
      // ignore: avoid_print
      print('[TakeQuizPage] _answerSingle ignored for locked qid=$qid');
      return;
    }
    _answers[qid] = choiceId;
    final now = DateTime.now();
    final duration = _questionStartTime != null
        ? now.difference(_questionStartTime!).inSeconds
        : 0;
    final existing = _answerModels[qid];
    _answerModels[qid] = AttemptAnswerModel(
      questionId: qid,
      selectedChoiceId: choiceId,
      timeTakenSeconds: duration,
      answeredAt: now,
      isCorrect: false,
      forceIncorrect:
          (existing?.forceIncorrect ?? false) ||
          _flaggedQuestionIds.contains(qid),
    );
    // debug: log each write to answer models for diagnostics
    // ignore: avoid_print
    print(
      '[TakeQuizPage] _answerSingle wrote for qid=$qid model=${_answerModels[qid]} flagged=${_flaggedQuestionIds.contains(qid)}',
    );
    _antiCheat.onQuestionAnswered();
    Future.microtask(() {
      if (mounted) _nextQuestion();
    });
  }

  void _answerText(String qid, String text) {
    if (_lockedQuestionIds.contains(qid)) {
      // ignore text edits for locked questions
      // ignore: avoid_print
      print('[TakeQuizPage] _answerText ignored for locked qid=$qid');
      return;
    }
    _answers[qid] = text;
    _antiCheat.onQuestionAnswered();
  }

  Future<void> _submitAttempt() async {
    if (_attemptId == null) {
      return;
    }

    int score = 0;
    final answersList = <AttemptAnswerModel>[];

    for (var q in _questions) {
      final qid = q.id;
      final existing = _answerModels[qid];
      String userResp = existing?.selectedChoiceId ?? '';
      if (userResp.isEmpty) {
        // fallback to current answer maps
        if (q.type == QuestionType.checkbox) {
          userResp = (_multiAnswers[qid] ?? []).join(',');
        } else {
          userResp = _answers[qid] ?? '';
        }
      }

      bool correct = false;
      if (q.type == QuestionType.checkbox) {
        final expected = q.correctAnswers.toSet();
        final actual = (_multiAnswers[qid] ?? []).toSet();
        correct =
            expected.length == actual.length &&
            expected.difference(actual).isEmpty;
      } else if (q.type == QuestionType.multipleChoice ||
          q.type == QuestionType.dropdown) {
        if (q.correctAnswers.isNotEmpty) {
          correct = userResp == q.correctAnswers.first;
        }
      } else if (q.type == QuestionType.shortAnswer ||
          q.type == QuestionType.paragraph) {
        if (q.correctAnswers.isNotEmpty) {
          final normUser = normalizeAnswerForComparison(userResp);
          final normCorrect = normalizeAnswerForComparison(
            q.correctAnswers.first,
          );
          correct = normUser == normCorrect;
        }
      }

      if (correct) {
        score += q.points;
      }

      if (existing != null) {
        // If the answer was force-marked incorrect due to a policy violation,
        // respect that and do not allow recomputing it as correct. Also
        // consult the independent flagged set to ensure flagging survives
        // intermediate overwrites.
        final isForced =
            existing.forceIncorrect || _flaggedQuestionIds.contains(qid);
        if (isForced) {
          answersList.add(
            existing.copyWith(isCorrect: false, forceIncorrect: true),
          );
        } else {
          answersList.add(existing.copyWith(isCorrect: correct));
        }
        // debug: log final answer entry for this question
        // ignore: avoid_print
        print(
          '[TakeQuizPage] _submitAttempt using existing for qid=$qid entry=${answersList.last} forceIncorrect=$isForced correctComputed=$correct',
        );
      } else {
        final wasFlagged = _flaggedQuestionIds.contains(qid);
        answersList.add(
          AttemptAnswerModel(
            questionId: qid,
            selectedChoiceId: userResp,
            timeTakenSeconds: 0,
            answeredAt: null,
            isCorrect: wasFlagged ? false : correct,
            forceIncorrect: wasFlagged,
          ),
        );
      }
    }

    final attempt = AttemptModel(
      id: _attemptId!,
      quizId: widget.quizId,
      userId: Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser!.uid,
      startedAt: _attemptStartedAt ?? DateTime.now(),
      submittedAt: DateTime.now(),
      score: score,
      totalPoints: _questions.fold<int>(0, (s, q) => s + q.points),
      answers: answersList,
      totalViolations: _antiCheat.getViolationCount(),
    );

    await _firestore.submitAttempt(_attemptId!, attempt);
    _antiCheat.stopAntiCheat();

    // Disable screenshot protection after attempt submission.
    try {
      await ScreenProtector.setSecure(false);
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submitted'),
          content: Text('Score: ${attempt.score}/${attempt.totalPoints}'),
          actions: [
            TextButton(
              onPressed: () {
                if (!mounted) return;
                Navigator.of(context).popUntil((r) => r.isFirst);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newSize = MediaQuery.of(context).size;
      if (_attemptId != null &&
          (_reportedScreenSize == null || _reportedScreenSize != newSize)) {
        _reportedScreenSize = newSize;
        _antiCheat.onScreenSizeChanged(newSize);
      }
    });

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color.fromARGB(255, 207, 207, 207),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromARGB(255, 169, 169, 169), Color.fromARGB(255, 255, 255, 255)],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: const Color.fromARGB(255, 240, 240, 240),
              child: AppBar(
                scrolledUnderElevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: Text(_quizTitle ?? 'Quiz Guard', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                actions: kDebugMode
                    ? [
                        IconButton(
                          icon: const Icon(Icons.bug_report, color: Colors.black),
                          onPressed: _showDebugInfoDialog,
                          tooltip: 'Debug state',
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    if (_remainingSeconds != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Time left: ${_formatRemaining(_remainingSeconds!)}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if ((_usageAccessGranted ?? false) == false ||
                        (_accessibilityServiceEnabled ?? false) == false)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: _buildMonitoringBanner(),
                      ),
                    Expanded(
                      child: _questions.isEmpty
                          ? const SizedBox.shrink()
                          : Builder(
                              builder: (context) {
                                final q = _questions[_currentQuestionIndex];
                                final started = _attemptId != null;
                                return Stack(
                                  children: [
                                    // The interactive content; blocked by IgnorePointer when not started
                                    IgnorePointer(
                                      ignoring: !started,
                                      child: Opacity(
                                        opacity: started ? 1.0 : 0.95,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              const BoxShadow(
                                                color: Colors.white,
                                                offset: Offset(-4, -4),
                                                blurRadius: 10,
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                offset: const Offset(4, 4),
                                                blurRadius: 10,
                                              ),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF7F8C8D),
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  q.prompt,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF222222),
                                                    fontSize: 18,
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                if (q.type ==
                                                        QuestionType
                                                            .multipleChoice ||
                                                    q.type ==
                                                        QuestionType.dropdown)
                                                  Expanded(
                                                    child: SingleChildScrollView(
                                                      child: Column(
                                                        children: q.choices.map((c) {
                                                          final selected =
                                                              _answers[q.id] == c.id;
                                                          final locked =
                                                              _lockedQuestionIds
                                                                  .contains(q.id);
                                                          return Container(
                                                            margin: const EdgeInsets.only(bottom: 12),
                                                            decoration: BoxDecoration(
                                                              color: selected ? const Color(0xFF222222).withValues(alpha: 0.05) : Colors.white,
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(color: selected ? const Color(0xFF222222) : Colors.transparent),
                                                            ),
                                                            child: ListTile(
                                                              title: Text(c.text, style: TextStyle(color: locked ? Colors.grey : const Color(0xFF222222), fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                                                              leading: Icon(
                                                                selected
                                                                    ? Icons
                                                                          .radio_button_checked
                                                                    : Icons
                                                                          .radio_button_unchecked,
                                                                color: locked ? Colors.grey : (selected ? const Color(0xFF222222) : const Color(0xFF7F8C8D)),
                                                              ),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                              onTap: locked
                                                                  ? null
                                                                  : () =>
                                                                        _answerSingle(
                                                                          q.id,
                                                                          c.id,
                                                                        ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                if (q.type ==
                                                    QuestionType.checkbox)
                                                  Expanded(
                                                    child: SingleChildScrollView(
                                                      child: Column(
                                                        children: q.choices.map((c) {
                                                          final locked =
                                                              _lockedQuestionIds
                                                                  .contains(q.id);
                                                          final isSelected = (_multiAnswers[q.id] ?? []).contains(c.id);
                                                          return Container(
                                                            margin: const EdgeInsets.only(bottom: 12),
                                                            decoration: BoxDecoration(
                                                              color: isSelected ? const Color(0xFF222222).withValues(alpha: 0.05) : Colors.white,
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(color: isSelected ? const Color(0xFF222222) : Colors.transparent),
                                                            ),
                                                            child: CheckboxListTile(
                                                              title: Text(c.text, style: TextStyle(color: locked ? Colors.grey : const Color(0xFF222222), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                                              value: isSelected,
                                                              activeColor: const Color(0xFF222222),
                                                              checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                              onChanged: locked
                                                                  ? null
                                                                  : (v) =>
                                                                        _answerCheckbox(
                                                                          q.id,
                                                                          c.id,
                                                                          v ?? false,
                                                                        ),
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                  ),
                                                if (q.type ==
                                                        QuestionType
                                                            .shortAnswer ||
                                                    q.type ==
                                                        QuestionType.paragraph)
                                                  TextField(
                                                    controller: _textController,
                                                    onChanged: (v) =>
                                                        _answerText(q.id, v),
                                                    readOnly: _lockedQuestionIds
                                                        .contains(q.id),
                                                    keyboardType:
                                                        TextInputType.multiline,
                                                    textInputAction:
                                                        TextInputAction.newline,
                                                    minLines:
                                                        q.type ==
                                                            QuestionType.paragraph
                                                        ? 3
                                                        : 1,
                                                    maxLines:
                                                        q.type ==
                                                            QuestionType.paragraph
                                                        ? null
                                                        : 1,
                                                    style: const TextStyle(color: Color(0xFF222222)),
                                                    decoration: InputDecoration(
                                                      hintText: 'Type your answer here...',
                                                      hintStyle: const TextStyle(color: Color(0xFF7F8C8D)),
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                      enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: BorderSide.none,
                                                      ),
                                                      focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                        borderSide: const BorderSide(color: Color(0xFF222222), width: 1.5),
                                                      ),
                                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                      suffix:
                                                          _lockedQuestionIds
                                                              .contains(q.id)
                                                          ? const Text('Flagged', style: TextStyle(color: Colors.red))
                                                          : null,
                                                    ),
                                                  ),
                                                const Spacer(),
                                                const SizedBox(height: 12),
                                                if (q.type ==
                                                        QuestionType.checkbox ||
                                                    q.type ==
                                                        QuestionType
                                                            .shortAnswer ||
                                                    q.type ==
                                                        QuestionType.paragraph)
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.end,
                                                    children: [
                                                      ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: const Color(0xFF222222),
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          elevation: 5,
                                                          shadowColor: Colors.black.withValues(alpha: 0.3),
                                                        ),
                                                        onPressed: () {
                                                          final ok =
                                                              (q.type ==
                                                                      QuestionType
                                                                          .checkbox &&
                                                                  (_multiAnswers[q
                                                                              .id] ??
                                                                          [])
                                                                      .isNotEmpty) ||
                                                              ((q.type ==
                                                                          QuestionType
                                                                              .shortAnswer ||
                                                                      q.type ==
                                                                          QuestionType
                                                                              .paragraph) &&
                                                                  (_answers[q.id] ??
                                                                          '')
                                                                      .trim()
                                                                      .isNotEmpty);
                                                          if (ok) {
                                                            _recordCurrentAnswerIfNeeded();
                                                            _nextQuestion();
                                                          }
                                                        },
                                                        child: Text(
                                                          _currentQuestionIndex +
                                                                      1 <
                                                                  _questions
                                                                      .length
                                                              ? 'Next'
                                                              : 'Submit',
                                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Overlay when not started: blurred and with centered Start button
                                    if (!started)
                                      Positioned.fill(
                                        child: ClipRect(
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 4.0,
                                              sigmaY: 4.0,
                                            ),
                                            child: Container(
                                              color: const Color.fromRGBO(
                                                0,
                                                0,
                                                0,
                                                0.25,
                                              ),
                                              alignment: Alignment.center,
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF222222),
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 32,
                                                        vertical: 16,
                                                      ),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  elevation: 10,
                                                ),
                                                onPressed: _confirmStartAttempt,
                                                child: const Text(
                                                  'Start Attempt',
                                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
