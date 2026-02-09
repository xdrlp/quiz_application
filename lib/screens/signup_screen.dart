import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/utils/snackbar_utils.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

// Button constants
const double _kHorizontalPadding = 32.0;
const double _kButtonHeight = 44.0;

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
  String? _firstError;
  String? _lastError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  Future<void> _handleCreateAccount() async {
    if (_isCreatingAccount) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _firstError = null;
      _lastError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });

    final email = _emailController.text.trim();
    final firstName = _firstController.text.trim();
    final lastName = _lastController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmController.text;

    if (firstName.isEmpty) {
      setState(() => _firstError = 'Required');
      return;
    }
    if (lastName.isEmpty) {
      setState(() => _lastError = 'Required');
      return;
    }
    if (email.isEmpty) {
      setState(() => _emailError = 'Required');
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Required');
      return;
    }
    if (confirmPassword.isEmpty) {
      setState(() => _confirmError = 'Required');
      return;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Min 6 characters');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _confirmError = 'Passwords do not match');
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
      SnackBarUtils.showThemedSnackBar(
        ScaffoldMessenger.of(context),
        'Account created successfully!',
        leading: Icons.check_circle_outline,
        duration: const Duration(seconds: 1),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      SnackBarUtils.showThemedSnackBar(
        ScaffoldMessenger.of(context),
        auth.errorMessage ?? 'Sign up failed.',
        leading: Icons.error_outline,
      );
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
    String? error,
  }) {
    return Container(
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
        child: TextField(
          controller: controller,
          obscureText: obscureText,
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
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.black54,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
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
                            error: _firstError,
                          ),
                          const SizedBox(height: 20),
                          _buildGradientTextField(
                            controller: _lastController,
                            hint: 'Last Name',
                            icon: Icons.person_outline,
                            error: _lastError,
                          ),
                          const SizedBox(height: 20),
                          _buildGradientTextField(
                            controller: _emailController,
                            hint: 'Email',
                            icon: Icons.email_outlined,
                            error: _emailError,
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
                            error: _passwordError,
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
                            error: _confirmError,
                          ),
                          const SizedBox(height: 40),
                          _isCreatingAccount
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : _GradientButton(
                                  onTap: _handleCreateAccount,
                                  text: 'Create Account',
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
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 6,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
