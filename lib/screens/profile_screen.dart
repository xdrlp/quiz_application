import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/models/user_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstController = TextEditingController();
  final _lastController = TextEditingController();
  final _classController = TextEditingController();

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _classController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user != null) {
      _firstController.text = user.firstName;
      _lastController.text = user.lastName;
      _classController.text = user.classSection ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await auth.updateProfile(
      firstName: _firstController.text.trim(),
      lastName: _lastController.text.trim(),
      classSection: _classController.text.trim().isEmpty ? null : _classController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Failed to update profile')));
    }
  }

  // Profile picture/upload features removed per user request.

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final UserModel? user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? const Center(child: Text('No user'))
            : Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            child: Text(_initials(user)),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstController,
                      decoration: const InputDecoration(labelText: 'First name'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter first name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastController,
                      decoration: const InputDecoration(labelText: 'Last name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _classController,
                      decoration: const InputDecoration(labelText: 'Class / Section (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: user.email,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: auth.isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      child: auth.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        // Prefill forgot-password flow for this user's email
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await auth.requestPasswordReset(email: user.email);
                        if (!mounted) return;
                        if (ok) {
                          messenger.showSnackBar(const SnackBar(content: Text('Password reset email sent')));
                        } else {
                          messenger.showSnackBar(SnackBar(content: Text(auth.errorMessage ?? 'Failed to send reset email')));
                        }
                      },
                      child: const Text('Change password'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        await auth.logout();
                        if (!mounted) return;
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      child: const Text('Sign out'),
                    ),
                    // Sync status button removed — sync runs automatically.
                  ],
                ),
              ),
      ),
    );
  }

  String _initials(UserModel user) {
    final String f = user.firstName.trim();
    final String l = user.lastName.trim();
    if (f.isEmpty && l.isEmpty) return user.email.substring(0, 1).toUpperCase();
    if (l.isEmpty) return f.substring(0, 1).toUpperCase();
    return (f.substring(0, 1) + l.substring(0, 1)).toUpperCase();
  }
}
