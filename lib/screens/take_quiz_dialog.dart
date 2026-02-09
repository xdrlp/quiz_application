import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/utils/snackbar_utils.dart';
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

class _GradientButton extends StatefulWidget {
  final VoidCallback onTap;
  final String text;
  final LinearGradient backgroundGradient;
  final List<Shadow>? textShadows;
  final double? height;

  const _GradientButton({
    required this.onTap,
    required this.text,
    required this.backgroundGradient,
    this.textShadows,
    this.height,
  });

  @override
  State<_GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<_GradientButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const double kButtonHeight = 44.0;
    final double available = MediaQuery.of(context).size.width - (32.0 * 2);
    final double buttonWidth = available > 360.0 ? 360.0 : available;
    final double height = widget.height ?? kButtonHeight;

    return Center(
      child: SizedBox(
        width: buttonWidth,
        height: height,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              transform: _isPressed 
                ? (Matrix4.identity()..scaleByVector3(vm.Vector3(0.98, 0.98, 1.0)))
                : Matrix4.identity(),
              transformAlignment: Alignment.center,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.fromARGB(
                      255,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                    ),
                    Color.fromARGB(
                      255,
                      _isHovered ? 215 : 199,
                      _isHovered ? 215 : 199,
                      _isHovered ? 215 : 199,
                    ),
                    Color.fromARGB(
                      255,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                      _isHovered ? 255 : 248,
                    ),
                    Color.fromARGB(
                      255,
                      _isHovered ? 130 : 116,
                      _isHovered ? 130 : 116,
                      _isHovered ? 130 : 116,
                    ),
                    Color.fromARGB(
                      242,
                      _isHovered ? 75 : 61,
                      _isHovered ? 75 : 61,
                      _isHovered ? 75 : 61,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: _isHovered || _isPressed
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  gradient: widget.backgroundGradient,
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
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        shadows: widget.textShadows,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// models imported via FirestoreService responses; no direct model types required here

Widget _buildDetailCard({required List<Widget> children}) {
  return CustomPaint(
    painter: _GradientPainter(
      strokeWidth: 2,
      radius: 12,
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: children,
      ),
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
          fontWeight: FontWeight.w500,
          color: Color.fromARGB(202, 0, 0, 0),
        ),
      ),
      Text(
        value,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF000000),
        ),
      ),
    ],
  );
}

class TakeQuizDialog extends StatefulWidget {
  const TakeQuizDialog({super.key});

  @override
  State<TakeQuizDialog> createState() => _TakeQuizDialogState();
}

class _TakeQuizDialogState extends State<TakeQuizDialog> {
  final TextEditingController codeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool showPasswordField = false;
  dynamic currentQuiz;
  bool passwordVisible = false;
  bool _showPreview = false;
  dynamic creator;
  int questionCount = 0;

