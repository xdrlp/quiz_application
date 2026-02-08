import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/models/question_model.dart';
import 'package:quiz_application/screens/question_editor.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is String) {
        quizId = arg;
        _load();
      } else if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _timeController.dispose();
    super.dispose();
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
      _timeController.text = _timeMinutes.toString();
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
      if (mounted) {
        setState(() {
          _questions.add(toSave);
        });
      }
    }
  }

  Future<bool> _saveQuizSettings({bool showSnack = true}) async {
    if (_enablePassword && _passwordController.text.trim().isEmpty) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Please enter a password or disable password protection', leading: Icons.error_outline);
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
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Settings saved', leading: Icons.check_circle_outline);
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
      if (mounted) {
        final index = _questions.indexWhere((question) => question.id == q.id);
        if (index != -1) {
          setState(() {
            _questions[index] = result.copyWith(id: q.id);
          });
        }
      }
    }
  }

  Future<void> _deleteQuestion(String id) async {
    await FirestoreService().deleteQuestion(quizId, id);
    if (mounted) {
      setState(() {
        _questions.removeWhere((q) => q.id == id);
      });
    }
  }

  Future<void> _publishQuiz() async {
    final saved = await _saveQuizSettings(showSnack: false);
    if (!saved) return;

    if (_questions.isEmpty) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Add at least one question before publishing', leading: Icons.error_outline);
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
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Some questions are missing correct answers. Mark them before publishing.', leading: Icons.error_outline);
      return;
    }

    final questionCount = _questions.length;
    final totalPoints = _questions.fold<int>(0, (s, q) => s + q.points);

    if (!mounted) return;
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Center(
          child: SingleChildScrollView(
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: 360,
                child: CustomPaint(
                  painter: _GradientPainter(
                    strokeWidth: 2,
                    radius: 20,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.white],
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.fromARGB(255, 226, 226, 226),
                          Color.fromARGB(255, 167, 167, 167),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Confirm Publish',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color.fromARGB(206, 34, 34, 34),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This will make it available to participants.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color.fromARGB(202, 0, 0, 0),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Quiz Details Section
                        _buildDetailCard(
                          children: [
                            _buildDetailRow('Questions', questionCount.toString()),
                            const SizedBox(height: 12),
                            _buildDetailRow('Total Points', totalPoints.toString()),
                            const SizedBox(height: 12),
                            _buildDetailRow('Quiz Code', _quiz?.quizCode ?? 'N/A'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Settings Section
                        _buildDetailCard(
                          children: [
                            const Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color.fromARGB(255, 0, 0, 0),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSettingRow('Shuffle Questions', _shuffleQuestions),
                            const SizedBox(height: 8),
                            _buildSettingRow('Shuffle Choices', _shuffleChoices),
                            const SizedBox(height: 8),
                            _buildSettingRow('Single Response', _singleResponse),
                            const SizedBox(height: 8),
                            _buildSettingRow('Password Protected', _enablePassword),
                          ],
                        ),
                      const SizedBox(height: 20),
                      // Buttons
                      Column(
                        children: [
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(true),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color.fromARGB(255, 248, 248, 248),
                                      Color.fromARGB(255, 199, 199, 199),
                                      Color.fromARGB(255, 248, 248, 248),
                                      Color.fromARGB(255, 116, 116, 116),
                                      Color.fromARGB(242, 61, 61, 61),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Container(
                                  height: 40,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFF1F00),
                                        Color(0xFFDD1700),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: ShaderMask(
                                      shaderCallback: (bounds) {
                                        return const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [Color(0xFFE9E9E9), Color(0xFFFFFFFF)],
                                        ).createShader(bounds);
                                      },
                                      child: const Text(
                                        'Publish',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(false),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color.fromARGB(255, 248, 248, 248),
                                      Color.fromARGB(255, 199, 199, 199),
                                      Color.fromARGB(255, 248, 248, 248),
                                      Color.fromARGB(255, 116, 116, 116),
                                      Color.fromARGB(242, 61, 61, 61),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Container(
                                  height: 40,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF808080),
                                        Color(0xFF505050),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
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
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await FirestoreService().publishQuiz(quizId, true);
      await _load();
      if (!mounted) return;
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: SingleChildScrollView(
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: 360,
                  child: CustomPaint(
                    painter: _GradientPainter(
                      strokeWidth: 2,
                      radius: 20,
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.white],
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.fromARGB(228, 238, 238, 238),
                            Color.fromARGB(235, 173, 173, 173),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Quiz Published',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF222222),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your quiz is now published. Share the code below with participants:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDetailCard(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Quiz Code',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SelectableText(
                                    _quiz?.quizCode ?? '—',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF222222),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _quiz?.quizCode ?? '')).then((_) {
                                  if (!mounted) return;
                                  Navigator.of(context).pop();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color.fromARGB(255, 248, 248, 248),
                                      Color.fromARGB(255, 199, 199, 199),
                                      Color.fromARGB(255, 248, 248, 248),
                                      Color.fromARGB(255, 116, 116, 116),
                                      Color.fromARGB(242, 61, 61, 61),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Container(
                                  height: 40,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF222222),
                                        Color(0xFF1a1a1a),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.copy, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        ShaderMask(
                                          shaderCallback: (bounds) {
                                            return const LinearGradient(
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                              colors: [Color(0xFFE9E9E9), Color(0xFFFFFFFF)],
                                            ).createShader(bounds);
                                          },
                                          child: const Text(
                                            'Copy Code',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // indicate to caller that publishing occurred so they can refresh
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Failed to publish: $e', leading: Icons.error_outline);
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
            Color.fromARGB(255, 175, 175, 175),
          ],
        ),
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            await _saveQuizSettings(showSnack: false);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
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
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                title: Text(_quiz?.title ?? 'Edit Quiz', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
                actions: [
                  if (_quiz != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                      child: Tooltip(
                        message: (!_quiz!.published && _questions.isEmpty) ? 'Add at least one question before publishing' : '',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: (!_quiz!.published && _questions.isEmpty)
                                ? null
                                : _quiz!.published
                                    ? () async {
                                        if (!await _saveQuizSettings(showSnack: false)) return;
                                        await FirestoreService().publishQuiz(quizId, false);
                                        await _load();
                                      }
                                    : _publishQuiz,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color.fromARGB(255, 248, 248, 248),
                                    Color.fromARGB(255, 199, 199, 199),
                                    Color.fromARGB(255, 248, 248, 248),
                                    Color.fromARGB(255, 116, 116, 116),
                                    Color.fromARGB(242, 61, 61, 61),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Container(
                                height: 40,
                                width: 100,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.fromARGB(255, 241, 0, 0),
                                      Color.fromARGB(255, 233, 0, 0),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: ShaderMask(
                                    shaderCallback: (bounds) {
                                      return const LinearGradient(
                                        colors: [Color(0xFFE9E9E9), Color(0xFFFFFFFF)],
                                      ).createShader(bounds);
                                    },
                                    child: Text(
                                      _quiz!.published ? 'Unpublish' : 'Publish',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
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
            ? _buildSkeletonLoading()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_quiz != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: CustomPaint(
                          painter: _GradientPainter(
                            strokeWidth: 2,
                            radius: 8,
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.transparent,
                            ),
                            child: Text(
                              _quiz!.description,
                              style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 133, 133, 133)),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ),
                    if (_quiz != null && !_quiz!.published && _questions.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x000ffccc)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.info_outline, size: 20, color: Color.fromARGB(255, 109, 109, 109)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Add at least one question to enable Publish.',
                                style: TextStyle(color: Color.fromARGB(255, 71, 71, 71)),
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
                      suffix: 'mins',
                    ),
                    const SizedBox(height: 32),
                    const Text('Questions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF222222))),
                    const SizedBox(height: 12),
                    if (_questions.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No questions yet, add some!', style: TextStyle(color: Color.fromARGB(255, 126, 126, 126))))),
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

                        return _neumorphicQuestionCard(
                          key: ValueKey(q.id),
                          margin: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _neumorphicQuestionCard({
    required Widget child,
    double padding = 16,
    EdgeInsets margin = EdgeInsets.zero,
    Key? key,
  }) {
    return Container(
      key: key,
      margin: margin,
      child: CustomPaint(
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
      ),
    );
  }

  Widget _buildGradientTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? suffix,
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
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            filled: false,
            contentPadding: const EdgeInsets.fromLTRB(8, 14, 20, 14),
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

  Widget _buildDetailCard({required List<Widget> children}) {
    return CustomPaint(
      painter: _GradientPainter(
        strokeWidth: 1.5,
        radius: 12,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.fromARGB(255, 0, 0, 0), Color.fromARGB(255, 151, 151, 151), Color.fromARGB(255, 180, 180, 180), Color.fromARGB(255, 255, 255, 255)],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF222222),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String label, bool isEnabled) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
          ),
        ),
        Text(
          isEnabled ? 'Yes' : 'No',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isEnabled ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quiz Description Skeleton
          Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 16.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          // Quiz Settings Header
          Container(
            height: 20,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          // Settings Switches (4 items)
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 50,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Time Input Skeleton
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 32),
          // Questions Header
          Container(
            height: 24,
            width: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          // Question Cards (3 skeleton cards)
          for (int i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        height: 20,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 20,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
      