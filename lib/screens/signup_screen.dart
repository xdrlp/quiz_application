// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  double _prevBottomInset = 0.0;
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  // Focus nodes and keys for ensuring visibility of fields when keyboard opens
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _firstFocus = FocusNode();
  final FocusNode _lastFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  final GlobalKey _emailKey = GlobalKey();
  final GlobalKey _firstKey = GlobalKey();
  final GlobalKey _lastKey = GlobalKey();
  final GlobalKey _passwordKey = GlobalKey();
  final GlobalKey _confirmKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _firstController.dispose();
    _lastController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailFocus.dispose();
    _firstFocus.dispose();
    _lastFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }
  bool _passwordVisible = false;
  // Tweakable constants for overlay scaling and input positioning
  final double _overlayScale = 1.1; // 1.0 = native 1920x1080 scale; increase to make art larger
  bool _confirmPasswordVisible = false;
  // Per-widget manual nudges for debug elements (edit these to move the sign-in box)

  // (Create-account position/size are now specified inline at the Positioned widget.)

  void _createAccount() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create account tapped')));
  }

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => _handleFocusChange(_emailFocus, _emailKey));
    _firstFocus.addListener(() => _handleFocusChange(_firstFocus, _firstKey));
    _lastFocus.addListener(() => _handleFocusChange(_lastFocus, _lastKey));
    _passwordFocus.addListener(() => _handleFocusChange(_passwordFocus, _passwordKey));
    _confirmFocus.addListener(() => _handleFocusChange(_confirmFocus, _confirmKey));
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
              children: [
                // Static background image (covers the whole screen)
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/background.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade900),
                  ),
                ),

                // Scrollable form while keeping background static
                Positioned.fill(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                    // manage behavior when keyboard opens/closes and only allow user scroll when keyboard open
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
                      // keep a consistent top spacing so elements don't jump to the very top
                      padding: const EdgeInsets.only(left: 0, right: 0, top: 30.0, bottom: 0),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        // compute overlay height from 16:9 aspect ratio
                        child: Builder(builder: (ctx) {
                          final double overlayHeight = constraints.maxWidth * (1080 / 1920);
                          // Stack overlay image and input column so inputs appear above the art
                          return SizedBox(
                            width: constraints.maxWidth,
                            height: overlayHeight + 800, // extra space for inputs below
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  child: Image.asset(
                                    'assets/images/sign_up_elements.png',
                                    width: constraints.maxWidth * _overlayScale,
                                    fit: BoxFit.fitWidth,
                                    alignment: Alignment.topCenter,
                                    errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                  ),
                                ),
                                // Absolute-positioned tappable area for Create Account.
                                // Edit `createButtonLeft`, `createButtonTop`, `createButtonWidth`, `createButtonHeight` at the top of this file.
                                // Create-account button (edit the numeric values here)
                                Positioned(
                                  left: 34,
                                  top: 576,
                                  width: 325,
                                  height: 38,
                                  child: Material(
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    borderRadius: BorderRadius.circular(5),
                                    child: InkWell(
                                      onTap: _createAccount,
                                      splashColor: const Color.fromARGB(53, 50, 50, 50),
                                      highlightColor: const Color.fromARGB(0, 0, 0, 0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color.fromARGB(0, 0, 0, 0),
                                        ),
                                        child: const Center(
                                          child: Text('Create account', style: TextStyle(color: Color.fromARGB(0, 255, 255, 255), fontWeight: FontWeight.w700)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Back action retained but visual back icon hidden.
                                // Keeps the tappable area so the screen still pops when tapped,
                                // but the icon is not shown.
                                Positioned(
                                  left: 12,
                                  top: -10,
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
                                // Inputs placed on top of the overlay. Adjust the `top` value to nudge vertically.
                                Positioned(
                                  left: 80,
                                  right: 20,
                                  top: 227,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        key: _emailKey,
                                        child: SizedBox(
                                          height: 56,
                                          child: TextField(
                                            focusNode: _emailFocus,
                                            controller: _emailController,
                                            cursorColor: Colors.black,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Email',
                                              hintStyle: TextStyle(color: Color(0x803E3B36), fontWeight: FontWeight.bold),
                                            ),
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold), 
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        key: _firstKey,
                                        child: SizedBox(
                                          height: 56,
                                          child: TextField(
                                            focusNode: _firstFocus,
                                            controller: _firstController,
                                            cursorColor: Colors.black,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'First name',
                                              hintStyle: TextStyle(color: Color(0x803E3B36), fontWeight: FontWeight.bold),
                                            ),
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        key: _lastKey,
                                        child: SizedBox(
                                          height: 56,
                                          child: TextField(
                                            focusNode: _lastFocus,
                                            controller: _lastController,
                                            cursorColor: Colors.black,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              hintText: 'Last name',
                                              hintStyle: TextStyle(color: Color(0x803E3B36), fontWeight: FontWeight.bold),
                                            ),
                                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Container(
                                        key: _passwordKey,
                                        child: SizedBox(
                                          height: 56,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  focusNode: _passwordFocus,
                                                  controller: _passwordController,
                                                  cursorColor: Colors.black,
                                                  obscureText: !_passwordVisible,
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    hintText: 'Password',
                                                    hintStyle: TextStyle(color: Color(0x803E3B36), fontWeight: FontWeight.bold),
                                                  ),
                                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(right: 18.0),
                                                child: IconButton(
                                                  icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility, color: Color.fromRGBO(0, 0, 0, 0.41)),
                                                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        key: _confirmKey,
                                        child: SizedBox(
                                          height: 56,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  focusNode: _confirmFocus,
                                                  controller: _confirmController,
                                                  cursorColor: Colors.black,
                                                  obscureText: !_confirmPasswordVisible,
                                                  decoration: const InputDecoration(
                                                    border: InputBorder.none,
                                                    hintText: 'Confirm password',
                                                    hintStyle: TextStyle(color: Color(0x803E3B36), fontWeight: FontWeight.bold),
                                                  ),
                                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(right: 18.0),
                                                child: IconButton(
                                                  icon: Icon(_confirmPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Color.fromRGBO(0, 0, 0, 0.41)),
                                                  onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      const SizedBox(height: 56),
                                      const SizedBox(height: 12),
                                      // tappable overlay moved outside the Column (see below)
                                      // Debug-visible tappable area for Sign in — fixed width via Align + SizedBox
                                      Align(
                                        widthFactor: 1.0,
                                        alignment: Alignment.centerLeft,
                                        child: Transform.translate(
                                          offset: const Offset(30, -18),
                                          child: SizedBox(
                                            width: 180, // adjust desired width here
                                            height: 36,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  FocusScope.of(context).unfocus();
                                                  Navigator.pushReplacementNamed(context, '/login');
                                                },
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromARGB(0, 255, 0, 0),
                                                    border: Border.all(color: const Color.fromARGB(0, 255, 82, 82)),
                                                    borderRadius: BorderRadius.circular(6),
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
                              ],
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

