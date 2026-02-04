import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
// Local queueing removed intentionally; use FirestoreService directly.
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/models/question_model.dart';

class AttemptsReviewScreen extends StatefulWidget {
  final String quizId;
  const AttemptsReviewScreen({super.key, required this.quizId});

  @override
  State<AttemptsReviewScreen> createState() => _AttemptsReviewScreenState();
}

class _AttemptsReviewScreenState extends State<AttemptsReviewScreen> {
  final FirestoreService _fs = FirestoreService();
  late Future<List<AttemptModel>> _attemptsFuture;
  late Future<List<QuestionModel>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _attemptsFuture = _fs.getAttemptsByQuiz(widget.quizId);
    _questionsFuture = _fs.getQuizQuestions(widget.quizId);
  }

  Future<void> _reload() async {
    setState(() {
      _attemptsFuture = _fs.getAttemptsByQuiz(widget.quizId);
      _questionsFuture = _fs.getQuizQuestions(widget.quizId);
    });
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color.fromARGB(255, 231, 231, 231),
                    Color.fromARGB(255, 247, 247, 247),
                  ],
                ),
              ),
              child: AppBar(
                title: const Text('Attempts', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
        body: FutureBuilder<List<AttemptModel>>(
        future: _attemptsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final attempts = snap.data ?? [];
          if (attempts.isEmpty) return const Center(child: Text('No attempts yet'));
          return FutureBuilder<List<QuestionModel>>(
            future: _questionsFuture,
            builder: (context, qsnap) {
              if (qsnap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              final questions = qsnap.data ?? [];
              return ListView.builder(
                itemCount: attempts.length,
                itemBuilder: (context, i) {
                  final a = attempts[i];
                  return ListTile(
                    title: Text('User: ${a.userId}'),
                    subtitle: Text('Score: ${a.score}/${a.totalPoints}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _openAttemptDetail(context, a, questions),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      ),
    );
  }

  void _openAttemptDetail(BuildContext context, AttemptModel attempt, List<QuestionModel> questions) {
    showDialog(
      context: context,
      builder: (_) => AttemptDetailDialog(
        attempt: attempt,
        questions: questions,
        onSaved: () async {
          if (!mounted) return;
          await _reload();
        },
      ),
    );
  }
}

class AttemptDetailDialog extends StatefulWidget {
  final AttemptModel attempt;
  final List<QuestionModel> questions;
  final VoidCallback onSaved;
  const AttemptDetailDialog({super.key, required this.attempt, required this.questions, required this.onSaved});

  @override
  State<AttemptDetailDialog> createState() => _AttemptDetailDialogState();
}

class _AttemptDetailDialogState extends State<AttemptDetailDialog> {
  late AttemptModel _attempt;

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

  Future<void> _saveAttempt() async {
    try {
      await FirestoreService().patchAttempt(_attempt.id, _attempt.toFirestore());
      widget.onSaved();
    } catch (e) {
      // ignore: avoid_print
      print('[AttemptsReview] failed to save attempt: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Attempt by ${_attempt.userId}'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _attempt.answers.length,
          itemBuilder: (context, i) {
            final a = _attempt.answers[i];
            final q = _findQuestion(a.questionId);
            final prompt = q?.prompt ?? a.questionId;
            final type = q?.type;
            return ListTile(
              title: Text(prompt),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text('Response: ${a.selectedChoiceId}'),
                  if (type == QuestionType.paragraph)
                    Row(
                      children: [
                        const Text('Mark as correct:'),
                        Switch(
                          value: a.isCorrect,
                          onChanged: (v) {
                            setState(() {
                              // update local attempt answer by creating a new instance
                              final updated = AttemptAnswerModel(
                                questionId: a.questionId,
                                selectedChoiceId: a.selectedChoiceId,
                                timeTakenSeconds: a.timeTakenSeconds,
                                answeredAt: a.answeredAt,
                                isCorrect: v,
                                forceIncorrect: a.forceIncorrect,
                              );
                              final list = _attempt.answers.toList();
                              list[i] = updated;
                              // recalc score: adjust based on question points
                              int newScore = 0;
                              for (var j = 0; j < list.length; j++) {
                                final ans = list[j];
                                final qq = _findQuestion(ans.questionId);
                                if (ans.isCorrect && qq != null) newScore += qq.points;
                              }
                              _attempt = _attempt.copyWith(score: newScore, answers: list);
                            });
                          },
                        ),
                      ],
                    ),
                ],
              ),
              trailing: a.isCorrect ? const Icon(Icons.check, color: Colors.green) : null,
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final navigator = Navigator.of(context);
            await _saveAttempt();
            if (mounted) navigator.pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
