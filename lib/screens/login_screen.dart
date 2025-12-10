// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
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
  final _confirmController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  bool _isLogin = true;
  DateTime? _verificationSentAt;
  Timer? _verificationPollTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _verificationPollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Periodically refresh the verificationSentAt from Firestore so cooldown
    // state persists across devices/tabs. Poll every 5 seconds.
    _fetchVerificationSentAt();
    _verificationPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchVerificationSentAt();
    });
  }

  Future<void> _fetchVerificationSentAt() async {
    final authProvider = mounted ? context.read<AuthProvider>() : null;
    if (authProvider == null) return;
    try {
      final sent = await authProvider.getVerificationSentAt();
      if (!mounted) return;
      setState(() {
        _verificationSentAt = sent;
      });
    } catch (_) {
      // ignore failures silently; banner will still allow resend locally
    }
  }

  int _resendCooldownRemainingSeconds() {
    if (_verificationSentAt == null) return 0;
    final since = DateTime.now().difference(_verificationSentAt!);
    const cooldown = Duration(seconds: 60);
    final remaining = cooldown - since;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  Future<void> _submit(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text;

        if (_isLogin) {
            final success = await authProvider.login(email: email, password: password);
            if (!mounted) return;
            if (!success) {
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(content: Text(authProvider.errorMessage ?? 'Login failed')));
                return;
            }
            // If the account isn't verified show verification dialog, otherwise enter app
            if (!authProvider.isEmailVerified) {
                await _showVerifyDialog();
                return;
            }
            if (mounted) navigator.pushReplacementNamed('/home');
        } else {
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final confirm = _confirmController.text;
        if (password != confirm) {
        if (!mounted) return;
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Passwords do not match')));
        return;
      }
      final success = await authProvider.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );

      if (!mounted) return;
      if (!mounted) return;
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authProvider.errorMessage ?? 'Sign up failed')));
        return;
      }
      // After successful sign up we present the verification dialog.
      await _showVerifyDialog();
    }

  
  }

  Future<void> _showVerifyDialog() async {
    final authProvider = context.read<AuthProvider>();
    final initialSentAt = await authProvider.getVerificationSentAt();
    if (!mounted) return;

    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VerifyDialog(initialSentAt: initialSentAt),
    );

    if (result == true && mounted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent. Please check your inbox.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Sign in' : 'Create account')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            if (authProvider.isAuthenticated && !authProvider.isEmailVerified)
              Card(
                color: Theme.of(context).colorScheme.secondary.withAlpha(15),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Email not verified', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Your account is not verified. Please check your email (including your spam/junk folder) or resend the verification link.'),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              // Resend appears as a small link when enabled, or as a chip showing remaining seconds when disabled.
                              if (_resendCooldownRemainingSeconds() > 0)
                                Chip(label: Text('Resend (${_resendCooldownRemainingSeconds()})'))
                              else
                                TextButton(
                                  onPressed: () async {
                                    final ok = await authProvider.resendVerification();
                                    if (!mounted) return;
                                    if (!ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to resend verification')));
                                      return;
                                    }
                                    await _fetchVerificationSentAt();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email resent.')));
                                  },
                                  child: const Text('Resend'),
                                ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => _showVerifyDialog(),
                                child: const Text('Open verification dialog'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(44),
                                  ),
                                  onPressed: () async {
                                    final ok = await authProvider.reloadAndCheckVerified();
                                    if (!mounted) return;
                                    if (ok) {
                                      Navigator.of(context).pushReplacementNamed('/home');
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email still not verified.')));
                                    }
                                  },
                                  child: const Text('Check verification status'),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // rest of fields
            TextField(
                  controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
                const SizedBox(height: 12),
                    const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (!_isLogin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
              const SizedBox(height: 12),
            ],
            // Forgot password placed above the Sign In button
            if (_isLogin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    final parentContext = context;
                    final authProvider = parentContext.read<AuthProvider>();
                    String email = _emailController.text.trim();
                    if (email.isEmpty) {
                      final controller = TextEditingController();
                      final result = await showDialog<String?>(
                        context: parentContext,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Reset password'),
                          content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter your email')),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                            ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()), child: const Text('Send')),
                          ],
                        ),
                      );
                      if (result == null || result.isEmpty) return;
                      email = result;
                    }
                    final messenger = ScaffoldMessenger.of(parentContext);
                    final ok = await authProvider.requestPasswordReset(email: email);
                    if (!mounted) return;
                    if (ok) {
                      messenger.showSnackBar(const SnackBar(content: Text('Password reset email sent. Please check your inbox (including spam).')));
                    } else {
                      messenger.showSnackBar(SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to send reset email')));
                    }
                  },
                  child: const Text('Forgot password?'),
                ),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _submit(context),
              child: Text(_isLogin ? 'Sign In' : 'Sign Up'),
            ),
            const SizedBox(height: 8),
            // Toggle between sign in and sign up
            TextButton(
              onPressed: () {
                setState(() => _isLogin = !_isLogin);
              },
              child: Text(_isLogin ? 'Create account' : 'Have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyDialog extends StatefulWidget {
  final DateTime? initialSentAt;
  const _VerifyDialog({this.initialSentAt});

  @override
  State<_VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends State<_VerifyDialog> {
  static const expiryDuration = Duration(minutes: 5);
  static const resendCooldown = Duration(seconds: 60);

  Timer? _timer;
  DateTime? _sentAt;
  bool _resendDisabled = false;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sentAt = widget.initialSentAt;
    _startTimer();
  }

  void _startTimer() {
    _updateState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(_updateState);
    });
  }

  void _updateState() {
    final now = DateTime.now();
    if (_sentAt != null) {
      final expiry = _sentAt!.add(expiryDuration);
      _remaining = expiry.difference(now);
      if (_remaining.isNegative) _remaining = Duration.zero;

      final sinceSent = now.difference(_sentAt!);
      _resendDisabled = sinceSent < resendCooldown;
    } else {
      _remaining = Duration.zero;
      _resendDisabled = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();

    return AlertDialog(
      title: const Text('Verify your email'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A verification link was sent to your email.'),
          const SizedBox(height: 8),
          if (_remaining > Duration.zero)
            Text('Link expires in ${_formatDuration(_remaining)}')
          else
            const Text('Link expired. Please resend.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _resendDisabled
              ? null
              : () async {
                  final navigator = Navigator.of(context);
                  final ok = await authProvider.resendVerification();
                  if (!mounted) return;
                  if (!ok) {
                    // show the provider's friendly error
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authProvider.errorMessage ?? 'Failed to resend verification')));
                    return;
                  }
                  setState(() {
                    _sentAt = DateTime.now();
                    _updateState();
                  });
                  if (!mounted) return;
                  navigator.pop(true);
                },
          child: Text(_resendDisabled ? 'Resend (wait)' : 'Resend'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
 