  @override
  void dispose() {
    codeController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      codeController.text = data!.text!.trim();
    }
  }

  Future<void> handlePasswordSubmit() async {
    final enteredPassword = passwordController.text.trim();
    if (enteredPassword.isEmpty) return;

    // Verify password
    if (currentQuiz.password != enteredPassword) {
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Incorrect password', leading: Icons.error_outline);
      return;
    }

    // Password is correct, proceed to quiz summary
    setState(() => isLoading = true);
    try {
      creator = await FirestoreService().getUser(currentQuiz.createdBy);
      questionCount = currentQuiz.totalQuestions;
      try {
        if (questionCount == 0) {
          final qs = await FirestoreService().getQuizQuestions(currentQuiz.id);
          questionCount = qs.length;
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        isLoading = false;
        _showPreview = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Error loading quiz details', leading: Icons.error_outline);
    }
  }

  Future<void> takeQuiz() async {
    final code = codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final quiz = await FirestoreService().getQuizByCode(code);
      if (quiz == null) {
        if (!mounted) return;
        SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'No quiz found for that code', leading: Icons.error_outline);
        setState(() => isLoading = false);
        return;
      }

      currentQuiz = quiz;

      // Check if quiz has password
      if (quiz.password != null && quiz.password!.isNotEmpty) {
        setState(() {
          isLoading = false;
          showPasswordField = true;
        });
      } else {
        // No password, proceed directly
        setState(() => isLoading = false);

        creator = await FirestoreService().getUser(quiz.createdBy);
        questionCount = quiz.totalQuestions;
        try {
          if (questionCount == 0) {
            final qs = await FirestoreService().getQuizQuestions(quiz.id);
            questionCount = qs.length;
          }
        } catch (_) {}

        if (!mounted) return;
        setState(() => _showPreview = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Error fetching quiz', leading: Icons.error_outline);
    }
  }

  String normalizeDuplicateTrailingWords(String s) {
    final parts = s.trim().split(RegExp(r'\\s+'));
    if (parts.length >= 2 && parts[parts.length - 1] == parts[parts.length - 2]) {
      parts.removeLast();
    }
    return parts.join(' ');
  }

  String get authorName {
    final displayNameRaw = creator?.displayName ?? '';
    final firstName = creator?.firstName ?? '';
    final lastName = creator?.lastName ?? '';

    return (displayNameRaw.trim().isNotEmpty)
        ? normalizeDuplicateTrailingWords(displayNameRaw)
        : normalizeDuplicateTrailingWords('$firstName $lastName');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
            child: Container(color: Colors.transparent),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: 360,
                child: CustomPaint(
                  painter: _GradientPainter(
                    strokeWidth: 2,
                    radius: 24,
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color.fromARGB(255, 0, 0, 0),
                        Color(0xFFFFFFFF),
                        Color.fromARGB(255, 170, 170, 170),
                        Color(0xFFFFFFFF),
                        Color(0xFFFFFFFF),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
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
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromARGB(0, 0, 0, 0),
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _showPreview ? const SizedBox(height: 4) : const SizedBox(height: 12),
                          if (!_showPreview)
                            Text(
                              'Enter Quiz Code',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          if (!_showPreview) const SizedBox(height: 6),
                          if (!_showPreview)
                            const Text(
                              'Enter the 6-digit code to join the quiz',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),
                          const SizedBox(height: 12),
                          // Dashed Line
                          if (!_showPreview)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: List.generate(
                                  30,
                                  (index) => Expanded(
                                    child: Container(
                                      height: 1,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (!_showPreview) const SizedBox(height: 16),
                          // Quiz Code Field
                          if (!_showPreview)
                            CustomPaint(
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
                                  controller: codeController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  textAlign: TextAlign.left,
                                  textAlignVertical: TextAlignVertical.bottom,
                                  cursorColor: Colors.black54,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    suffixIcon: IconButton(
                                      icon: const Icon(
                                        Icons.paste_outlined,
                                        color: Colors.black54,
                                      ),
                                      onPressed: pasteFromClipboard,
                                    ),
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 15,
                                    ),
                                    hintText: 'Enter code',
                                    hintStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black38,
                                    ),
                                    counterText: '',
                                  ),
                                ),
                              ),
                            ),
                          if (!_showPreview) const SizedBox(height: 16),
                          // Password Field (Dynamic)
                          if (showPasswordField && !_showPreview)
                            CustomPaint(
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
                                  controller: passwordController,
                                  obscureText: !passwordVisible,
                                  cursorColor: Colors.black54,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        passwordVisible ? Icons.visibility : Icons.visibility_off,
                                        color: Colors.black54,
                                      ),
                                      onPressed: () {
                                        setState(() => passwordVisible = !passwordVisible);
                                      },
                                    ),
                                    filled: false,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                    hintText: 'Password',
                                    hintStyle: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (showPasswordField && !_showPreview) const SizedBox(height: 24),
                          // Preview Content
                          if (_showPreview) ...[
                            Text(
                              currentQuiz.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (currentQuiz.description.isNotEmpty)
                              Text(
                                currentQuiz.description,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            if (currentQuiz.description.isNotEmpty)
                              const SizedBox(height: 12),
                            if (currentQuiz.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Row(
                                  children: List.generate(
                                    30,
                                    (index) => Expanded(
                                      child: Container(
                                        height: 1,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        color: Colors.black26,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (currentQuiz.description.isNotEmpty)
                              const SizedBox(height: 16),
                            // Quiz Details Card
                            _buildDetailCard(
                              children: [
                                _buildDetailRow('Questions', '$questionCount'),
                                const SizedBox(height: 12),
                                _buildDetailRow('Author', authorName.isNotEmpty ? authorName : 'Unknown'),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                          // Take Quiz Button
                          if (!_showPreview && !showPasswordField && !isLoading)
                            _GradientButton(
                              onTap: takeQuiz,
                              text: 'Take Quiz',
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
                          // Submit Password Button
                          if (showPasswordField && !_showPreview)
                            _GradientButton(
                              onTap: handlePasswordSubmit,
                              text: 'Submit',
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
                          if (isLoading && !_showPreview) const CircularProgressIndicator(),
                          if (!_showPreview) const SizedBox(height: 12),
                          // Action Buttons for Preview
                          if (_showPreview) ...[
                            _GradientButton(
                              onTap: () {
                                Navigator.of(context).pushNamed('/take_quiz', arguments: currentQuiz.id);
                              },
                              text: 'Attempt Quiz',
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
                            const SizedBox(height: 12),
                            _GradientButton(
                              onTap: () {
                                setState(() {
                                  _showPreview = false;
                                  currentQuiz = null;
                                  creator = null;
                                  questionCount = 0;
                                });
                              },
                              text: 'Close',
                              backgroundGradient: const LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  Color(0xFF333333),
                                  Color(0xFF414141),
                                  Color(0xFF141414),
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
                          // Cancel Button
                          if (!_showPreview && !showPasswordField)
                            _GradientButton(
                              onTap: () => Navigator.of(context).pop(),
                              text: 'Cancel',
                              backgroundGradient: const LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  Color(0xFF333333),
                                  Color(0xFF414141),
                                  Color(0xFF141414),
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
                          // Back Button (for password screen)
                          if (showPasswordField && !_showPreview) ...[
                            const SizedBox(height: 12),
                            _GradientButton(
                              onTap: () {
                                passwordController.clear();
                                setState(() {
                                  showPasswordField = false;
                                  passwordVisible = false;
                                });
                              },
                              text: 'Back',
                              backgroundGradient: const LinearGradient(
                                begin: Alignment.centerRight,
                                end: Alignment.centerLeft,
                                colors: [
                                  Color(0xFF333333),
                                  Color(0xFF414141),
                                  Color(0xFF141414),
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
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> showTakeQuizDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => const TakeQuizDialog(),
  );
}
