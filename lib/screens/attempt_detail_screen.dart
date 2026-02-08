import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:intl/intl.dart';

// ignore_for_file: use_super_parameters

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

class AttemptDetailScreen extends StatefulWidget {
  final String attemptId;
  const AttemptDetailScreen({super.key, required this.attemptId});

  @override
  State<AttemptDetailScreen> createState() => _AttemptDetailScreenState();
}

class _AttemptDetailScreenState extends State<AttemptDetailScreen> {
  final FirestoreService _fs = FirestoreService();
  bool _loading = true;
  AttemptModel? _attempt;
  QuizModel? _quiz;
  List<QuestionModel> _questions = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final attempt = await _fs.getAttempt(widget.attemptId);
      if (attempt == null) throw Exception('Attempt not found');
      _attempt = attempt;

      final quiz = await _fs.getQuiz(attempt.quizId);
      if (quiz == null) throw Exception('Quiz not found');
      _quiz = quiz;

      final questions = await _fs.getQuizQuestions(attempt.quizId);
      _questions = questions;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildSkeletonScoreCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: CustomPaint(
        painter: _GradientPainter(
          strokeWidth: 2.5,
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
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // "Score" label
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              // Large score number
              Container(
                width: 180,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              // Percentage
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              // Completion date
              Container(
                width: 200,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonQuestionCard() {
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Q# badge and question text
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Q# badge
                      Container(
                        width: 32,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Question text
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 150,
                              height: 16,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color.fromARGB(255, 182, 182, 182), height: 1),
                  const SizedBox(height: 16),
                  // Your Answer row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Correct answer row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 70,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
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
    );
  }

  Widget _buildSkeletonDetail() {
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
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color.fromARGB(255, 179, 179, 179),
                  Color.fromARGB(255, 255, 255, 255),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: const Color.fromARGB(255, 240, 240, 240),
              child: AppBar(
                scrolledUnderElevation: 0,
                title: Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/quiz_history', (route) => route.isFirst),
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonScoreCard(),
              const SizedBox(height: 32),
              const Text(
                'Question Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
              ),
              const SizedBox(height: 16),
              _buildSkeletonQuestionCard(),
              const SizedBox(height: 16),
              _buildSkeletonQuestionCard(),
              const SizedBox(height: 16),
              _buildSkeletonQuestionCard(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _buildSkeletonDetail();
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        body: Center(child: Text(_error!)),
      );
    }

    final attempt = _attempt!;
    final quiz = _quiz!;

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
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color.fromARGB(255, 179, 179, 179),
                  Color.fromARGB(255, 255, 255, 255),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: const Color.fromARGB(255, 240, 240, 240),
              child: AppBar(
                scrolledUnderElevation: 0,
                title: Text(quiz.title, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/quiz_history', (route) => route.isFirst),
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score Card
            Container(
              key: ValueKey('score_card'),
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: CustomPaint(
                painter: _GradientPainter(
                  strokeWidth: 2.5,
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        'Score',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${attempt.score} / ${attempt.totalPoints}',
                        style: const TextStyle(
                          fontSize: 52, 
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${attempt.scorePercentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: attempt.scorePercentage >= 75 ? const Color(0xFF27AE60) : 
                                 attempt.scorePercentage >= 50 ? const Color(0xFFF39C12) : const Color(0xFFE74C3C),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (attempt.submittedAt != null)
                       Column(
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           Text(
                             'Completed on ${DateFormat.yMMMd().add_jm().format(attempt.submittedAt!)}',
                             style: TextStyle(color: Colors.grey[600], fontSize: 13),
                           ),
                           const SizedBox(height: 4),
                           Builder(
                             builder: (context) {
                               final timeDiff = attempt.submittedAt!.difference(attempt.startedAt);
                               final totalSeconds = timeDiff.inSeconds;
                               final totalMilliseconds = timeDiff.inMilliseconds;
                               String timeTaken;
                               if (totalSeconds < 60) {
                                 final seconds = totalMilliseconds ~/ 1000;
                                 final centiseconds = (totalMilliseconds % 1000) ~/ 10;
                                 timeTaken = '$seconds.${centiseconds.toString().padLeft(2, '0')} sec';
                               } else {
                                 final minutes = totalSeconds ~/ 60;
                                 final secs = totalSeconds % 60;
                                 timeTaken = '$minutes:${secs.toString().padLeft(2, '0')} mins';
                               }
                               return Text(
                                 'Time taken: $timeTaken',
                                 style: TextStyle(color: Colors.grey[600], fontSize: 13),
                               );
                             },
                           ),
                         ],
                       ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            const Text(
              'Question Review',
               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
            ),
            const SizedBox(height: 16),

            ..._questions.map((q) {
              final attemptAnswer = attempt.answers.firstWhere(
                (a) => a.questionId == q.id,
                orElse: () => AttemptAnswerModel(
                  questionId: q.id, 
                  selectedChoiceId: '', 
                  timeTakenSeconds: 0, 
                  isCorrect: false
                ),
              );

              final isCorrect = attemptAnswer.isCorrect;
              final selectedOption = q.choices.firstWhere(
                (o) => o.id == attemptAnswer.selectedChoiceId, 
                orElse: () => Choice(id: '', text: 'No Answer'),
              );
              
              // Find the first correct option (assuming single choice for now)
              final correctOption = q.choices.firstWhere(
                (o) => q.correctAnswers.contains(o.id),
                orElse: () => Choice(id: '', text: 'Unknown', points: 0),
              );

              return Container(
                key: ValueKey(q.id),
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isCorrect ? const Color.fromARGB(255, 0, 201, 0) : const Color.fromARGB(255, 204, 0, 0),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: Colors.white,
                                        offset: Offset(-2, -2),
                                        blurRadius: 5,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        offset: const Offset(2, 2),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isCorrect ? Icons.check : Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        q.prompt,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                                      ),
                                      if (attemptAnswer.manuallyEdited) 
                                        Text(
                                          'Author manually corrected',
                                          style: TextStyle(color: Colors.red[400], fontSize: 12, fontStyle: FontStyle.italic),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Color.fromARGB(255, 182, 182, 182), height: 1),
                            const SizedBox(height: 16),
                            
                            _AnswerRow(
                              label: 'Your Answer:', 
                              text: selectedOption.text, 
                              color: const Color.fromARGB(255, 49, 49, 49),
                            ),
                            if (!isCorrect) ...[
                              const SizedBox(height: 12),
                              _AnswerRow(
                                label: 'Correct:', 
                                text: correctOption.text, 
                                color: const Color.fromARGB(255, 49, 49, 49),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _AnswerRow({required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Color.fromARGB(255, 70, 70, 70), fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
