import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/firestore_service.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

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
  
  // Error state variables
  String? _titleError;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
    _timeController.text = '10'; // Default to 10 minutes
  }

  Future<void> _loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _shuffleQuestions = prefs.getBool('default_shuffle_questions') ?? false;
      _shuffleChoices = prefs.getBool('default_shuffle_options') ?? false;
      _singleResponse = prefs.getBool('default_single_response') ?? false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _timeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Clear previous errors
    setState(() {
      _titleError = null;
      _timeError = null;
    });

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final minutes = int.tryParse(_timeController.text) ?? 10;

    // Validate title
    if (title.isEmpty) {
      setState(() => _titleError = 'Required');
      return;
    }

    // Validate time limit
    if (minutes > 999) {
      setState(() => _timeError = 'Max 999 minutes');
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222), letterSpacing: 0.5)),
                        if (_titleError != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(_titleError!, style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F), fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildGradientTextField(
                      controller: _titleController,
                      hint: 'Title',
                      icon: Icons.title,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(99),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGradientTextField(
                  controller: _descController,
                  hint: 'Description',
                  icon: Icons.description,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(249),
                  ],
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Time Limit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF222222), letterSpacing: 0.5)),
                        if (_timeError != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(_timeError!, style: const TextStyle(fontSize: 12, color: Color(0xFFD32F2F), fontWeight: FontWeight.w500)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildGradientTextField(
                      controller: _timeController,
                      hint: 'e.g., 10 (Max 999)',
                      icon: Icons.schedule,
                      keyboardType: TextInputType.number,
                      suffixText: 'mins',
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(
                  color: Color(0xFF9E9E9E),
                  thickness: 1.5,
                  height: 1,
                ),
                const SizedBox(height: 24),
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
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _GradientButton(
                        onTap: _submit,
                        text: 'Create',
                        backgroundGradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFF1F00),
                            Color(0xFFDD1700),
                          ],
                        ),
                        textShadows: const [
                          Shadow(
                            color: Color.fromARGB(255, 0, 0, 0),
                            offset: Offset(1.2, 1.2),
                            blurRadius: 0.5,
                          ),
                        ],
                        height: 44.0,
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
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
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
        child: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: Colors.grey.withAlpha(150),
              selectionHandleColor: Colors.grey,
            ),
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
            selectionControls: materialTextSelectionControls,
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: Icon(icon, color: Colors.black54),
              suffix: suffixText != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        suffixText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : null,
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
