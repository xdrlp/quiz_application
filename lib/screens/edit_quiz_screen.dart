import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/screens/question_editor.dart';

class EditQuizScreen extends StatefulWidget {
  const EditQuizScreen({super.key});

  @override
  State<EditQuizScreen> createState() => _EditQuizScreenState();
}

class _EditQuizScreenState extends State<EditQuizScreen> {
  late String quizId;
  QuizModel? _quiz;
  List<QuestionModel> _questions = [];
  bool _loading = true;
  // settings state
  bool _shuffleQuestions = false;
  bool _shuffleChoices = false;
  bool _singleResponse = false;
  int _timeMinutes = 0;
  bool _enablePassword = false;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)!.settings.arguments;
    if (arg is String) {
      quizId = arg;
      _load();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = await FirestoreService().getQuiz(quizId);
    final list = await FirestoreService().getQuizQuestions(quizId);
    setState(() {
      _quiz = q;
      _questions = list;
      _shuffleQuestions = q?.randomizeQuestions ?? false;
      _shuffleChoices = q?.randomizeOptions ?? false;
      _singleResponse = (q?.singleResponse) ?? false;
      _timeMinutes = ((q?.timeLimitSeconds ?? 0) / 60).ceil();
      _enablePassword = (q?.password != null && q!.password!.isNotEmpty);
      _passwordController.text = q?.password ?? '';
      _loading = false;
    });
  }

  Future<void> _addQuestion() async {
    final result = await showDialog<QuestionModel>(
      context: context,
      builder: (_) => const QuestionEditor(),
    );
    if (result != null) {
      final toSave = result.copyWith(order: _questions.length, createdAt: DateTime.now());
      await FirestoreService().addQuestion(quizId, toSave);
      await _load();
    }
  }

  Future<void> _saveSettings() async {
    if (_enablePassword && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password or disable password protection')),
      );
      return;
    }
    
    await FirestoreService().updateQuiz(quizId, {
      'randomizeQuestions': _shuffleQuestions,
      'randomizeOptions': _shuffleChoices,
      'singleResponse': _singleResponse,
      'timeLimitSeconds': _timeMinutes * 60,
      'scoringType': 'auto',
      'password': _enablePassword ? _passwordController.text.trim() : null,
      'updatedAt': DateTime.now(),
    });
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Future<void> _editQuestion(QuestionModel q) async {
    final result = await showDialog<QuestionModel>(
      context: context,
      builder: (_) => QuestionEditor(initial: q),
    );
    if (result != null) {
      await FirestoreService().updateQuestion(quizId, q.id, result.toFirestore());
      await _load();
    }
  }

  Future<void> _deleteQuestion(String id) async {
    await FirestoreService().deleteQuestion(quizId, id);
    await _load();
  }

  Future<void> _publishQuiz() async {
    if (_questions.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one question before publishing')));
      return;
    }

    final requiresCorrect = {
      QuestionType.multipleChoice,
      QuestionType.checkbox,
      QuestionType.dropdown,
    };
    final invalid = _questions.where((q) => requiresCorrect.contains(q.type) && (q.correctAnswers.isEmpty)).toList();
    if (invalid.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Some questions are missing correct answers. Mark them before publishing.')));
      return;
    }

    final questionCount = _questions.length;
    final totalPoints = _questions.fold<int>(0, (s, q) => s + q.points);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Publish'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Questions: $questionCount'),
            const SizedBox(height: 6),
            Text('Total points: $totalPoints'),
            const SizedBox(height: 12),
            const Text('Publish this quiz? This will make it available to participants.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Publish')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirestoreService().publishQuiz(quizId, true);
      await _load();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Quiz Published'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your quiz is now published. Share the code below with participants:'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: SelectableText(_quiz?.quizCode ?? '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(
                    tooltip: 'Copy code',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _quiz?.quizCode ?? '')).then((_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz code copied')));
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        ),
      );
      // indicate to caller that publishing occurred so they can refresh
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_quiz?.title ?? 'Edit Quiz'),
        actions: [
          if (_quiz != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: Tooltip(
                message: (!_quiz!.published && _questions.isEmpty) ? 'Add at least one question before publishing' : '',
                child: ElevatedButton(
                  onPressed: (!_quiz!.published && _questions.isEmpty)
                      ? null
                      : _quiz!.published
                          ? () async {
                              await FirestoreService().publishQuiz(quizId, false);
                              await _load();
                            }
                          : _publishQuiz,
                  child: Text(_quiz!.published ? 'Unpublish' : 'Publish'),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addQuestion,
        tooltip: 'Add question',
        elevation: 6.0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_quiz != null) Text(_quiz!.description),
                  if (_quiz != null && !_quiz!.published && _questions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Expanded(child: Text('Add at least one question to enable Publish. You can publish once the quiz has questions.')),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quiz Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Text('Shuffle questions'),
                            const Spacer(),
                            Switch(value: _shuffleQuestions, onChanged: (v) => setState(() => _shuffleQuestions = v)),
                          ]),
                          Row(children: [
                            const Text('Shuffle choices'),
                            const Spacer(),
                            Switch(value: _shuffleChoices, onChanged: (v) => setState(() => _shuffleChoices = v)),
                          ]),
                          Row(children: [
                            const Text('Single response per user'),
                            const Spacer(),
                            Switch(value: _singleResponse, onChanged: (v) => setState(() => _singleResponse = v)),
                          ]),
                          Row(children: [
                            const Text('Enable Quiz Password'),
                            const Spacer(),
                            Switch(value: _enablePassword, onChanged: (v) => setState(() => _enablePassword = v)),
                          ]),
                          if (_enablePassword)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: TextField(
                                controller: _passwordController,
                                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                              ),
                            ),
                          Row(children: [
                            const Text('Time limit (minutes)'),
                            const Spacer(),
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: _timeMinutes.toString(),
                                keyboardType: TextInputType.number,
                                onChanged: (v) => setState(() => _timeMinutes = int.tryParse(v) ?? 0),
                              ),
                            )
                          ]),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(onPressed: _saveSettings, child: const Text('Save Settings')),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _questions.removeAt(oldIndex);
                        _questions.insert(newIndex, item);
                        for (var i = 0; i < _questions.length; i++) {
                          await FirestoreService().updateQuestion(quizId, _questions[i].id, {'order': i});
                        }
                        await _load();
                      },
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        final typeLabel = questionTypeDisplayName(q.type);
                        String? correctText;
                        if (q.correctAnswers.isNotEmpty) {
                          final resolved = q.correctAnswers.map((ans) {
                            final match = q.choices.firstWhere((c) => c.id == ans || c.text == ans, orElse: () => Choice(id: '', text: ans));
                            return match.text;
                          }).toList();
                          correctText = resolved.join(', ');
                        }

                        return Card(
                          key: ValueKey(q.id),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(q.prompt, style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Chip(label: Text(typeLabel), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                          if (correctText != null)
                                            Chip(
                                              label: Text('Answer: $correctText'),
                                              backgroundColor: Theme.of(context).colorScheme.secondary.withAlpha((0.12 * 255).round()),
                                              visualDensity: VisualDensity.compact,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(tooltip: 'Edit question', icon: const Icon(Icons.settings), onPressed: () => _editQuestion(q)),
                                    IconButton(tooltip: 'Delete question', icon: const Icon(Icons.delete), onPressed: () => _deleteQuestion(q.id)),
                                    ReorderableDragStartListener(index: index, child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Icon(Icons.drag_handle))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
      bottomNavigationBar: null,
    );
  }
}
