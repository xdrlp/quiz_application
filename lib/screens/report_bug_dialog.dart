import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:quiz_application/utils/snackbar_utils.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

// Button constants
const double _kHorizontalPadding = 32.0;
const double _kButtonHeight = 44.0;

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
  final VoidCallback? onTap;
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
    final double available =
        MediaQuery.of(context).size.width - (_kHorizontalPadding * 2);
    final double buttonWidth = available > 360.0 ? 360.0 : available;

    return Center(
      child: SizedBox(
        width: buttonWidth,
        height: widget.height ?? _kButtonHeight,
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

class ReportBugDialog extends StatefulWidget {
  final String screenName;

  const ReportBugDialog({super.key, this.screenName = 'unknown'});

  @override
  State<ReportBugDialog> createState() => _ReportBugDialogState();
}

class _ReportBugDialogState extends State<ReportBugDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final ScrollController _scrollController;
  double _prevBottomInset = 0.0;
  bool _isSubmitting = false;
  late final HttpsCallable _sendBugReportCallable;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _titleCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _scrollController = ScrollController();
    _sendBugReportCallable = FirebaseFunctions.instance.httpsCallable(
      'sendBugReport',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || title.isEmpty || description.isEmpty) {
      SnackBarUtils.showThemedSnackBar(messenger, 'Please complete all fields before submitting.', leading: Icons.error_outline);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _sendBugReportCallable.call({
        'name': name,
        'email': email,
        'title': title,
        'description': description,
        'screen': widget.screenName,
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      if (!mounted) return;

      SnackBarUtils.showThemedSnackBar(messenger, 'Report submitted successfully! Auto-closing...', leading: Icons.check_circle_outline);

      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      final message = e.message ?? 'Unable to send the bug report.';
      SnackBarUtils.showThemedSnackBar(messenger, message, leading: Icons.error_outline);
    } catch (e) {
      SnackBarUtils.showThemedSnackBar(messenger, 'Unable to send the bug report.', leading: Icons.error_outline);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    // Scroll back to top when keyboard closes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_prevBottomInset > 0 && bottomInset == 0) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
      _prevBottomInset = bottomInset;
    });

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Builder(
          builder: (msgContext) => Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: isKeyboardOpen
                        ? const ClampingScrollPhysics()
                        : const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: isKeyboardOpen ? bottomInset + 20 : 20,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: CustomPaint(
                        painter: _GradientPainter(
                          strokeWidth: 2,
                          radius: 24,
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color(0xFF181818),
                              Color(0xFFFFFFFF),
                              Color(0xFFC3B8B8),
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
                                  Color.fromARGB(
                                    228,
                                    238,
                                    238,
                                    238,
                                  ), // White with 49% transparency
                                  Color.fromARGB(
                                    235,
                                    155,
                                    155,
                                    155,
                                  ), // #9b9b9b with 10.5% transparency
                                ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 32),
                                const Text(
                                  'Report a bug',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Please tell us what went wrong.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Dashed Line
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
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
                                const SizedBox(height: 20),

                                // Form Fields
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildLabel('Name*'),
                                      _buildTextField(
                                        controller: _nameCtrl,
                                        hint: 'Enter your full name',
                                      ),
                                      const SizedBox(height: 12),
                                      _buildLabel('Email*'),
                                      _buildTextField(
                                        controller: _emailCtrl,
                                        hint: 'Enter your email address',
                                        keyboardType:
                                            TextInputType.emailAddress,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildLabel('Title*'),
                                      _buildTextField(
                                        controller: _titleCtrl,
                                        hint: 'Short summary of the problem',
                                      ),
                                      const SizedBox(height: 12),
                                      _buildLabel('Description*'),
                                      _buildTextField(
                                        controller: _descCtrl,
                                        hint:
                                            'Provide details about the problem you encountered.',
                                        maxLines: 5,
                                        height: 120,
                                      ),
                                      const SizedBox(height: 24),

                                      // Buttons
                                      _GradientButton(
                                        onTap: _isSubmitting
                                            ? null
                                            : () async {
                                                FocusScope.of(
                                                  msgContext,
                                                ).unfocus();
                                                await _submitReport();
                                              },
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
                                        height: 36.0,
                                      ),
                                      const SizedBox(height: 12),
                                      _GradientButton(
                                        onTap: () {
                                          FocusScope.of(msgContext).unfocus();
                                          Navigator.of(msgContext).pop();
                                        },
                                        text: 'Cancel',
                                        backgroundGradient: const LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Color.fromARGB(235, 78, 78, 78),
                                            Color.fromARGB(232, 58, 58, 58),
                                            Color.fromARGB(232, 49, 49, 49)                                       ],
                                        ),
                                        textShadows: const [
                                          Shadow(
                                            color: Color.fromARGB(255, 0, 0, 0),
                                            offset: Offset(1.2, 1.2),
                                            blurRadius: 0.5,
                                          ),
                                        ],
                                        height: 36.0,
                                      ),
                                      const SizedBox(height: 24),
                                    ],
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: RichText(
        text: TextSpan(
          text: text.substring(0, text.length - 1),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
          children: [
            TextSpan(
              text: text.substring(text.length - 1),
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int? maxLines = 1,
    double? height,
  }) {
    return CustomPaint(
      painter: _GradientPainter(
        strokeWidth: 2,
        radius: 10,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000), // #000000
            Color(0xFF484848), // #484848
            Color(0xFFFFFDFD), // #fffdfd
            Color(0xFFD5D5D5), // #d5d5d5
            Color(0xFF7C7979), // #7c7979
            Color(0xFFFFFFFF), // #ffffff
            Color(0xFFFFFFFF), // #ffffff
          ],
        ),
      ),
      child: Container(
        height: height,
        padding: const EdgeInsets.all(2),
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
          maxLines: maxLines,
          cursorColor: Colors.black54,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            border: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0x8A000000),
            ),
          ),
          ),
        ),
      ),
    );
  }
}
