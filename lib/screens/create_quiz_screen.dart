import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/firestore_service.dart';

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

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _timeController = TextEditingController();
  bool _loading = false;
  bool _shuffleQuestions = false;
  bool _shuffleChoices = false;
  bool _singleResponse = false;
  bool _enablePassword = false;
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _timeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final minutes = int.tryParse(_timeController.text) ?? 10;

    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a title')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final quiz = QuizModel(
        id: '',
        title: title,
        description: desc,
        timeLimitSeconds: minutes * 60,
        classIds: [],
        quizCode: _generateCode(),
        published: false,
        createdBy: user.uid,
        createdAt: DateTime.now(),
        totalQuestions: 0,
        randomizeQuestions: _shuffleQuestions,
        randomizeOptions: _shuffleChoices,
        singleResponse: _singleResponse,
        password: _enablePassword ? _passwordController.text.trim() : null,
      );

      final id = await FirestoreService().createQuiz(quiz);
      if (!mounted) return;
      setState(() => _loading = false);

      // After creating a quiz, immediately open the editor so the user can
      // add questions. The code dialog will be shown only when the quiz is
      // published (from the Edit screen).
      Navigator.of(context).pushReplacementNamed('/edit_quiz', arguments: id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating quiz: $e')),
      );
    }
  }

  String _generateCode() {
    final rnd = DateTime.now().millisecondsSinceEpoch.remainder(1000000);
    return rnd.toString().padLeft(6, '0');
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
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('Create Quiz', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'New Quiz Details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set basic information for your new quiz',
                  style: TextStyle(fontSize: 14, color: Color(0xFF7F8C8D)),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 32),
                _buildGradientTextField(
                  controller: _titleController,
                  hint: 'Title',
                  icon: Icons.title,
                ),
                const SizedBox(height: 16),
                _buildGradientTextField(
                  controller: _descController,
                  hint: 'Description',
                  icon: Icons.description,
                ),
                const SizedBox(height: 16),
                _buildGradientTextField(
                  controller: _timeController,
                  hint: 'e.g., 10 minutes',
                  icon: Icons.schedule,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Quiz Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF222222),
                  ),
                ),
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
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF222222),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Create', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF222222), fontSize: 16, fontWeight: FontWeight.w500))),
          Theme(
            data: ThemeData(
              useMaterial3: true,
              switchTheme: SwitchThemeData(
                thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.white;
                }),
                trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFFFFA500);
                  }
                  return const Color(0xFFBDBDBD);
                }),
              ),
            ),
            child: Switch(
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
