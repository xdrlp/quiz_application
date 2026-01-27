// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
// removed unused import
import 'package:provider/provider.dart';
import 'package:quiz_application/providers/auth_provider.dart';

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
    final Rect rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth);
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
  OverlayEntry? _topToastEntry;
  static final RegExp _emailRegExp = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+");

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
    _passwordFocus.addListener(() => _handleFocusChange(_passwordFocus, _passwordKey));
  }

  void _handleFocusChange(FocusNode node, GlobalKey key) {
    if (node.hasFocus) _ensureVisible(key);
  }

  void _ensureVisible(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.35, curve: Curves.easeInOut);
      }
    });
  }

  void _showTopToast(String message) {
    _topToastEntry?.remove();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        final topPadding = MediaQuery.of(context).padding.top + 8;
        return Positioned(
          top: topPadding,
          left: 16,
          right: 16,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade900,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
    _topToastEntry = entry;
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      if (_topToastEntry == entry) {
        _topToastEntry?.remove();
        _topToastEntry = null;
      }
    });
  }

  Future<void> _submit(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email and password.')));
      return;
    }
    final ok = await auth.login(email: email, password: password);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in')));
      // navigate home if your app expects that
      // Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Sign in failed')));
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
              padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
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
                        Color.fromARGB(228, 238, 238, 238), // White with 49% transparency
                        Color.fromARGB(235, 155, 155, 155), // #9b9b9b with 10.5% transparency
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
                      const SizedBox(height: 10),
                      // Lock Icon Circle
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFDDDDDD),
                              Color(0xFFFFFFFF),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 4,
                              offset: const Offset(-2, -2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.lock, size: 28, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter your email to reset your password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Dashed Line
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          children: List.generate(30, (index) => Expanded(
                            child: Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              color: Colors.black26,
                            ),
                          )),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Email Field Label
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
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
                            controller: dialogController,
                            cursorColor: Colors.black54,
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.email_outlined, color: Colors.black54),
                              filled: false,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
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
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFF0F0F0), Color(0xFFCCCCCC)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.6),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(dialogController.text.trim()),
                            borderRadius: BorderRadius.circular(22),
                            child: const Center(
                              child: Text(
                                'Reset password',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Cancel Button
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFFF3333), Color(0xFFCC0000)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            borderRadius: BorderRadius.circular(22),
                            child: const Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
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
    if (email.isEmpty && result != null) { // Only show error if they pressed Submit (returned a string)
       if (result.isEmpty) {
         _showTopToast('Please enter your email address.');
         return;
       }
    }
    
    // If dialog returns null, user cancelled or tapped outside
    if (result == null) return;

    if (!_emailRegExp.hasMatch(email)) {
      _showTopToast('Please enter a valid email address.');
      return;
    }
    final ok = await authProvider.requestPasswordReset(email: email);
    if (!mounted) return;
    if (ok) {
      _showTopToast('Password reset email sent. Please check your inbox (including spam).');
    } else {
      _showTopToast(authProvider.errorMessage ?? 'Failed to send reset email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 28, color: Colors.black),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 30),
              // Title
              const Text(
                'Hello,\nWelcome\nBack',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                  fontFamily: 'CanvaSans',
                ),
              ),
              const SizedBox(height: 60),
              
              // Email Field
              _buildTextField(
                controller: _emailController,
                focusNode: _emailFocus,
                hint: 'Email',
                icon: Icons.email_outlined,
                key: _emailKey,
              ),
              const SizedBox(height: 16),
              
              // Password Field
              _buildTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                hint: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
                key: _passwordKey,
              ),
              
              // Forgot Password
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      _showResetDialog(context);
                    },
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Color(0xFF424242),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Log In Button
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        _submit(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/red_login_button.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              // Sign Up Link
              Center(
                child: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.pushReplacementNamed(context, '/signup');
                  },
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                      children: [
                        TextSpan(
                          text: 'Sign up',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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
  }) {
    return CustomPaint(
      key: key,
      painter: _GradientPainter(
        strokeWidth: 2,
        radius: 12,
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
        height: 60,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword && !_passwordVisible,
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              border: InputBorder.none,
              icon: Icon(icon, color: Colors.black54),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black38),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
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

