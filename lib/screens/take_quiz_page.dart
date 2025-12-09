import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/violation_model.dart';
import 'package:quiz_application/services/anti_cheat_service.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/utils/answer_utils.dart';
import 'package:quiz_application/models/attempt_model.dart';
import 'package:quiz_application/providers/auth_provider.dart';

class TakeQuizPage extends StatefulWidget {
  final String quizId;
  const TakeQuizPage({super.key, required this.quizId});

  @override
  State<TakeQuizPage> createState() => _TakeQuizPageState();
}

class _TakeQuizPageState extends State<TakeQuizPage> with WidgetsBindingObserver {
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
  DateTime? _attemptStartedAt;
  final TextEditingController _textController = TextEditingController();
  final List<ViolationModel> _pendingViolations = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
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
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final qs = await _firestore.getQuizQuestions(widget.quizId);
    setState(() {
      _quizTitle = quiz.title;
      _questions = qs;
      _loading = false;
    });
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

    _antiCheat.startAntiCheat(id, user.uid);
    // Show an in-app popup whenever the anti-cheat service logs a violation.
    _antiCheat.setOnViolation((violation) {
      if (!mounted) return;
      final isForeground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (isForeground && isCurrentRoute) {
        final shortType = violation.type.toString().split('.').last;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Warning'),
            content: Text('We detected a potential anti-cheating event: $shortType. Please remain on the quiz screen.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // apply punishment after user acknowledged warning
                  _applyViolationConsequences();
                },
                child: const Text('Continue'),
              )
            ],
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Anti-cheat: $shortType detected'), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)));
      } else {
        // Buffer the violation and notify when the user returns to the app.
        _pendingViolations.add(violation);
        // Also show a lightweight snackbar when they return; but we store details now.
      }
    });

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _pendingViolations.isNotEmpty && mounted) {
      // Consolidate pending violations into a single alert to avoid spamming the user.
      final types = _pendingViolations.map((v) => v.type.toString().split('.').last).toList();
      final unique = types.toSet().toList();
      final summary = unique.join(', ');
      final count = _pendingViolations.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Warning'),
            content: Text('Detected $count anti-cheat event(s): $summary. Please remain on the quiz screen.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // apply accumulated consequences now
                  _applyViolationConsequences();
                },
                child: const Text('Continue'),
              )
            ],
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Anti-cheat: $count event(s) detected'), backgroundColor: Colors.orange, duration: const Duration(seconds: 4)));
      });
      _pendingViolations.clear();
    }
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
    if (q.type == QuestionType.shortAnswer || q.type == QuestionType.paragraph) {
      final text = _answers[q.id] ?? '';
      // avoid reassigning if same text to reduce cursor jumps
      if (_textController.text != text) {
        _textController.text = text;
        _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
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
    final duration = _questionStartTime != null ? now.difference(_questionStartTime!).inSeconds : 0;

    if (q.type == QuestionType.multipleChoice || q.type == QuestionType.dropdown) {
      // already recorded in _answerSingle
      return;
    }

    String userResp;
    if (q.type == QuestionType.checkbox) {
      userResp = (_multiAnswers[qid] ?? []).join(',');
    } else {
      userResp = _answers[qid] ?? '';
    }

    final model = AttemptAnswerModel(
      questionId: qid,
      selectedChoiceId: userResp,
      timeTakenSeconds: duration,
      answeredAt: now,
      isCorrect: false,
    );
    _answerModels[qid] = model;
  }

  // Flag the current question as incorrect immediately (used as a penalty).
  void _flagCurrentQuestionIncorrect() {
    if (_questions.isEmpty) return;
    final q = _questions[_currentQuestionIndex];
    final qid = q.id;
    final now = DateTime.now();
    final duration = _questionStartTime != null ? now.difference(_questionStartTime!).inSeconds : 0;

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
    );
    setState(() {
      _answerModels[qid] = penalized;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current question flagged as incorrect due to policy violation'), backgroundColor: Colors.red, duration: Duration(seconds: 3)));
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
      _flagCurrentQuestionIncorrect();
      return;
    }
    // count >= 3 -> auto-submit
    // ensure current question is flagged as incorrect as well
    _flagCurrentQuestionIncorrect();
    // small delay so the snackbar/changes have a moment to settle
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _submitAttempt();
    });
  }

  void _answerCheckbox(String qid, String choiceId, bool selected) {
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
    _answers[qid] = choiceId;
    final now = DateTime.now();
    final duration = _questionStartTime != null ? now.difference(_questionStartTime!).inSeconds : 0;
    _answerModels[qid] = AttemptAnswerModel(
      questionId: qid,
      selectedChoiceId: choiceId,
      timeTakenSeconds: duration,
      answeredAt: now,
      isCorrect: false,
    );
    _antiCheat.onQuestionAnswered();
    Future.microtask(() {
      if (mounted) _nextQuestion();
    });
  }

  void _answerText(String qid, String text) {
    _answers[qid] = text;
    _antiCheat.onQuestionAnswered();
  }

  

  Future<void> _submitAttempt() async {
    if (_attemptId == null) return;

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
        correct = expected.length == actual.length && expected.difference(actual).isEmpty;
      } else if (q.type == QuestionType.multipleChoice || q.type == QuestionType.dropdown) {
        if (q.correctAnswers.isNotEmpty) correct = userResp == q.correctAnswers.first;
      } else if (q.type == QuestionType.shortAnswer || q.type == QuestionType.paragraph) {
        if (q.correctAnswers.isNotEmpty) {
          final normUser = normalizeAnswerForComparison(userResp);
          final normCorrect = normalizeAnswerForComparison(q.correctAnswers.first);
          correct = normUser == normCorrect;
        }
      }

      if (correct) score += q.points;

      if (existing != null) {
        answersList.add(existing.copyWith(isCorrect: correct));
      } else {
        answersList.add(AttemptAnswerModel(
          questionId: qid,
          selectedChoiceId: userResp,
          timeTakenSeconds: 0,
          answeredAt: null,
          isCorrect: correct,
        ));
      }
    }

    final attempt = AttemptModel(
      id: _attemptId!,
      quizId: widget.quizId,
      userId: Provider.of<AuthProvider>(context, listen: false).currentUser!.uid,
      startedAt: _attemptStartedAt ?? DateTime.now(),
      submittedAt: DateTime.now(),
      score: score,
      totalPoints: _questions.fold<int>(0, (s, q) => s + q.points),
      answers: answersList,
      totalViolations: _antiCheat.getViolationCount(),
    );

    await _firestore.submitAttempt(_attemptId!, attempt);
    _antiCheat.stopAntiCheat();

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submitted'),
          content: Text('Score: ${attempt.score}/${attempt.totalPoints}'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newSize = MediaQuery.of(context).size;
      if (_attemptId != null && (_reportedScreenSize == null || _reportedScreenSize != newSize)) {
        _reportedScreenSize = newSize;
        _antiCheat.onScreenSizeChanged(newSize);
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(_quizTitle ?? 'Quiz')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  if (_remainingSeconds != null) Text('Time left: ${_formatRemaining(_remainingSeconds!)}'),
                  Expanded(
                    child: _questions.isEmpty
                        ? const SizedBox.shrink()
                        : Builder(builder: (context) {
                            final q = _questions[_currentQuestionIndex];
                            final started = _attemptId != null;
                            return Stack(
                              children: [
                                // The interactive content; blocked by IgnorePointer when not started
                                IgnorePointer(
                                  ignoring: !started,
                                  child: Opacity(
                                    opacity: started ? 1.0 : 0.95,
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Question ${_currentQuestionIndex + 1} of ${_questions.length}', style: const TextStyle(color: Colors.grey)),
                                            const SizedBox(height: 6),
                                            Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            if (q.type == QuestionType.multipleChoice || q.type == QuestionType.dropdown)
                                              Column(
                                                children: q.choices.map((c) {
                                                  final selected = _answers[q.id] == c.id;
                                                  return ListTile(
                                                    title: Text(c.text),
                                                    leading: IconButton(
                                                      icon: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                                                      onPressed: () => _answerSingle(q.id, c.id),
                                                    ),
                                                    onTap: () => _answerSingle(q.id, c.id),
                                                  );
                                                }).toList(),
                                              ),
                                            if (q.type == QuestionType.checkbox)
                                              Column(
                                                children: q.choices.map((c) {
                                                  return CheckboxListTile(
                                                    title: Text(c.text),
                                                    value: (_multiAnswers[q.id] ?? []).contains(c.id),
                                                    onChanged: (v) => _answerCheckbox(q.id, c.id, v ?? false),
                                                  );
                                                }).toList(),
                                              ),
                                            if (q.type == QuestionType.shortAnswer || q.type == QuestionType.paragraph)
                                              TextField(
                                                controller: _textController,
                                                onChanged: (v) => _answerText(q.id, v),
                                                keyboardType: TextInputType.multiline,
                                                textInputAction: TextInputAction.newline,
                                                minLines: q.type == QuestionType.paragraph ? 3 : 1,
                                                maxLines: q.type == QuestionType.paragraph ? null : 1,
                                                decoration: const InputDecoration(border: OutlineInputBorder()),
                                              ),
                                            

                                            const SizedBox(height: 12),
                                            if (q.type == QuestionType.checkbox || q.type == QuestionType.shortAnswer || q.type == QuestionType.paragraph)
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      final ok = (q.type == QuestionType.checkbox && (_multiAnswers[q.id] ?? []).isNotEmpty) ||
                                                          ((q.type == QuestionType.shortAnswer || q.type == QuestionType.paragraph) && (_answers[q.id] ?? '').trim().isNotEmpty);
                                                      if (ok) {
                                                        _recordCurrentAnswerIfNeeded();
                                                        _nextQuestion();
                                                      }
                                                    },
                                                    child: Text(_currentQuestionIndex + 1 < _questions.length ? 'Next' : 'Submit'),
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
                                        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
                                        child: Container(
                                          color: const Color.fromRGBO(0, 0, 0, 0.25),
                                          alignment: Alignment.center,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                                            onPressed: _startAttempt,
                                            child: const Text('Start Attempt'),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                  ),
                ],
              ),
            ),
    );
  }
}
