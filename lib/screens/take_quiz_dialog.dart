import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
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

// models imported via FirestoreService responses; no direct model types required here

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
          color: Color(0xFF000000),
        ),
      ),
    ],
  );
}

Future<void> showTakeQuizDialog(BuildContext context) async {
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool showPasswordField = false;
  dynamic currentQuiz;
  bool passwordVisible = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
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
            if (!ctx.mounted) return;
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Incorrect password')));
            return;
          }

          // Password is correct, proceed to quiz summary
          setState(() => isLoading = true);
          try {
            final creator = await FirestoreService().getUser(currentQuiz.createdBy);
            int questionCount = currentQuiz.totalQuestions;
            try {
              if (questionCount == 0) {
                final qs = await FirestoreService().getQuizQuestions(currentQuiz.id);
                questionCount = qs.length;
              }
            } catch (_) {}

            if (!ctx.mounted) return;
            setState(() => isLoading = false);
            Navigator.of(ctx).pop();

            final nav = Navigator.of(context);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (sctx) {
                final displayNameRaw = creator?.displayName ?? '';
                final firstName = creator?.firstName ?? '';
                final lastName = creator?.lastName ?? '';

                String normalizeDuplicateTrailingWords(String s) {
                  final parts = s.trim().split(RegExp(r'\\s+'));
                  if (parts.length >= 2 && parts[parts.length - 1] == parts[parts.length - 2]) {
                    parts.removeLast();
                  }
                  return parts.join(' ');
                }

                final authorName = (displayNameRaw.trim().isNotEmpty)
                    ? normalizeDuplicateTrailingWords(displayNameRaw)
                    : normalizeDuplicateTrailingWords('$firstName $lastName');

                return Dialog(
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
                                      Color.fromARGB(251, 238, 238, 238),
                                      Color.fromARGB(251, 173, 173, 173),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  Text(
                                    currentQuiz.title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF000000),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  if (currentQuiz.description.isNotEmpty)
                                    Text(
                                      currentQuiz.description,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Color.fromARGB(202, 0, 0, 0),
                                        height: 1.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  if (currentQuiz.description.isNotEmpty)
                                    const SizedBox(height: 20),
                                  // Quiz Details Card
                                  _buildDetailCard(
                                    children: [
                                      _buildDetailRow('Questions', '$questionCount'),
                                      const SizedBox(height: 12),
                                      _buildDetailRow('Author', authorName.isNotEmpty ? authorName : 'Unknown'),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  // Action Buttons
                                  Column(
                                    children: [
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          onTap: () => Navigator.of(sctx).pop(true),
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
                                                    'Attempt Quiz',
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
                                          onTap: () => Navigator.of(sctx).pop(false),
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
                                                    'Close',
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
            },
          );
          if (confirmed == true) {
            nav.pushNamed('/take_quiz', arguments: currentQuiz.id);
            }
          } catch (e) {
            if (!ctx.mounted) return;
            setState(() => isLoading = false);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }

        Future<void> takeQuiz() async {
          final code = codeController.text.trim();
          if (code.isEmpty) return;
          setState(() => isLoading = true);
          try {
            final quiz = await FirestoreService().getQuizByCode(code);
            if (quiz == null) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('No quiz found for that code')));
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
              
              final creator = await FirestoreService().getUser(quiz.createdBy);
              int questionCount = quiz.totalQuestions;
              try {
                if (questionCount == 0) {
                  final qs = await FirestoreService().getQuizQuestions(quiz.id);
                  questionCount = qs.length;
                }
              } catch (_) {}

              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();

              final nav = Navigator.of(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (sctx) {
                  final displayNameRaw = creator?.displayName ?? '';
                  final firstName = creator?.firstName ?? '';
                  final lastName = creator?.lastName ?? '';

                  String normalizeDuplicateTrailingWords(String s) {
                    final parts = s.trim().split(RegExp(r'\\s+'));
                    if (parts.length >= 2 && parts[parts.length - 1] == parts[parts.length - 2]) {
                      parts.removeLast();
                    }
                    return parts.join(' ');
                  }

                  final authorName = (displayNameRaw.trim().isNotEmpty)
                      ? normalizeDuplicateTrailingWords(displayNameRaw)
                      : normalizeDuplicateTrailingWords('$firstName $lastName');

                  return Dialog(
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
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        quiz.title,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF000000),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      if (quiz.description.isNotEmpty)
                                        Text(
                                          quiz.description,
                                          style: const TextStyle(
                                            fontSize: 15,
                                          color: Color.fromARGB(202, 0, 0, 0),
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    if (quiz.description.isNotEmpty)
                                      const SizedBox(height: 20),
                                    // Quiz Details Card
                                    _buildDetailCard(
                                      children: [
                                        _buildDetailRow('Questions', '$questionCount'),
                                        const SizedBox(height: 12),
                                        _buildDetailRow('Author', authorName.isNotEmpty ? authorName : 'Unknown'),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Action Buttons
                                    Column(
                                      children: [
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () => Navigator.of(sctx).pop(true),
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
                                                      'Attempt Quiz',
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
                                            onTap: () => Navigator.of(sctx).pop(false),
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
                                                      'Close',
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
              },
            );
            if (confirmed == true) {
              nav.pushNamed('/take_quiz', arguments: currentQuiz.id);
              }
            }
          } catch (e) {
            if (!ctx.mounted) return;
            setState(() => isLoading = false);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }

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
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: 340,
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
                              const SizedBox(height: 12),
                              const Text(
                                'Enter Quiz Code',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
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
                              const SizedBox(height: 16),
                              // Quiz Code Field
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
                              const SizedBox(height: 16),
                              // Password Field (Dynamic)
                              if (showPasswordField)
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
                              if (showPasswordField) const SizedBox(height: 24),
                              // Take Quiz Button
                              if (!showPasswordField && !isLoading)
                                SizedBox(
                                  height: 50,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          'assets/images/takeQuiz_button.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: takeQuiz,
                                            borderRadius: BorderRadius.circular(25),
                                            splashColor: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            highlightColor: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Submit Password Button
                              if (showPasswordField)
                                SizedBox(
                                  height: 50,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          'assets/images/takeQuiz_button.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: handlePasswordSubmit,
                                            borderRadius: BorderRadius.circular(25),
                                            splashColor: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            highlightColor: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isLoading && !showPasswordField) const CircularProgressIndicator(),
                              if (!showPasswordField) const SizedBox(height: 2),
                              // Cancel Button
                              if (!showPasswordField)
                                SizedBox(
                                  height: 50,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          'assets/images/cancel_button2.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => Navigator.of(ctx).pop(),
                                            borderRadius: BorderRadius.circular(25),
                                            splashColor: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            highlightColor: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // Back Button (for password screen)
                              if (showPasswordField)
                                const SizedBox(height: 2),
                              if (showPasswordField)
                                SizedBox(
                                  height: 50,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.asset(
                                          'assets/images/cancel_button2.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              passwordController.clear();
                                              setState(() {
                                                showPasswordField = false;
                                                passwordVisible = false;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(25),
                                            splashColor: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            highlightColor: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
      });
    },
  );
}
