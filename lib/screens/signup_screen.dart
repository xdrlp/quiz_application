import 'package:flutter/material.dart';
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

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _isCreatingAccount = false;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleCreateAccount() async {
    if (_isCreatingAccount) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final firstName = _firstController.text.trim();
    final lastName = _lastController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmController.text;

    if ([
      email,
      firstName,
      lastName,
      password,
      confirmPassword,
    ].any((v) => v.isEmpty)) {
      _showMessage('All fields are required.');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => _isCreatingAccount = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.signUp(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    if (!mounted) return;
    setState(() => _isCreatingAccount = false);

    if (success) {
      _showMessage('Account created successfully!');
      Navigator.pop(context);
    } else {
      _showMessage(auth.errorMessage ?? 'Sign up failed.');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Widget _buildGradientTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    bool isPassword = false,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _GradientPainter(
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
        child: Center(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            cursorColor: Colors.black87,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black38),
              prefixIcon: Icon(icon, color: Colors.black54),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black54,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Padding(
            padding: EdgeInsets.only(left: 6.0),
            child: Icon(Icons.arrow_back_ios, color: Colors.black87),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Let's get\nstarted!",
                            style: TextStyle(
                              fontFamily: 'MuseoModerno',
                              fontSize: 54,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'First time here? Let’s set up your account.',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildGradientTextField(
                            controller: _firstController,
                            hint: 'First Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 20),
                          _buildGradientTextField(
                            controller: _lastController,
                            hint: 'Last Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 20),
                          _buildGradientTextField(
                            controller: _emailController,
                            hint: 'Email',
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 20),
                          _buildGradientTextField(
                            controller: _passwordController,
                            hint: 'Password',
                            icon: Icons.lock_outline,
                            obscureText: !_passwordVisible,
                            isPassword: true,
                            onToggleVisibility: () => setState(
                              () => _passwordVisible = !_passwordVisible,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildGradientTextField(
                            controller: _confirmController,
                            hint: 'Confirm Password',
                            icon: Icons.lock_outline,
                            obscureText: !_confirmPasswordVisible,
                            isPassword: true,
                            onToggleVisibility: () => setState(
                              () => _confirmPasswordVisible =
                                  !_confirmPasswordVisible,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Center(
                            child: SizedBox(
                              height: 60,
                              child: _isCreatingAccount
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    )
                                  : Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Image.asset(
                                            'assets/images/create_account_button.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: _handleCreateAccount,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              splashColor: Colors.black
                                                  .withValues(alpha: 0.3),
                                              highlightColor: Colors.black
                                                  .withValues(alpha: 0.1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Already have an account? ",
                                style: TextStyle(
                                  color: Color.fromARGB(206, 0, 0, 0),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                ),
                                child: const Text(
                                  'Login here',
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
        ],
      ),
      ),
    );
  }
}
