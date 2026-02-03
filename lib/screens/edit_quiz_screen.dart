import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/screens/question_editor.dart';

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
  final _timeController = TextEditingController();
  bool _enablePassword = false;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _timeController.dispose();
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
      _timeController.text = _timeMinutes.toString();
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

  Future<bool> _saveQuizSettings({bool showSnack = true}) async {
    if (_enablePassword && _passwordController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a password or disable password protection')),
        );
      }
      return false;
    }

    final mins = int.tryParse(_timeController.text) ?? 0;
    
    await FirestoreService().updateQuiz(quizId, {
      'randomizeQuestions': _shuffleQuestions,
      'randomizeOptions': _shuffleChoices,
      'singleResponse': _singleResponse,
      'timeLimitSeconds': mins * 60,
      'scoringType': 'auto',
      'password': _enablePassword ? _passwordController.text.trim() : null,
      'updatedAt': DateTime.now(),
    });
    await _load();
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
    }
    return true;
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
    final saved = await _saveQuizSettings(showSnack: false);
    if (!saved) return;

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
      child: WillPopScope(
        onWillPop: () => _saveQuizSettings(showSnack: false),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color.fromARGB(108, 244, 244, 244), Color.fromARGB(205, 223, 223, 223)],
                ),
              ),
              child: AppBar(
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                title: Text(_quiz?.title ?? 'Edit Quiz', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                actions: [
                  if (_quiz != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Tooltip(
                        message: (!_quiz!.published && _questions.isEmpty) ? 'Add at least one question before publishing' : '',
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _quiz!.published ? const Color(0xFFC0392B) : const Color(0xFF222222),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: (!_quiz!.published && _questions.isEmpty)
                              ? null
                              : _quiz!.published
                                  ? () async {
                                      if (!await _saveQuizSettings(showSnack: false)) return;
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
            ),
          ),
        ),
        floatingActionButton: null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_quiz != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _quiz!.description,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF7F8C8D)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_quiz != null && !_quiz!.published && _questions.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFECB5)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, size: 20, color: Color(0xFF856404)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add at least one question to enable Publish.',
                                style: TextStyle(color: Color(0xFF856404)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text('Quiz Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF222222))),
                    const SizedBox(height: 16),
                    _settingsSwitch('Shuffle questions', _shuffleQuestions, (v) => setState(() => _shuffleQuestions = v)),
                    _settingsSwitch('Shuffle choices', _shuffleChoices, (v) => setState(() => _shuffleChoices = v)),
                    _settingsSwitch('Single response per user', _singleResponse, (v) => setState(() => _singleResponse = v)),
                    _settingsSwitch('Enable Quiz Password', _enablePassword, (v) => setState(() => _enablePassword = v)),
                    if (_enablePassword)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: _buildGradientTextField(
                          controller: _passwordController,
                          hint: 'Enter password',
                          icon: Icons.lock,
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildGradientTextField(
                      controller: _timeController,
                      hint: 'Time limit (minutes)',
                      icon: Icons.timer,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                    ),
                    const SizedBox(height: 32),
                    const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF222222))),
                    const SizedBox(height: 12),
                    if (_questions.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No questions yet, add some!', style: TextStyle(color: Colors.grey)))),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      onReorder: (oldIndex, newIndex) async {
                        setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _questions.removeAt(oldIndex);
                        _questions.insert(newIndex, item);
                        });
                        for (var i = 0; i < _questions.length; i++) {
                          await FirestoreService().updateQuestion(quizId, _questions[i].id, {'order': i});
                        }
                        // avoid full reload to keep UI smooth, just sync order
                      },
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, _) {
                            return Transform.translate(
                              offset: Offset(0, (animation.value - 1) * 0),
                              child: Material(
                                color: Colors.transparent,
                                child: child,
                              ),
                            );
                          },
                        );
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

                        return Container(
                          key: ValueKey(q.id),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: _neumorphicQuestionCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(q.prompt, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF222222))),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
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
                                              child: Text(typeLabel, style: const TextStyle(color: Colors.black, fontSize: 12)),
                                            ),
                                          ),
                                          if (correctText != null)
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
                                                child: Text('Ans: $correctText', style: const TextStyle(color: Colors.black, fontSize: 12)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit',
                                      icon: const Icon(Icons.edit, color: Color.fromARGB(255, 0, 0, 0)),
                                      onPressed: () => _editQuestion(q),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete',
                                      icon: const Icon(Icons.delete, color: Color.fromARGB(255, 0, 0, 0)),
                                      onPressed: () => _deleteQuestion(q.id),
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: const Padding(padding: EdgeInsets.symmetric(horizontal: 4.0), child: Icon(Icons.drag_handle, color: Color.fromARGB(255, 0, 0, 0))),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: CustomPaint(
                        painter: _GradientPainter(
                          strokeWidth: 2,
                          radius: 22,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF000000),
                              Color(0xFFBDBDBD),
                              Color(0xFFFFFFFF),
                              Color(0xFFFFFFFF),
                            ],
                          ),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _addQuestion,
                              customBorder: const CircleBorder(),
                              child: Center(
                                child: Icon(
                                  Icons.add,
                                  size: 24,
                                  color: const Color.fromARGB(255, 94, 94, 94),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      bottomNavigationBar: null,
        ),
      ),
    );
  }

  Widget _neumorphicQuestionCard({required Widget child, double padding = 16}) {
    return CustomPaint(
      painter: _GradientPainter(
        strokeWidth: 2,
        radius: 16,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.white],
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      ),
    );
  }

  Widget _buildGradientTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return CustomPaint(
      painter: _GradientPainter(
        strokeWidth: 2,
        radius: 10,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000),
            Color(0xFFBDBDBD),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          cursorColor: Colors.black54,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(icon, color: Colors.black54),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 8,
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              color: Colors.black26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingsSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF222222),
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Theme(
              data: ThemeData(
                useMaterial3: true,
                switchTheme: SwitchThemeData(
                  thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return const Color(0xFFE0E0E0);
                  }),
                  trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF222222);
                    }
                    return const Color(0xFFBDBDBD);
                  }),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ),
              child: Switch(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
      