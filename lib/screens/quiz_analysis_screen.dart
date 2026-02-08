import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:quiz_application/services/firestore_service.dart';
// Local queuing removed intentionally; use FirestoreService directly.
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/violation_model.dart';
import 'package:quiz_application/models/user_model.dart';
import 'package:quiz_application/utils/answer_utils.dart';
import 'package:quiz_application/utils/snackbar_utils.dart';
class _GradientPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientPainter({
    required this.gradient,
    required this.radius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final RRect rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

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
    if (!mounted) return;
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

      if (mounted) {
        setState(() {
          _quiz = quiz;
          _questions = qs;
          _attempts = attempts;
          _users = usersMap;
          _violationsByAttempt = violations;
        });
      }
    } catch (e, st) {
      // ignore: avoid_print
      print('[QuizAnalysisScreen] _loadAll error: $e\n$st');
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color.fromARGB(255, 197, 197, 197),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 48), // Height for Title + TabBar
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromARGB(255, 179, 179, 179), Color.fromARGB(255, 255, 255, 255)],
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
                title: Text(_quiz?.title ?? 'Quiz Analysis', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF222222),
                  unselectedLabelColor: Color.fromARGB(255, 94, 94, 94),
                  indicatorColor: const Color(0xFF222222),
                  tabs: const [Tab(text: 'Summary'), Tab(text: 'Insights'), Tab(text: 'Individual')],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(controller: _tabController, children: [_loading ? _buildSkeletonSummary() : _buildSummary(), _loading ? _buildSkeletonInsights() : _buildInsights(), _loading ? _buildSkeletonIndividual() : _buildIndividual()]),
      ),
    );
  }

  // Skeleton loaders
  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: CustomPaint(
        painter: _GradientPainter(
          strokeWidth: 2,
          radius: 14,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.white],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header skeleton
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Content skeleton lines
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 200,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: List.generate(4, (_) => _buildSkeletonCard()),
      ),
    );
  }

  Widget _buildSkeletonInsights() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: List.generate(5, (_) => _buildSkeletonCard()),
      ),
    );
  }

  Widget _buildSkeletonIndividual() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      itemBuilder: (context, i) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: CustomPaint(
            painter: _GradientPainter(
              strokeWidth: 2,
              radius: 14,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.white],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 150,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: CustomPaint(
          painter: _GradientPainter(
            strokeWidth: 2,
            radius: 14,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.white],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: (accent ?? const Color(0xFF222222)).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Icon(icon, color: accent ?? const Color(0xFF222222), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF222222),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      );
    }


    // Participation tile
    final participationTile = buildTile(
      icon: Icons.group_outlined,
      title: 'Participation',
      accent: const Color(0xFF222222),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Attempts', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94))), Text('$attemptCount', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Submitted', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94))), Text('$submittedCount', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))]),
        const SizedBox(height: 12),
        const Text('Completion rate', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: completionRate > 80 ? Colors.green : (completionRate >= 50 ? Colors.orange : Colors.red), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completionRate / 100.0,
                  minHeight: 10,
                  color: completionRate > 80 ? Colors.green : (completionRate >= 50 ? Colors.orange : Colors.red),
                  backgroundColor: const Color.fromARGB(0, 221, 221, 221),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${completionRate.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222))),
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
      icon: Icons.bar_chart, title: 'Performance', accent: const Color(0xFF222222), children: [
        // Compact flow: label, then a single row with score on the left and a progress bar to the right.
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Average score', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94))),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // Score value
            Text('${avgScore.toStringAsFixed(1)}/$maxPoints', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
            const SizedBox(width: 12),
            // Progress bar next to score
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: perfColor(), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (maxPoints == 0) ? 0.0 : (avgScore / maxPoints).clamp(0.0, 1.0),
                    minHeight: 12,
                    color: perfColor(),
                    backgroundColor: const Color.fromARGB(0, 224, 224, 224),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 44, child: Text('${((maxPoints == 0) ? 0 : ((avgScore / maxPoints) * 100)).toStringAsFixed(0)}%', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))),
          ]),
          const SizedBox(height: 12),
          // Small stats row: Highest and Lowest side-by-side
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Highest', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 12)), const SizedBox(height: 4), Text('$highest', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))]),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Lowest', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 12)), const SizedBox(height: 4), Text('$lowest', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)))]),
          ])
        ])
      ],
    );

    // Behavior & Time tile
    final behaviorTile = buildTile(
      icon: Icons.schedule, title: 'Behavior & Time', accent: const Color(0xFF222222), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Average time', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94))), Text('${avgTimeFormatted.inMinutes}:${(avgTimeFormatted.inSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF222222)))]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total violations', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94))), Text('$totalViolations', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF222222)))]),
      ],
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Column(
          children: [
            participationTile,
            performanceTile,
            behaviorTile,
            const SizedBox(height: 18),
            // Score distribution as a dashboard tile
            Builder(
              builder: (ctx) {
                final totalAttempts = _attempts.length;
                final scoreTile = buildTile(
                  icon: Icons.insert_chart_outlined,
                  title: 'Score distribution',
                  accent: const Color(0xFF222222),
                  children: [
                    Center(child: Text('Total attempts: $totalAttempts', style: const TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 13))),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (c, cc) {
                        final available = cc.maxHeight.isFinite ? cc.maxHeight : double.infinity;
                        final target = available.isFinite ? math.min(220.0, available) : 220.0;
                        return SizedBox(height: target.toDouble(), child: _buildVerticalScoreChart(dist));
                      },
                    ),
                  ],
                );
                return scoreTile;
              },
            ),
          ],
        ),
      ),
    );
  }

      // Vertical score chart styled to resemble the attached image.
      Widget _buildVerticalScoreChart(Map<int, int> dist) {
        final bins = [for (var i = 0; i <= 10; i++) i * 10];
        final maxCount = dist.values.isEmpty ? 0 : dist.values.reduce((a, b) => a > b ? a : b);
        const int yTickCount = 5; // number of Y ticks/grid lines to show (including 0)
        
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
                    // Left vertical label (grey) — slightly above vertical center
                    SizedBox(
                      width: 14,
                      child: Align(
                        alignment: const Alignment(0.0, -0.05),
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text('Attempts', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Y axis labels (top-to-bottom) - right-aligned
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          Expanded(
                            child: Builder(builder: (ctx) {
                              // Produce up to `yTickCount` evenly spaced Y-axis ticks (including 0 and max)
                              final tickValues = <int>[];
                              if (maxCount == 0) {
                                tickValues.add(0);
                              } else {
                                for (var i = 0; i < yTickCount; i++) {
                                  final val = ((maxCount * i) / (yTickCount - 1)).round();
                                  tickValues.add(val);
                                }
                                // remove duplicates (can happen when maxCount < yTickCount)
                                final dedup = <int>[];
                                for (var v in tickValues) {
                                  if (dedup.isEmpty || dedup.last != v) dedup.add(v);
                                }
                                tickValues
                                  ..clear()
                                  ..addAll(dedup.reversed); // want descending order
                              }
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: tickValues.map((v) => Align(alignment: Alignment.centerRight, child: Text('$v', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700)))).toList(),
                              );
                            }),
                          ),
                          const SizedBox(height: 52),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Chart area
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, right: 8),
                        child: LayoutBuilder(builder: (context, constraints) {
                        final plotWidth = constraints.maxWidth;
                        // reserve vertical space for rotated labels
                        final plotHeight = (constraints.maxHeight - 52).clamp(0.0, double.infinity);
                        // keep modest left/right margins so axis labels remain legible while maximizing width
                        final double chartMarginLeft = math.min(12.0, plotWidth * 0.05);
                        final double chartMarginRight = math.min(12.0, plotWidth * 0.05);
                        final effectiveWidth = (plotWidth - chartMarginLeft - chartMarginRight).clamp(0.0, double.infinity);
                        final spacing = bins.length <= 1 ? effectiveWidth : (bins.length > 1 ? effectiveWidth / (bins.length - 1) : effectiveWidth);
                        // allow children (rotated labels) to overflow so 0%/100% remain visible
                        return Stack(clipBehavior: Clip.none,
                          children: [
                            // horizontal grid lines (evenly spaced based on yTickCount)
                            for (var gi = 0; gi < yTickCount; gi++)
                              Positioned(
                                top: ((gi) / (yTickCount - 1)) * (plotHeight - 4),
                                left: chartMarginLeft,
                                right: chartMarginRight,
                                child: Container(height: 1, color: Colors.grey.shade600),
                              ),

                            // bars for each bin (0..100 step 10)
                                for (var idx = 0; idx < bins.length; idx++)
                                  Builder(builder: (ctx) {
                                    final bin = bins[idx];
                                    final cnt = dist[bin] ?? 0;
                                    final barHeight = maxCount == 0 ? 0.0 : (cnt / maxCount) * (plotHeight - 8);
                                    final x = chartMarginLeft + idx * spacing;
                                    // make bars slightly narrower so they don't collide with axis labels
                                    final thickBarWidth = spacing * 0.55;
                                    // add small offset so leftmost bar doesn't touch y-axis
                                    final minLeft = chartMarginLeft + 2.0;
                                    return Positioned(
                                      bottom: 52,
                                      left: (x - (thickBarWidth / 2)).clamp(minLeft, plotWidth - chartMarginRight - thickBarWidth - 2.0),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: thickBarWidth,
                                            height: barHeight,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF222222),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                      ),
                                    );
                                  }),

                            // x-axis labels under the chart (percent) - positioned precisely under each tick using spacing
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: SizedBox(
                                height: 52,
                                child: Stack(
                                  children: [
                                    for (var idx = 0; idx < bins.length; idx++)
                                      Builder(builder: (ctx) {
                                            // show labels at a spacing-aware frequency to avoid overlap
                                            final showEvery = (spacing < 28.0) ? 2 : 1; // if cramped, show every 20%
                                            if (idx % showEvery != 0) return const SizedBox.shrink();

                                            // compute compact label width and font size; ensure enough room for "100%"
                                            final labelW = math.min(56.0, math.max(42.0, spacing * 0.85));
                                            final x = chartMarginLeft + idx * spacing;
                                            final unconstrainedLeft = x - (labelW / 2);
                                            final minLeft = chartMarginLeft - (labelW * 0.6);
                                            final maxLeft = plotWidth - chartMarginRight - (labelW * 0.4);
                                            final left = unconstrainedLeft.clamp(minLeft, maxLeft);
                                            return Positioned(
                                              left: left,
                                              width: labelW,
                                              top: 12,
                                              child: Center(
                                                child: Transform.rotate(
                                                  angle: -math.pi / 4,
                                                  alignment: Alignment.center,
                                                  child: SizedBox(
                                                    width: labelW,
                                                    child: Text('${bins[idx]}%', textAlign: TextAlign.center, softWrap: false, maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 11)),
                                                  ),
                                                ),
                                              ),
                                            );
                                      }),
                                  ],
                                ),
                              ),
                            ),

                            // axis lines and tick marks
                            // vertical y-axis line (aligned with chart left margin)
                            Positioned(left: chartMarginLeft, bottom: 52, top: 0, child: Container(width: 1.2, color: Colors.grey.shade700)),
                            // horizontal x-axis line (span only the plotting area)
                            Positioned(left: chartMarginLeft, right: chartMarginRight, bottom: 52, child: Container(height: 1.2, color: Colors.grey.shade700)),
                            // x-axis tick marks
                            for (var idx = 0; idx < bins.length; idx++)
                              Positioned(bottom: 52 - 6, left: (chartMarginLeft + idx * spacing - 1).clamp(chartMarginLeft, plotWidth - chartMarginRight - 2), child: Container(width: 2, height: 6, color: Colors.grey.shade700)),
                          ],
                        );
                      }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              const Text('Score (%)', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 12)),
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

        Widget studentFlagsCard = Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: CustomPaint(
            painter: _GradientPainter(
              strokeWidth: 2,
              radius: 14,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.white],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.redAccent, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Student Flags',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF222222),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (uniqueFlagged.isEmpty)
                      const Text('No flagged students', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94))),
                    for (var uid in uniqueFlagged.take(5))
                      Builder(
                        builder: (ctx) {
                          final user = _users[uid];
                          final name = user?.displayName ?? uid;
                          final violCount = userViolCounts[uid] ?? 0;
                          final appSwitchCount = userAppSwitch[uid] ?? 0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: user?.photoUrl != null &&
                                          user!.photoUrl!.isNotEmpty
                                      ? NetworkImage(user.photoUrl!)
                                      : null,
                                  child: user?.photoUrl == null ||
                                          user!.photoUrl!.isEmpty
                                      ? Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: Color(0xFF222222),
                                              fontWeight: FontWeight.bold),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF222222))),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          if (violCount > 0)
                                            CustomPaint(
                                              painter: _GradientPainter(
                                                strokeWidth: 1.5,
                                                radius: 8,
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [Color.fromARGB(255, 0, 0, 0), Color.fromARGB(255, 248, 248, 248)],
                                                ),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Text(
                                                  '$violCount violations',
                                                  style: const TextStyle(color: Colors.black, fontSize: 12),
                                                ),
                                              ),
                                            ),
                                          if (violCount > 0) const SizedBox(width: 8),
                                          if (appSwitchCount > 0)
                                            CustomPaint(
                                              painter: _GradientPainter(
                                                strokeWidth: 1.5,
                                                radius: 8,
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [Colors.black, Color.fromARGB(255, 248, 248, 248)],
                                                ),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                child: Text(
                                                  '$appSwitchCount app-switches',
                                                  style: const TextStyle(color: Colors.black, fontSize: 12),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Color.fromARGB(255, 94, 94, 94)),
                                  onPressed: () async {
                                    AttemptModel? attempt;
                                    try {
                                      attempt = _attempts.firstWhere((a) => a.userId == uid);
                                    } catch (_) {
                                      attempt = null;
                                    }
                                    if (attempt != null) {
                                      final result = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => _AttemptDetailViewer(
                                          attempt: attempt!,
                                          questions: _questions,
                                          violations: _violationsByAttempt[attempt.id] ?? [],
                                          user: user,
                                        ),
                                      );
                                      if (result == true) {
                                        await _loadAll();
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        Widget integrityCard = Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: CustomPaint(
            painter: _GradientPainter(
              strokeWidth: 2,
              radius: 14,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.white],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: impactColor(percentFlagged), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Quiz Integrity Overview',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF222222),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${attemptsWithViol.length}/${_attempts.length}',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: impactColor(percentFlagged),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'attempts with violations',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color.fromARGB(255, 78, 78, 78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 84,
                          height: 84,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (percentFlagged / 100.0).clamp(0.0, 1.0),
                                color: impactColor(percentFlagged),
                                backgroundColor: const Color.fromARGB(0, 238, 238, 238),
                                strokeWidth: 8,
                              ),
                              Text(
                                '${percentFlagged.toStringAsFixed(0)}%',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: impactColor(percentFlagged), width: 1.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (percentFlagged / 100.0).clamp(0.0, 1.0),
                          color: impactColor(percentFlagged),
                          backgroundColor: const Color.fromARGB(0, 238, 238, 238),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Severity',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color.fromARGB(255, 80, 80, 80)),
                        ),
                        Text(
                          percentFlagged > 25 ? 'High' : (percentFlagged >= 10 ? 'Medium' : 'Low'),
                          style: TextStyle(color: impactColor(percentFlagged), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (constraints.maxWidth >= 800) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: cardWidth, child: studentFlagsCard),
              const SizedBox(width: 16),
              SizedBox(width: cardWidth, child: integrityCard),
            ],
          );
        }
        return Column(children: [studentFlagsCard, const SizedBox(height: 12), integrityCard]);
      }),
      const SizedBox(height: 12),
      // Easy items with gradient borders
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: CustomPaint(
          painter: _GradientPainter(
            strokeWidth: 2,
            radius: 14,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.white],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Most correctly answered',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sortedByEasy.take(5).map((id) {
                    final q = _questions.firstWhere((x) => x.id == id);
                    final st = qStats[id]!;
                    final correct = st['correct'] as int;
                    final total = st['total'] as int;
                    final pctDouble = perQuestionRates[id] ?? 0.0;
                    final badgeColor = pctDouble >= 80
                        ? Colors.green
                        : (pctDouble <= 40 ? Colors.red : const Color(0xFF222222));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF222222)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha((0.12 * 255).round()),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color.fromARGB(78, 0, 0, 0),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              '$correct/$total',
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Difficult items
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: CustomPaint(
          painter: _GradientPainter(
            strokeWidth: 2,
            radius: 14,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.white],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Least correctly answered',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...sortedByHard.take(5).map((id) {
                    final q = _questions.firstWhere((x) => x.id == id);
                    final st = qStats[id]!;
                    final correct = st['correct'] as int;
                    final total = st['total'] as int;
                    final pctDouble = perQuestionRates[id] ?? 0.0;
                    final badgeColor = pctDouble >= 80
                        ? Colors.green
                        : (pctDouble <= 40 ? Colors.red : const Color(0xFF222222));
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF222222)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha((0.12 * 255).round()),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color.fromARGB(78, 0, 0, 0),
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              '$correct/$total',
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // High violation items with counts
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: CustomPaint(
          painter: _GradientPainter(
            strokeWidth: 2,
            radius: 14,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.white],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'High violation items',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...highViolation.take(5).map((id) {
                    final q = _questions.firstWhere((x) => x.id == id);
                    final st = qStats[id]!;
                    final viol = st['violations'] as int;
                    final total = st['total'] as int;
                    final violPct = violationRates[id] ?? 0.0;
                    final badgeColor = violPct >= 50 ? Colors.orange : const Color(0xFF222222);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.prompt,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: Color(0xFF222222)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: badgeColor.withAlpha((0.12 * 255).round()),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              '$viol/$total',
                              style: TextStyle(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),

      // Visual: Violations vs performance & Time-based patterns
      Builder(builder: (context) {
        // helper to render a labeled progress bar with trailing value
        Widget scoreRow(String label, double value, double maxVal, Color color) {
          final pct = (maxVal <= 0) ? 0.0 : (value / maxVal).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 94, 94, 94)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: pct,
                        color: color,
                        backgroundColor: Colors.transparent,
                        minHeight: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    value.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                  ),
                ),
              ],
            ),
          );
        }

        final maxScore = [avgWithViol, avgWithoutViol, avgFastScore, avgSlowScore].fold<double>(0.0, (p, e) => e > p ? e : p);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: CustomPaint(
            painter: _GradientPainter(
              strokeWidth: 2,
              radius: 14,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.white],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Violations vs performance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 12),
                    scoreRow('With violations', avgWithViol, maxScore == 0 ? 1.0 : maxScore, Colors.orange),
                    scoreRow('Without violations', avgWithoutViol, maxScore == 0 ? 1.0 : maxScore, Colors.green),
                    const SizedBox(height: 16),
                    const Text(
                      'Time-based patterns',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF222222),
                      ),
                    ),
                    const SizedBox(height: 12),
                    scoreRow('Fast group (avg)', avgFastScore, maxScore == 0 ? 1.0 : maxScore, Colors.blue),
                    scoreRow('Slow group (avg)', avgSlowScore, maxScore == 0 ? 1.0 : maxScore, Colors.purple),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
      
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: CustomPaint(
          painter: _GradientPainter(
            strokeWidth: 2,
            radius: 14,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black, Colors.white],
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Flagged students (>=3 violations)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    flaggedUsers.isEmpty ? 'None' : flaggedUsers.map((u) => _users[u]?.displayName ?? u).join(', '),
                    style: const TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Frequent app-switchers',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    frequentAppSwitchers.isEmpty ? 'None' : frequentAppSwitchers.map((u) => _users[u]?.displayName ?? u).join(', '),
                    style: const TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 14),
                  ),
                  const Divider(height: 24, color: Color.fromARGB(255, 94, 94, 94)),
                  const Text(
                    'Overall impact of anti-cheating',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentFlagged.toStringAsFixed(1)}% of attempts had at least one violation.',
                    style: const TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF222222),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'These insights are automated heuristics. Review flagged attempts and context before taking action.',
                    style: TextStyle(
                      color: Color.fromARGB(255, 94, 94, 94),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // Individual attempts list
  Widget _buildIndividual() {
    if (_attempts.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No attempts', style: TextStyle(color: Color.fromARGB(255, 94, 94, 94), fontSize: 16))));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _attempts.length,
      itemBuilder: (context, i) {
        final a = _attempts[i];
        final user = _users[a.userId];
        final violations = _violationsByAttempt[a.id] ?? [];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: CustomPaint(
            painter: _GradientPainter(
              strokeWidth: 2,
              radius: 14,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.white],
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    // show interactive attempt viewer
                    final saved = await showDialog<bool>(
                      context: context,
                      builder: (_) => _AttemptDetailViewer(
                        attempt: a,
                        questions: _questions,
                        violations: violations,
                        user: user,
                      ),
                    ) ?? false;
                    // reload after dialog only if changes were saved
                    if (!mounted || !saved) return;
                    await _loadAll();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey.shade300,
                          backgroundImage:
                              user?.photoUrl != null && user!.photoUrl!.isNotEmpty
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                          child: user?.photoUrl == null || user!.photoUrl!.isEmpty
                              ? Text(
                                  (user?.displayName ?? a.userId).isNotEmpty
                                      ? (user?.displayName ?? a.userId)[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? a.userId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF222222),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Score: ${a.score}/${a.totalPoints} • Violations: ${violations.length}',
                                style: const TextStyle(
                                  color: Color.fromARGB(255, 70, 70, 70),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16, color: Color.fromARGB(255, 94, 94, 94)),
                      ],
                    ),
                  ),
                ),
              ),
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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _attempt = widget.attempt;
  }

  String _formatTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = (local.year % 100).toString().padLeft(2, '0');
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$day/$month/$year ${hour12.toString().padLeft(2, '0')}:$minute $ampm';
  }

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

  String? _extractSwitchPath(String? details) => _extractDetailValue(details, 'switchPath');

  String? _extractTrigger(String? details) => _extractDetailValue(details, 'trigger');

  String? _extractAccessibilityPath(String? details) => _extractDetailValue(details, 'accessibilityPath');

  String? _extractOpenedApps(String? details) => _extractDetailValue(details, 'openedApps');

  String _primaryDetail(String? details) {
    if (details == null) return '';
    return details.split('|').first.trim();
  }

  String _violationTypeLabel(ViolationType type) {
    switch (type) {
      case ViolationType.appSwitch:
        return 'App switch';
      case ViolationType.screenResize:
        return 'Screen resize';
      case ViolationType.splitScreen:
        return 'Split screen';
      case ViolationType.screenshot:
        return 'Screenshot';
      case ViolationType.rapidResponse:
        return 'Rapid response';
      case ViolationType.copyPaste:
        return 'Copy/Paste';
      case ViolationType.other:
        return 'Other violation';
    }
  }

  String _violationSubtitle(ViolationModel v) {
    final parts = <String>[];
    final primary = _primaryDetail(v.details);
    if (primary.isNotEmpty) parts.add(primary);
    parts.add('Detected at ${_formatTimestamp(v.detectedAt)}');
    final target = _extractSwitchedToApp(v.details);
    if (target != null) parts.add('Switched to: $target');
    final sequence = _extractSwitchPath(v.details);
    if (sequence != null && sequence.isNotEmpty) parts.add('Sequence: $sequence');
    final trigger = _extractTrigger(v.details);
    if (trigger != null && trigger.isNotEmpty) parts.add('Likely action: $trigger');
    final accessibility = _extractAccessibilityPath(v.details);
    if (accessibility != null && accessibility.isNotEmpty) parts.add('Accessibility trace: $accessibility');
    final opened = _extractOpenedApps(v.details);
    if (opened != null && opened.isNotEmpty) parts.add('Opened apps: $opened');
    return parts.join('\n');
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
      final updated = a.copyWith(isCorrect: !a.isCorrect, manuallyEdited: true);
      final newAnswers = List.of(_attempt.answers);
      newAnswers[index] = updated;
      int newScore = 0;
      for (var ans in newAnswers) {
        if (ans.isCorrect) {
          QuestionModel? q;
          try {
            q = widget.questions.firstWhere((q) => q.id == ans.questionId);
          } catch (_) {
            q = null;
          }
          if (q != null) newScore += q.points;
        }
      }
      _attempt = _attempt.copyWith(answers: newAnswers, score: newScore);
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
      newAnswers.add(a.copyWith(isCorrect: correct, manuallyEdited: false));
    }
    setState(() {
      int newScore = 0;
      for (var ans in newAnswers) {
        if (ans.isCorrect) {
          QuestionModel? q;
          try {
            q = widget.questions.firstWhere((q) => q.id == ans.questionId);
          } catch (_) {
            q = null;
          }
          if (q != null) newScore += q.points;
        }
      }
      _attempt = _attempt.copyWith(answers: newAnswers, score: newScore);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      await FirestoreService().patchAttempt(_attempt.id, _attempt.toFirestore());
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (mounted) SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Failed to save: $e', leading: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: CustomPaint(
        painter: _GradientPainter(
          strokeWidth: 2,
          radius: 14,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.white],
          ),
        ),
        child: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color.fromARGB(255, 197, 197, 197),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: Text('Attempt by ${widget.user?.displayName ?? _attempt.userId}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222222)))),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color.fromARGB(255, 0, 0, 0)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color.fromARGB(255, 94, 94, 94)),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  _NeumorphicButton(
                    onPressed: _recalculate,
                    icon: Icons.refresh,
                    label: 'Reset',
                    showShadow: false,
                  ),
                  const SizedBox(width: 12),
                  _NeumorphicButton(
                    onPressed: _saving ? null : _saveChanges,
                    icon: Icons.save,
                    label: _saving ? 'Saving...' : 'Save',
                    isPrimary: true,
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'Tap on the check icons to mark it as correct or incorrect',
                style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 94, 94, 94), fontStyle: FontStyle.italic),
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: _attempt.answers.length + 1,
                itemBuilder: (context, i) {
                  if (i == _attempt.answers.length) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 24),
                      const Text('Violations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF222222))),
                      const SizedBox(height: 12),
                      if (widget.violations.isEmpty)
                        _buildInfoTile(Icons.check_circle_outline, Colors.green, 'No violations detected', 'This respondent had 0 anti-cheating flags.')
                      else
                        for (var v in widget.violations)
                          _buildInfoTile(Icons.warning_amber_rounded, Colors.deepOrange, _violationTypeLabel(v.type), _violationSubtitle(v)),
                      const SizedBox(height: 24),
                      const Text('Opened apps timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF222222))),
                      const SizedBox(height: 12),
                      if ((_attempt.openedApps).isEmpty)
                        _buildInfoTile(Icons.check_circle_outline, Colors.green, 'No opened apps recorded', 'No app switches recorded.')
                      else
                        Column(
                          children: _attempt.openedApps.map((e) {
                            final pkg = e['package']?.toString() ?? '';
                            final label = e['label']?.toString() ?? pkg;
                            final tsRaw = e['ts']?.toString() ?? '';
                            String tsFormatted = tsRaw;
                            try {
                              tsFormatted = _formatTimestamp(DateTime.parse(tsRaw));
                            } catch (_) {}
                            return _buildInfoTile(Icons.phone_iphone_outlined, const Color(0xFF7F8C8D), label, '$pkg • $tsFormatted');
                          }).toList(),
                        ),
                      const SizedBox(height: 24),
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
                  final isCorrect = ans.isCorrect;
                  final timeLabel = 'Time: ${time}s';
                  final answeredLabel = answeredAt != null ? ' • ${formatAnsweredAt(answeredAt)}' : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: CustomPaint(
                      painter: _GradientPainter(
                        strokeWidth: 1.5,
                        radius: 8,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black, Color.fromARGB(255, 248, 248, 248)],
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(q?.prompt ?? ans.questionId, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF222222))),
                                    const SizedBox(height: 4),
                                    Text('Response: $respLabel', style: const TextStyle(fontSize: 13, color: Color.fromARGB(255, 94, 94, 94))),
                                    Text('$timeLabel$answeredLabel • ${isCorrect ? 'Correct' : 'Incorrect'}', style: TextStyle(fontSize: 12, color: isCorrect ? Colors.green : Colors.red)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(isCorrect ? Icons.check_circle : Icons.check_circle_outline, color: isCorrect ? Colors.green : Colors.grey),
                                onPressed: () => _toggleCorrect(i),
                                tooltip: 'Toggle correct status',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildInfoTile(IconData icon, Color iconColor, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF7F8C8D))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeumorphicButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool showShadow;

  const _NeumorphicButton({required this.onPressed, required this.icon, required this.label, this.isPrimary = false, this.showShadow = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary ? const Color.fromARGB(255, 14, 207, 0) : const Color.fromARGB(255, 255, 0, 0),
            borderRadius: BorderRadius.circular(12),
            boxShadow: (onPressed == null || !showShadow) ? [] : [
              const BoxShadow(color: Color.fromARGB(255, 255, 255, 255), offset: Offset(-3, -3), blurRadius: 6),
              BoxShadow(color: Colors.black.withAlpha(25), offset: const Offset(3, 3), blurRadius: 6),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isPrimary ? const Color(0xFF222222) : const Color(0xFF222222)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: isPrimary ? const Color(0xFF222222) : const Color(0xFF222222))),
            ],
          ),
        ),
      ),
    );
  }
}
