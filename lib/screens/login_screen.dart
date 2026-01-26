// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
// removed unused import
import 'package:provider/provider.dart';
import 'package:quiz_application/providers/auth_provider.dart';

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
  double _prevBottomInset = 0.0;
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
    final result = await showGeneralDialog<String?>(
      context: parentContext,
      barrierDismissible: true,
      barrierLabel: 'ResetPassword',
      barrierColor: const Color.fromRGBO(0, 0, 0, 0.25),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
                child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                child: Container(color: Colors.transparent),
              ),
            ),
            Center(
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: SizedBox(
                  width: 360,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/images/reset_password_bg.png', fit: BoxFit.cover),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 65.0, vertical: 28.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 180),
                              Container(
                                height: 52,
                                color: Colors.transparent,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: dialogController,
                                        cursorColor: Colors.black,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Email',
                                          hintStyle: TextStyle(color: Color(0x803E3B36)),
                                        ),
                                        style: const TextStyle(color: Colors.black),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 36,
                        right: 28,
                        bottom: 78,
                        height: 30,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(dialogController.text.trim()),
                            borderRadius: BorderRadius.circular(28),
                            splashColor: Colors.white24,
                            highlightColor: Colors.white10,
                            child: Container(),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 36,
                        right: 28,
                        bottom: 34,
                        height: 30,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            borderRadius: BorderRadius.circular(28),
                            splashColor: Colors.white24,
                            highlightColor: Colors.white10,
                            child: Container(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    String email = _emailController.text.trim();
    if (result != null && result.isNotEmpty) email = result;
    if (email.isEmpty) {
      _showTopToast('Please enter your email address.');
      return;
    }
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
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/background.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade900),
                  ),
                ),

                

                Positioned.fill(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_prevBottomInset > 0 && bottomInset == 0) {
                        if (_scrollController.hasClients) {
                          final double minExtent = _scrollController.position.minScrollExtent;
                          try {
                            _scrollController.animateTo(minExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                          } catch (_) {
                            _scrollController.jumpTo(minExtent);
                          }
                        }
                      }
                      _prevBottomInset = bottomInset;
                    });

                    final bool isKeyboardOpen = bottomInset > 0.0;

                    return SingleChildScrollView(
                      controller: _scrollController,
                      physics: isKeyboardOpen ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(left: 0, right: 0, top: 30.0, bottom: 0),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        // compute overlay height from 16:9 aspect ratio
                        child: Builder(builder: (ctx) {
                          final double overlayHeight = constraints.maxWidth * (1080 / 1920);
                          return SizedBox(
                            width: constraints.maxWidth,
                            height: overlayHeight + 800,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: Image.asset(
                                    'assets/images/login_elements.png',
                                    width: constraints.maxWidth,
                                    fit: BoxFit.fitWidth,
                                    alignment: Alignment.topCenter,
                                    errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                  ),
                                ),
                                // Sign-in tappable overlay
                                Positioned(
                                  left: 34,
                                  right: 34,
                                  bottom: 515,
                                  height: 37,
                                  child: Material(
                                    borderRadius: BorderRadius.circular(8),
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    child: InkWell(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        _submit(context);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      splashColor: const Color.fromARGB(108, 15, 15, 15),
                                      highlightColor: const Color.fromARGB(0, 0, 0, 0),
                                      child: Container(),
                                    ),
                                  ),
                                ),
                                // Absolute-positioned tappable area for the "Forgot password" artwork element.
                                Positioned(
                                  left: 260, // adjust X here
                                  top: 412, // adjust Y here
                                  width: 110,
                                  height: 30,
                                  child: Material(
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    child: InkWell(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        _showResetDialog(context);
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(),
                                    ),
                                  ),
                                ),
                                // Debug tappable overlay for the "Don't have an account? Sign up" artwork.
                                Positioned(
                                  left: 110, // adjust X here
                                  top: 520, // adjust Y here
                                  width: 180,
                                  height: 30,
                                  child: Material(
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    child: InkWell(
                                      onTap: () {
                                        FocusScope.of(context).unfocus();
                                        Navigator.pushReplacementNamed(context, '/signup');
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(),
                                    ),
                                  ),
                                ),
                                // Absolute-positioned email field so X/Y can be adjusted directly
                                Positioned(
                                  left: 85, // adjust X here
                                  right: 56,
                                  top: 292, // adjust Y here
                                  height: 56,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: TextField(
                                      key: _emailKey,
                                      focusNode: _emailFocus,
                                      controller: _emailController,
                                      cursorColor: Colors.black,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: 'Email',
                                        hintStyle: TextStyle(
                                          color: Color(0x803E3B36),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                // Absolute-positioned password field so X/Y can be adjusted directly
                                Positioned(
                                  left: 85, // adjust X here
                                  right: 20, // reduced inset so icon can move further right
                                  top: 358, // adjust Y here
                                  height: 56,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            key: _passwordKey,
                                            focusNode: _passwordFocus,
                                            controller: _passwordController,
                                            cursorColor: Colors.black,
                                            obscureText: !_passwordVisible,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Password',
                                              hintStyle: TextStyle(
                                                color: Color(0x803E3B36),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(right: 15.0),
                                          child: IconButton(
                                            icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility, color: Color.fromARGB(104, 0, 0, 0)),
                                            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
                // Back button in the upper-left corner (ripple on tap) - placed last so it's tappable
                Positioned(
                  left: 12,
                  top: 12,
                  width: 48,
                  height: 48,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(24),
                      splashColor: Colors.white24,
                      child: Semantics(
                        label: 'Back',
                        button: true,
                        child: Center(child: SizedBox.shrink()),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

