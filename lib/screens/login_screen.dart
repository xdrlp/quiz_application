// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as vm;
// removed unused import
import 'package:provider/provider.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/utils/snackbar_utils.dart';

// Button constants
const double _kHorizontalPadding = 32.0;
const double _kButtonHeight = 44.0;

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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  // Scroll / keyboard handling reused from signup screen
  final ScrollController _scrollController = ScrollController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final GlobalKey _emailKey = GlobalKey();
  final GlobalKey _passwordKey = GlobalKey();
  static final RegExp _emailRegExp = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+");
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _emailFocus.addListener(() => _handleFocusChange(_emailFocus, _emailKey));
    _passwordFocus.addListener(
      () => _handleFocusChange(_passwordFocus, _passwordKey),
    );
  }

  void _handleFocusChange(FocusNode node, GlobalKey key) {
    if (node.hasFocus) _ensureVisible(key);
  }

  void _ensureVisible(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          alignment: 0.35,
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _submit(BuildContext context) async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _emailError = 'Required');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Required');
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = await auth.login(email: email, password: password);
    if (!mounted) return;
    if (!ok) {
      SnackBarUtils.showThemedSnackBar(
        ScaffoldMessenger.of(context),
        auth.errorMessage ?? 'Sign in failed',
        leading: Icons.error_outline,
      );
    } else {
      SnackBarUtils.showThemedSnackBar(
        ScaffoldMessenger.of(context),
        'Signed in successfully',
        leading: Icons.check_circle_outline,
        duration: const Duration(milliseconds: 500),
      );
      // Ensure navigation to home so user isn't stuck on the login screen
      // in environments where auth state events may be delayed/blocked.
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  Future<void> _showResetDialog(BuildContext parentContext) async {
    final authProvider = parentContext.read<AuthProvider>();
    final dialogController = TextEditingController();

    // Helper builder for the dialog
    Widget buildResetDialog(BuildContext dialogContext) {
      return Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: 340,
                  child: CustomPaint(
                    painter: GradientPainter(
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
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            const Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Enter your email to reset your password',
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

                            // Email Field Label
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 4,
                                ),
                                child: RichText(
                                  text: const TextSpan(
                                    text: 'Email Address',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF333333),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '*',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // Email TextField
                            CustomPaint(
                              painter: GradientPainter(
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
                                  controller: dialogController,
                                  cursorColor: Colors.black54,
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: Colors.black54,
                                    ),
                                    filled: false,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    hintText: 'Email',
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Reset Password Button
                            _GradientButton(
                              onTap: () => Navigator.of(
                                dialogContext,
                              ).pop(dialogController.text.trim()),
                              text: 'Reset Password',
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

                            // Cancel Button
                            _GradientButton(
                              onTap: () =>
                                  Navigator.of(dialogContext).pop(),
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
                              height: 36.0,
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
    }

    final result = await showGeneralDialog<String?>(
      context: parentContext,
      barrierDismissible: true,
      barrierLabel: 'ResetPassword',
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.25),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return buildResetDialog(dialogContext);
      },
    );

    String email = _emailController.text.trim();
    if (result != null && result.isNotEmpty) email = result;
    if (email.isEmpty && result != null) {
      // Only show error if they pressed Submit (returned a string)
      if (result.isEmpty) {
        Navigator.of(parentContext).pop();
        if (!mounted) return;
        SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Please enter your email address.', leading: Icons.error_outline);
        return;
      }
    }

    // If dialog returns null, user cancelled or tapped outside
    if (result == null) return;

    if (!_emailRegExp.hasMatch(email)) {
      Navigator.of(parentContext).pop();
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Please enter a valid email address.', leading: Icons.error_outline);
      return;
    }
    final ok = await authProvider.requestPasswordReset(email: email);
    if (!mounted) return;
    if (ok) {
      Navigator.of(parentContext).pop();
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Password reset email sent. Please check your inbox (including spam).', leading: Icons.check_circle_outline);
    } else {
      Navigator.of(parentContext).pop();
      if (!mounted) return;
      SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), authProvider.errorMessage ?? 'Failed to send reset email', leading: Icons.error_outline);
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      const SizedBox(height: 20),
                      const Text(
                        "Hello,\nWelcome\nBack",
                        style: TextStyle(
                          fontFamily: 'MuseoModerno',
                          fontSize: 54,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to pick up where you left off',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildTextField(
                        controller: _emailController,
                        focusNode: _emailFocus,
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        key: _emailKey,
                        error: _emailError,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        key: _passwordKey,
                        error: _passwordError,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            bottom: 24.0,
                          ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              _showResetDialog(context);
                            },
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                      _GradientButton(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _submit(context);
                        },
                        text: 'Log in',
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
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              color: Color.fromARGB(197, 0, 0, 0),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pushReplacementNamed(
                                context,
                                '/signup',
                              );
                            },
                            child: const Text(
                              'Sign up',
                              style: TextStyle(
                                color: Color.fromARGB(255, 0, 0, 0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                          const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 15,
              left: 8,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required GlobalKey key,
    String? error,
  }) {
    return Container(
      key: key,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: GradientPainter(
          strokeWidth: 2,
          radius: 8,
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
        child: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: Colors.grey.withAlpha(150),
              selectionHandleColor: Colors.grey,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword && !_passwordVisible,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            cursorColor: Colors.black87,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: error != null ? '$hint - $error' : hint,
              hintStyle: TextStyle(
                color: Colors.black38,
                fontSize: error != null ? 14 : 16,
              ),
              prefixIcon: Icon(icon, color: Colors.black54),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.black54,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
