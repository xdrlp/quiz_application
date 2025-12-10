import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/violation_model.dart';
import 'package:quiz_application/models/user_model.dart';
import 'package:quiz_application/utils/answer_utils.dart';

// Interactive Quiz Analysis screen with attempt viewer (recalc/save/toggle/edit-time).
class QuizAnalysisScreen extends StatefulWidget {
  final String quizId;
  final String initialTab;
  const QuizAnalysisScreen({super.key, required this.quizId, this.initialTab = 'summary'});

  @override
  State<QuizAnalysisScreen> createState() => _QuizAnalysisScreenState();
}

class _QuizAnalysisScreenState extends State<QuizAnalysisScreen> with TickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  QuizModel? _quiz;
  List<QuestionModel> _questions = [];
  List<AttemptModel> _attempts = [];
  Map<String, UserModel> _users = {};
  Map<String, List<ViolationModel>> _violationsByAttempt = {};

  late TabController _tabController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: _initialIndex());
    _loadAll();
  }

  int _initialIndex() {
    switch (widget.initialTab) {
      case 'insights':
        return 1;
      case 'individual':
        return 2;
      default:
        return 0;
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final quiz = await _fs.getQuiz(widget.quizId);
      final qs = await _fs.getQuizQuestions(widget.quizId);
      final attempts = await _fs.getAttemptsByQuiz(widget.quizId);

      final usersMap = <String, UserModel>{};
      final violations = <String, List<ViolationModel>>{};

      for (var a in attempts) {
        if (!usersMap.containsKey(a.userId)) {
          final u = await _fs.getUser(a.userId);
          if (u != null) usersMap[a.userId] = u;
        }
        violations[a.id] = await _fs.getViolationsByAttempt(a.id);
      }

      setState(() {
        _quiz = quiz;
        _questions = qs;
        _attempts = attempts;
        _users = usersMap;
        _violationsByAttempt = violations;
      });
    } catch (_) {
      // ignore; show whatever we have
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?.title ?? 'Quiz analysis'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Summary'), Tab(text: 'Insights'), Tab(text: 'Individual')]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabController, children: [_buildSummary(), _buildInsights(), _buildIndividual()]),
    );
  }

  // Summary: overall counts and a simple percentage-binned bar chart
  Widget _buildSummary() {
    final attemptCount = _attempts.length;
    final submittedCount = _attempts.where((a) => a.submittedAt != null).length;
    final avgScore = _attempts.isEmpty ? 0.0 : _attempts.map((a) => a.score).reduce((v, e) => v + e) / (_attempts.length);
    final highest = _attempts.isEmpty ? 0 : _attempts.map((a) => a.score).reduce((v, e) => v > e ? v : e);
    final lowest = _attempts.isEmpty ? 0 : _attempts.map((a) => a.score).reduce((v, e) => v < e ? v : e);
    final avgTimeSeconds = _attempts.isEmpty
      ? 0
      : (_attempts.map((a) => a.answers.fold<int>(0, (p, ans) => p + ans.timeTakenSeconds)).reduce((v, e) => v + e) ~/ _attempts.length);
    final avgTimeFormatted = Duration(seconds: avgTimeSeconds);
    final completionRate = attemptCount == 0 ? 0.0 : (submittedCount / attemptCount) * 100.0;
    final totalViolations = _attempts.fold<int>(0, (p, a) => p + a.totalViolations);
    final bins = [for (var i = 0; i <= 10; i++) i * 10];
    final dist = Map<int, int>.fromEntries(bins.map((b) => MapEntry(b, 0)));
    for (var a in _attempts) {
      final pct = a.totalPoints == 0 ? 0 : ((a.score / a.totalPoints) * 100).round();
      final bucket = pct == 100 ? 100 : (pct ~/ 10) * 10;
      dist[bucket] = (dist[bucket] ?? 0) + 1;
    }

    // Dashboard tiles
    final maxPoints = _attempts.isEmpty ? 0 : _attempts.first.totalPoints;
    Widget buildTile({required IconData icon, required String title, required List<Widget> children, Color? accent}) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                decoration: BoxDecoration(color: (accent ?? Theme.of(context).colorScheme.primary).withAlpha(20), borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: accent ?? Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            ...children,
          ]),
        ),
      );
    }

    // Participation tile
    final participationTile = buildTile(
      icon: Icons.group_outlined,
      title: 'Participation',
      accent: Colors.blue,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Attempts', style: TextStyle(color: Color(0xFF6B7280))), Text('$attemptCount', style: const TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Submitted', style: TextStyle(color: Color(0xFF6B7280))), Text('$submittedCount', style: const TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 12),
        Text('Completion rate', style: TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: completionRate / 100.0, minHeight: 10, color: Colors.blue, backgroundColor: Colors.grey.shade200))),
          const SizedBox(width: 12),
          Text('${completionRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ],
    );

    // Performance tile
    Color perfColor() {
      if (avgScore > 4) return Colors.green;
      if (avgScore >= 2) return Colors.orange;
      return Colors.red;
    }
    final performanceTile = buildTile(
      icon: Icons.bar_chart, title: 'Performance', accent: Colors.green, children: [
        // Compact flow: label, then a single row with score on the left and a progress bar to the right.
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Average score', style: TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Score value
            Text('${avgScore.toStringAsFixed(1)}/$maxPoints', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
            const SizedBox(width: 12),
            // Progress bar next to score
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (maxPoints == 0) ? 0.0 : (avgScore / maxPoints).clamp(0.0, 1.0),
                  minHeight: 12,
                  color: perfColor(),
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 44, child: Text('${((maxPoints == 0) ? 0 : ((avgScore / maxPoints) * 100)).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 12),
          // Small stats row: Highest and Lowest side-by-side
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Highest', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)), const SizedBox(height: 4), Text('$highest', style: const TextStyle(fontWeight: FontWeight.w600))]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Lowest', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)), const SizedBox(height: 4), Text('$lowest', style: const TextStyle(fontWeight: FontWeight.w600))]),
          ])
        ])
      ],
    );

    // Behavior & Time tile
    final behaviorTile = buildTile(
      icon: Icons.schedule, title: 'Behavior & Time', accent: Colors.orange, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Average time', style: TextStyle(color: Color(0xFF6B7280))), Text('${avgTimeFormatted.inMinutes}:${(avgTimeFormatted.inSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w600))]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total violations', style: TextStyle(color: Color(0xFF6B7280))), Row(children: [totalViolations == 0 ? Icon(Icons.check_circle, color: Colors.green, size: 18) : const SizedBox(width: 18), const SizedBox(width: 8), Text('$totalViolations', style: const TextStyle(fontWeight: FontWeight.w600))])]),
      ],
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          LayoutBuilder(builder: (context, constraints) {
          int cols = 1;
          if (constraints.maxWidth >= 1000) {
            cols = 3;
          } else if (constraints.maxWidth >= 650) {
            cols = 2;
          }
          return Wrap(spacing: 16, runSpacing: 16, children: [
            SizedBox(width: cols == 3 ? (constraints.maxWidth - 32) / 3 : (cols == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth), child: participationTile),
            SizedBox(width: cols == 3 ? (constraints.maxWidth - 32) / 3 : (cols == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth), child: performanceTile),
            SizedBox(width: cols == 3 ? (constraints.maxWidth - 32) / 3 : (cols == 2 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth), child: behaviorTile),
          ]);
        }),
        const SizedBox(height: 18),
        // Score distribution as a dashboard tile
        Builder(builder: (ctx) {
          final totalAttempts = _attempts.length;
          final scoreTile = buildTile(
            icon: Icons.insert_chart_outlined,
            title: 'Score distribution',
            accent: Theme.of(ctx).colorScheme.primary,
            children: [
              Center(child: Text('Total attempts: $totalAttempts', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.grey))),
              const SizedBox(height: 8),
                  LayoutBuilder(builder: (c, cc) {
                    final available = cc.maxHeight.isFinite ? cc.maxHeight : double.infinity;
                    final target = available.isFinite ? math.min(220.0, available) : 220.0;
                    return SizedBox(height: target.toDouble(), child: _buildVerticalScoreChart(dist));
                  }),
            ],
          );
          return scoreTile;
        }),
      ]),
      ),
    );
      }

      // Vertical score chart styled to resemble the attached image.
      Widget _buildVerticalScoreChart(Map<int, int> dist) {
        final bins = [for (var i = 0; i <= 10; i++) i * 10];
        final maxCount = dist.values.isEmpty ? 0 : dist.values.reduce((a, b) => a > b ? a : b);
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              // NOTE: the card already shows total attempts in its header; avoid duplicating here.
              // The following Row will expand to fill the available height provided by the parent
              // (caller wraps this widget in a SizedBox with a target height). Using Expanded
              // prevents hard-coded heights that caused RenderFlex overflows.
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left vertical label (grey) — nudged further right for visual alignment
                    SizedBox(
                      width: 20,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text('Attempts', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Y axis labels (top-to-bottom) - right-aligned
                    SizedBox(
                      width: 28,
                      child: Padding(
                        // add larger bottom padding so the '0' label sits on the x-axis line
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [for (var i = maxCount; i >= 0; i--) Align(alignment: Alignment.centerRight, child: Text('$i', style: Theme.of(context).textTheme.bodySmall))],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chart area
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        final plotWidth = constraints.maxWidth;
                        final plotHeight = (constraints.maxHeight - 40).clamp(0.0, double.infinity); // reserve for x-axis labels
                        final spacing = bins.length <= 1 ? plotWidth : plotWidth / (bins.length - 1);
                        return Stack(
                          children: [
                            // horizontal grid lines (evenly spaced based on maxCount)
                            for (var i = 0; i <= maxCount; i++)
                              Positioned(
                                top: ((maxCount - i) / (maxCount == 0 ? 1 : maxCount)) * (plotHeight - 4),
                                left: 0,
                                right: 0,
                                child: Container(height: 1, color: Colors.grey.shade200),
                              ),

                            // bars for each bin (0..100 step 10)
                                for (var idx = 0; idx < bins.length; idx++)
                                  Builder(builder: (ctx) {
                                    final bin = bins[idx];
                                    final cnt = dist[bin] ?? 0;
                                    final barHeight = maxCount == 0 ? 0.0 : (cnt / maxCount) * (plotHeight - 8);
                                    final x = idx * spacing;
                                    // make bars thicker by increasing width fraction
                                    final thickBarWidth = spacing * 0.6;
                                    return Positioned(
                                      bottom: 40,
                                      left: (x - (thickBarWidth / 2)).clamp(0.0, plotWidth - thickBarWidth),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: thickBarWidth,
                                            height: barHeight,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.primary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                      ),
                                    );
                                  }),

                            // x-axis labels under the chart (percent)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: SizedBox(
                                height: 40,
                                child: Row(
                                  children: [for (var idx = 0; idx < bins.length; idx++) Expanded(child: Center(child: Text('${bins[idx]}%', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black))))],
                                ),
                              ),
                            ),

                            // axis lines and tick marks
                            // vertical y-axis line
                            Positioned(left: 0, bottom: 40, top: 0, child: Container(width: 1.2, color: Colors.grey.shade300)),
                            // horizontal x-axis line
                            Positioned(left: 0, right: 0, bottom: 40, child: Container(height: 1.2, color: Colors.grey.shade300)),
                            // x-axis tick marks
                            for (var idx = 0; idx < bins.length; idx++)
                              Positioned(bottom: 40 - 6, left: (idx * spacing - 1).clamp(0.0, plotWidth - 2), child: Container(width: 2, height: 6, color: Colors.grey.shade400)),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Score (%)', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        );
      }

  // Insights: per-question correctness %
  Widget _buildInsights() {
    if (_attempts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No insights yet')));

    // Per-question stats
    final qStats = <String, Map<String, dynamic>>{}; // qid -> {correct, total, avgTimeSeconds, violations}
    for (var q in _questions) {
      qStats[q.id] = {'correct': 0, 'total': 0, 'timeSum': 0, 'violations': 0};
    }

    // map violations to questions by timestamp proximity when possible
    final Map<String, List<ViolationModel>> violationsByAttempt = {};
    for (var a in _attempts) {
      violationsByAttempt[a.id] = _violationsByAttempt[a.id] ?? [];
    }

    for (var a in _attempts) {
      final attemptViolations = violationsByAttempt[a.id] ?? [];
      for (var ans in a.answers) {
        final st = qStats[ans.questionId];
        if (st == null) continue;
        st['total'] = (st['total'] as int) + 1;
        st['timeSum'] = (st['timeSum'] as int) + (ans.timeTakenSeconds);
        if (ans.isCorrect) st['correct'] = (st['correct'] as int) + 1;

        // assign violations that occurred within +/-15s of this answer's answeredAt
        if (ans.answeredAt != null) {
          for (var v in attemptViolations) {
            final dt = v.detectedAt;
            if (dt.isAfter(ans.answeredAt!.subtract(const Duration(seconds: 15))) && dt.isBefore(ans.answeredAt!.add(const Duration(seconds: 15)))) {
              st['violations'] = (st['violations'] as int) + 1;
            }
          }
        }
      }
    }

    // identify easy/difficult items
    final perQuestionRates = <String, double>{};
    for (var q in _questions) {
      final st = qStats[q.id]!;
      final total = st['total'] as int;
      final correct = st['correct'] as int;
      perQuestionRates[q.id] = total == 0 ? 0.0 : (correct / total) * 100.0;
    }
    final sortedByEasy = List<String>.from(perQuestionRates.keys)..sort((a, b) => (perQuestionRates[b] ?? 0.0).compareTo(perQuestionRates[a] ?? 0.0));
    final sortedByHard = List<String>.from(perQuestionRates.keys)..sort((a, b) => (perQuestionRates[a] ?? 0.0).compareTo(perQuestionRates[b] ?? 0.0));

    // items with high violation rates
    final violationRates = <String, double>{};
    for (var q in _questions) {
      final st = qStats[q.id]!;
      final viol = st['violations'] as int;
      final total = st['total'] as int;
      violationRates[q.id] = total == 0 ? 0.0 : (viol / total) * 100.0;
    }
    final highViolation = violationRates.keys.toList()..sort((a, b) => (violationRates[b] ?? 0.0).compareTo(violationRates[a] ?? 0.0));

    // relationship between violations and performance
    final attemptsWithViol = _attempts.where((a) => (violationsByAttempt[a.id] ?? []).isNotEmpty).toList();
    final attemptsWithoutViol = _attempts.where((a) => (violationsByAttempt[a.id] ?? []).isEmpty).toList();
    final avgWithViol = attemptsWithViol.isEmpty ? 0.0 : attemptsWithViol.map((a) => a.score).reduce((v, e) => v + e) / attemptsWithViol.length;
    final avgWithoutViol = attemptsWithoutViol.isEmpty ? 0.0 : attemptsWithoutViol.map((a) => a.score).reduce((v, e) => v + e) / attemptsWithoutViol.length;

    // time-based patterns: median split on avg time per answer
    final attemptsWithAvgTime = _attempts.map((a) {
      final totalTime = a.answers.fold<int>(0, (p, ans) => p + ans.timeTakenSeconds);
      final avg = a.answers.isEmpty ? 0.0 : totalTime / a.answers.length;
      return {'attempt': a, 'avg': avg};
    }).toList();
    attemptsWithAvgTime.sort((x, y) => (x['avg'] as double).compareTo(y['avg'] as double));
    final medianIdx = (attemptsWithAvgTime.length / 2).floor();
    final fast = attemptsWithAvgTime.take(medianIdx).map((e) => e['attempt'] as AttemptModel).toList();
    final slow = attemptsWithAvgTime.skip(medianIdx).map((e) => e['attempt'] as AttemptModel).toList();
    final avgFastScore = fast.isEmpty ? 0.0 : fast.map((a) => a.score).reduce((v, e) => v + e) / fast.length;
    final avgSlowScore = slow.isEmpty ? 0.0 : slow.map((a) => a.score).reduce((v, e) => v + e) / slow.length;

    // identify students with unusual patterns (many violations or appSwitch events)
    final userViolCounts = <String, int>{};
    final userAppSwitch = <String, int>{};
    for (var a in _attempts) {
      for (var v in violationsByAttempt[a.id] ?? []) {
        userViolCounts[v.userId] = (userViolCounts[v.userId] ?? 0) + 1;
        if (v.type == ViolationType.appSwitch) userAppSwitch[v.userId] = (userAppSwitch[v.userId] ?? 0) + 1;
      }
    }
    final flaggedUsers = userViolCounts.entries.where((e) => e.value >= 3).map((e) => e.key).toList();
    final frequentAppSwitchers = userAppSwitch.entries.where((e) => e.value >= 2).map((e) => e.key).toList();

    // overall impact
    final percentFlagged = _attempts.isEmpty ? 0.0 : (attemptsWithViol.length / _attempts.length) * 100.0;

    return ListView(padding: const EdgeInsets.all(12), children: [
      // Top cards: Student Flags & Quiz Integrity Overview
      LayoutBuilder(builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 800 ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;
        Color impactColor(double pct) {
          if (pct < 10) return Colors.green;
          if (pct <= 25) return Colors.orange;
          return Colors.red;
        }

        final uniqueFlagged = <String>{}..addAll(flaggedUsers)..addAll(frequentAppSwitchers);

        Widget studentFlagsCard = Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.flag, color: Colors.redAccent), const SizedBox(width: 8), Text('Student Flags', style: Theme.of(context).textTheme.titleMedium)]),
              const SizedBox(height: 12),
              if (uniqueFlagged.isEmpty) const Text('No flagged students'),
              for (var uid in uniqueFlagged.take(5))
                Builder(builder: (ctx) {
                  final name = _users[uid]?.displayName ?? uid;
                  final violCount = userViolCounts[uid] ?? 0;
                  final appSwitchCount = userAppSwitch[uid] ?? 0;
                  final initials = name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(children: [
                      CircleAvatar(backgroundColor: Colors.grey.shade200, child: Text(initials.isEmpty ? '?' : initials.substring(0, initials.length > 2 ? 2 : initials.length))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Row(children: [
                        if (violCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Text('$violCount violations', style: TextStyle(color: Colors.red, fontSize: 12))),
                        if (violCount > 0) const SizedBox(width: 8),
                        if (appSwitchCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withAlpha(30), borderRadius: BorderRadius.circular(12)), child: Text('$appSwitchCount app-switches', style: TextStyle(color: Colors.orange, fontSize: 12))),
                      ])])),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { /* open details */ }),
                    ]),
                  );
                }),
            ]),
          ),
        );

        Widget integrityCard = Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(Icons.shield_outlined, color: impactColor(percentFlagged)), const SizedBox(width: 8), Text('Quiz Integrity Overview', style: Theme.of(context).textTheme.titleMedium)]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${percentFlagged.toStringAsFixed(1)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: impactColor(percentFlagged))), const SizedBox(height: 6), Text('${attemptsWithViol.length} out of ${_attempts.length} attempts', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey))])),
                const SizedBox(width: 12),
                SizedBox(width: 84, height: 84, child: Stack(alignment: Alignment.center, children: [CircularProgressIndicator(value: (percentFlagged / 100.0).clamp(0.0, 1.0), color: impactColor(percentFlagged), backgroundColor: Colors.grey.shade200, strokeWidth: 8), Text('${percentFlagged.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w700))])),
              ]),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: (percentFlagged / 100.0).clamp(0.0, 1.0), color: impactColor(percentFlagged), backgroundColor: Colors.grey.shade200, minHeight: 10),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Severity', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)), Text(percentFlagged > 25 ? 'High' : (percentFlagged >= 10 ? 'Medium' : 'Low'), style: TextStyle(color: impactColor(percentFlagged)))]),
            ]),
          ),
        );

        if (constraints.maxWidth >= 800) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: cardWidth, child: studentFlagsCard), const SizedBox(width: 16), SizedBox(width: cardWidth, child: integrityCard)]);
        }
        return Column(children: [studentFlagsCard, const SizedBox(height: 12), integrityCard]);
      }),
      const SizedBox(height: 12),
      // Easy items with clearer labels and badges
      ListTile(
        title: const Text('Most correctly answered', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedByEasy.take(5).map((id) {
            final q = _questions.firstWhere((x) => x.id == id);
            final st = qStats[id]!;
            final correct = st['correct'] as int;
            final total = st['total'] as int;
            final pctDouble = perQuestionRates[id] ?? 0.0;
            final badgeColor = pctDouble >= 80
                ? Colors.green
                : (pctDouble <= 40 ? Colors.red : Theme.of(context).colorScheme.primary);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(children: [
                Expanded(child: Text(q.prompt, maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: badgeColor.withAlpha((0.12 * 255).round()), borderRadius: BorderRadius.circular(14)),
                  child: Text('$correct/$total', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: badgeColor, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
      const Divider(),
      // Difficult items
      ListTile(
        title: const Text('Least correctly answered', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: sortedByHard.take(5).map((id) {
            final q = _questions.firstWhere((x) => x.id == id);
            final st = qStats[id]!;
            final correct = st['correct'] as int;
            final total = st['total'] as int;
            final pctDouble = perQuestionRates[id] ?? 0.0;
            final badgeColor = pctDouble >= 80
                ? Colors.green
                : (pctDouble <= 40 ? Colors.red : Theme.of(context).colorScheme.primary);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(children: [
                Expanded(child: Text(q.prompt, maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: badgeColor.withAlpha((0.12 * 255).round()), borderRadius: BorderRadius.circular(14)),
                  child: Text('$correct/$total', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: badgeColor, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
      const Divider(),
      // High violation items with counts
      ListTile(
        title: const Text('High violation items', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: highViolation.take(5).map((id) {
            final q = _questions.firstWhere((x) => x.id == id);
            final st = qStats[id]!;
            final viol = st['violations'] as int;
            final total = st['total'] as int;
            final violPct = violationRates[id] ?? 0.0;
            final badgeColor = violPct >= 50 ? Colors.orange : Theme.of(context).colorScheme.primary;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(children: [
                Expanded(child: Text(q.prompt, maxLines: 2, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: badgeColor.withAlpha((0.12 * 255).round()), borderRadius: BorderRadius.circular(14)),
                  child: Text('$viol/$total', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: badgeColor, fontWeight: FontWeight.w600)),
                ),
              ]),
            );
          }).toList(),
        ),
      ),
      const Divider(),
      // Visual: Violations vs performance & Time-based patterns
      Builder(builder: (context) {
        // helper to render a labeled progress bar with trailing value
        Widget scoreRow(String label, double value, double maxVal, Color color) {
          final pct = (maxVal <= 0) ? 0.0 : (value / maxVal).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(children: [
              SizedBox(width: 150, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pct,
                      color: color,
                      backgroundColor: Colors.grey.shade200,
                      minHeight: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: Text(value.toStringAsFixed(1), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall)),
            ]),
          );
        }

        final maxScore = [avgWithViol, avgWithoutViol, avgFastScore, avgSlowScore].fold<double>(0.0, (p, e) => e > p ? e : p);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Violations vs performance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          scoreRow('With violations', avgWithViol, maxScore == 0 ? 1.0 : maxScore, Colors.orange),
          scoreRow('Without violations', avgWithoutViol, maxScore == 0 ? 1.0 : maxScore, Colors.green),
          const SizedBox(height: 12),
          Text('Time-based patterns', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          scoreRow('Fast group (avg)', avgFastScore, maxScore == 0 ? 1.0 : maxScore, Colors.blue),
          scoreRow('Slow group (avg)', avgSlowScore, maxScore == 0 ? 1.0 : maxScore, Colors.purple),
        ]);
      }),
      const Divider(),
      ListTile(title: const Text('Flagged students (>=3 violations)'), subtitle: Text(flaggedUsers.isEmpty ? 'None' : flaggedUsers.map((u) => _users[u]?.displayName ?? u).join(', '))),
      ListTile(title: const Text('Frequent app-switchers'), subtitle: Text(frequentAppSwitchers.isEmpty ? 'None' : frequentAppSwitchers.map((u) => _users[u]?.displayName ?? u).join(', '))),
      const Divider(),
      ListTile(title: const Text('Overall impact of anti-cheating'), subtitle: Text('${percentFlagged.toStringAsFixed(1)}% of attempts had at least one violation.')),
      const SizedBox(height: 12),
      const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
      const Text('These insights are automated heuristics. Review flagged attempts and context before taking action.'),
    ]);
  }

  // Individual attempts list
  Widget _buildIndividual() {
    if (_attempts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No attempts')));

    return ListView.builder(
      itemCount: _attempts.length,
      itemBuilder: (context, i) {
        final a = _attempts[i];
        final user = _users[a.userId];
        final violations = _violationsByAttempt[a.id] ?? [];
        return Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            title: Text(user?.displayName ?? a.userId),
            subtitle: Text('Score: ${a.score}/${a.totalPoints} — Violations: ${violations.length}'),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
                onPressed: () async {
                // show interactive attempt viewer
                await showDialog(
                  context: context,
                  builder: (_) => _AttemptDetailViewer(
                    attempt: a,
                    questions: _questions,
                    violations: violations,
                    user: user,
                  ),
                );
                // reload after dialog (in case of save)
                if (!mounted) return;
                await _loadAll();
              },
            ),
          ),
        );
      },
    );
  }
}

// Stateful attempt detail viewer with recalc/save/toggle/edit-time.
class _AttemptDetailViewer extends StatefulWidget {
  final AttemptModel attempt;
  final List<QuestionModel> questions;
  final List<ViolationModel> violations;
  final UserModel? user;
  const _AttemptDetailViewer({required this.attempt, required this.questions, required this.violations, this.user});

  @override
  State<_AttemptDetailViewer> createState() => _AttemptDetailViewerState();
}

class _AttemptDetailViewerState extends State<_AttemptDetailViewer> {
  late AttemptModel _attempt;
  final FirestoreService _fs = FirestoreService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _attempt = widget.attempt;
  }

  QuestionModel? _findQuestion(String qid) {
    try {
      return widget.questions.firstWhere((q) => q.id == qid);
    } catch (_) {
      return null;
    }
  }

  void _toggleCorrect(int index) {
    setState(() {
      final a = _attempt.answers[index];
      final updated = a.copyWith(isCorrect: !a.isCorrect);
      final newAnswers = List.of(_attempt.answers);
      newAnswers[index] = updated;
      _attempt = _attempt.copyWith(answers: newAnswers);
    });
  }

  

  void _recalculate() {
    final newAnswers = <AttemptAnswerModel>[];
    for (var a in _attempt.answers) {
      QuestionModel? q;
      try {
        q = widget.questions.firstWhere((x) => x.id == a.questionId);
      } catch (_) {
        q = null;
      }
      if (q == null) {
        newAnswers.add(a);
        continue;
      }
      bool correct = a.isCorrect;
      if (q.type == QuestionType.multipleChoice || q.type == QuestionType.dropdown) {
        correct = q.correctAnswers.contains(a.selectedChoiceId);
      } else if (q.type == QuestionType.shortAnswer) {
        final normUser = normalizeAnswerForComparison(a.selectedChoiceId);
        final normCorrect = q.correctAnswers.isNotEmpty ? normalizeAnswerForComparison(q.correctAnswers.first) : '';
        correct = normUser == normCorrect;
      }
      newAnswers.add(a.copyWith(isCorrect: correct));
    }
    setState(() {
      _attempt = _attempt.copyWith(answers: newAnswers);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      await _fs.submitAttempt(_attempt.id, _attempt);
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Attempt by ${widget.user?.displayName ?? _attempt.userId}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [ElevatedButton.icon(onPressed: _recalculate, icon: const Icon(Icons.refresh), label: const Text('Recalculate')), const SizedBox(width: 8), ElevatedButton.icon(onPressed: _saving ? null : _saveChanges, icon: const Icon(Icons.save), label: _saving ? const Text('Saving...') : const Text('Save'))]),
            const SizedBox(height: 12),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: ListView.builder(
                itemCount: _attempt.answers.length + 1,
                itemBuilder: (context, i) {
                  if (i == _attempt.answers.length) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 12),
                      const Text('Violations', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (widget.violations.isEmpty) ListTile(leading: const Icon(Icons.check_circle_outline, color: Colors.green), title: const Text('No violations detected'), subtitle: const Text('This respondent had 0 anti-cheating flags.')) else for (var v in widget.violations) ListTile(title: Text(v.type.toString()), subtitle: Text(v.details ?? ''))
                    ]);
                  }

                  final ans = _attempt.answers[i];
                  final q = _findQuestion(ans.questionId);
                  final rawResp = ans.selectedChoiceId;
                  final time = ans.timeTakenSeconds;
                  final answeredAt = ans.answeredAt;

                  // Format response: map choice IDs to choice text when possible.
                  String formatResponse(String raw, QuestionModel? qmodel) {
                    if (qmodel == null) return raw.isEmpty ? 'No response' : raw;
                    if (qmodel.choices.isEmpty) return raw.isEmpty ? 'No response' : raw;
                    // support comma-separated ids for checkbox answers
                    final parts = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                    if (parts.isEmpty) return 'No response';
                    final mapped = parts.map((id) {
                      try {
                        final c = qmodel.choices.firstWhere((ch) => ch.id == id);
                        return c.text;
                      } catch (_) {
                        return id; // fallback
                      }
                    }).toList();
                    return mapped.join(', ');
                  }

                  String formatAnsweredAt(DateTime dt) {
                    final local = dt.toLocal();
                    final day = local.day.toString().padLeft(2, '0');
                    final month = local.month.toString().padLeft(2, '0');
                    final year = (local.year % 100).toString().padLeft(2, '0');
                    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
                    final minute = local.minute.toString().padLeft(2, '0');
                    final ampm = local.hour >= 12 ? 'PM' : 'AM';
                    return '$day/$month/$year ${hour12.toString().padLeft(2, '0')}:$minute $ampm';
                  }

                  final respLabel = formatResponse(rawResp, q);

                  return ListTile(
                    title: Text(q?.prompt ?? ans.questionId),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Response: $respLabel'),
                        Text('Time taken: ${time}s'),
                        if (answeredAt != null) Text('Answered at: ${formatAnsweredAt(answeredAt)}'),
                        Text('Status: ${ans.isCorrect ? 'Correct' : 'Incorrect'}'),
                      ],
                    ),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: Icon(ans.isCorrect ? Icons.check_circle : Icons.check_circle_outline, color: ans.isCorrect ? Colors.green : null), onPressed: () => _toggleCorrect(i)),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
