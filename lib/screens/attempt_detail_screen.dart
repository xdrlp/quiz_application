import 'package:flutter/material.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
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
            Color.fromARGB(255, 207, 207, 207),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(quiz.title),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
          ),
          titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'Score',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${attempt.score} / ${attempt.totalPoints}',
                    style: const TextStyle(
                      fontSize: 48, 
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${attempt.scorePercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      color: attempt.scorePercentage >= 75 ? Colors.green : 
                             attempt.scorePercentage >= 50 ? Colors.orange : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (attempt.submittedAt != null)
                   Text(
                      'Completed on ${DateFormat.yMMMd().add_jm().format(attempt.submittedAt!)}',
                       style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(
              'Question Review',
               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),

            ..._questions.map((q) {
              final idx = _questions.indexOf(q) + 1;
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
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCorrect ? Colors.green.withValues(alpha: 0.5) : Colors.red.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCorrect ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q$idx',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            q.prompt,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 12),
                    
                    _AnswerRow(
                      label: 'Your Answer:', 
                      text: selectedOption.text, 
                      color: isCorrect ? Colors.green[300]! : Colors.red[300]!,
                    ),
                    if (!isCorrect)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _AnswerRow(
                          label: 'Correct Answer:', 
                          text: correctOption.text, 
                          color: Colors.green[300]!,
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
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
