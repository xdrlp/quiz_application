import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:quiz_application/services/firestore_service.dart';

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
  bool _isEditing = false;

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
    } else {
      // if there is no Firestore-backed profile, prefill from Firebase Auth so UI shows values
      final f = fb.FirebaseAuth.instance.currentUser;
      if (f != null) {
        final base = f.displayName ?? f.email?.split('@').first ?? '';
        final parts = base.split(' ');
        _firstController.text = parts.isNotEmpty ? parts.first : '';
        _lastController.text = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        _classController.text = '';
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // If there is no Firestore profile yet, create one. Otherwise update existing profile.
    if (auth.currentUser == null) {
      final fuser = fb.FirebaseAuth.instance.currentUser;
      if (fuser == null) {
        messenger.showSnackBar(const SnackBar(content: Text('No signed-in user')));
        return;
      }
      final fs = FirestoreService();
      final newUser = UserModel(
        uid: fuser.uid,
        email: fuser.email ?? '',
        displayName: fuser.displayName ?? '',
        firstName: _firstController.text.trim(),
        lastName: _lastController.text.trim(),
        classSection: _classController.text.trim().isEmpty ? null : _classController.text.trim(),
        createdAt: DateTime.now(),
      );
      try {
        await fs.createUser(fuser.uid, newUser);
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text('Profile created')));
        await auth.reloadAndCheckVerified();
        setState(() => _isEditing = false);
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Failed to create profile: $e')));
      }
      return;
    }

    final ok = await auth.updateProfile(
      firstName: _firstController.text.trim(),
      lastName: _lastController.text.trim(),
      classSection: _classController.text.trim().isEmpty ? null : _classController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
      setState(() => _isEditing = false);
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
      body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    // Header: if we have a full user model show it, otherwise fall back to auth user
                    Builder(builder: (ctx) {
                      if (user != null) {
                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 56,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(_initials(user), style: const TextStyle(fontSize: 28, color: Colors.white)),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.displayName.isNotEmpty ? user.displayName : '${user.firstName} ${user.lastName}'.trim(),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(user.email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                            const SizedBox(height: 16),
                          ],
                        );
                      }
                      final fu = fb.FirebaseAuth.instance.currentUser;
                      final displayName = fu?.displayName ?? '';
                      final email = fu?.email ?? '';
                      final uid = fu?.uid ?? '';
                      final initials = (displayName.isNotEmpty ? displayName : email.isNotEmpty ? email : uid).trim();
                      final initialLetter = initials.isNotEmpty ? initials.substring(0, 1).toUpperCase() : '?';
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 56,
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(initialLetter, style: const TextStyle(fontSize: 28, color: Colors.white)),
                          ),
                          const SizedBox(height: 12),
                          Text(displayName.isNotEmpty ? displayName : (email.isNotEmpty ? email.split('@').first : uid), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(height: 12),
                        ],
                      );
                    }),

                    // Show a single polished profile details card (prefilled from Firestore or Firebase Auth)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Profile details', style: TextStyle(fontWeight: FontWeight.bold)),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = !_isEditing;
                                      if (!_isEditing) {
                                        final u = auth.currentUser;
                                        _firstController.text = u?.firstName ?? _firstController.text;
                                        _lastController.text = u?.lastName ?? _lastController.text;
                                        _classController.text = u?.classSection ?? _classController.text;
                                      }
                                    });
                                  },
                                  child: Text(_isEditing ? 'Cancel' : 'Edit'),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_isEditing)
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _firstController,
                                      decoration: const InputDecoration(labelText: 'First name'),
                                      validator: (v) => v == null || v.trim().isEmpty ? 'Please enter first name' : null,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _lastController,
                                      decoration: const InputDecoration(labelText: 'Last name'),
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _classController,
                                      decoration: const InputDecoration(labelText: 'Class / Section (optional)'),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: auth.isLoading ? null : _save,
                                      child: auth.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('First name'),
                                    subtitle: Text(user?.firstName.isNotEmpty == true ? user!.firstName : _firstController.text.isNotEmpty ? _firstController.text : '-'),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Last name'),
                                    subtitle: Text(user?.lastName.isNotEmpty == true ? user!.lastName : _lastController.text.isNotEmpty ? _lastController.text : '-'),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Class / Section'),
                                    subtitle: Text(user?.classSection ?? (_classController.text.isNotEmpty ? _classController.text : '-')),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () async {
                                      await auth.logout();
                                      if (!mounted) return;
                                      Navigator.of(context).pushReplacementNamed('/login');
                                    },
                                    child: const Text('Sign out'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),

                    // If we DO have a full model, show the editable details card below
                    if (user != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Profile details', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isEditing = !_isEditing;
                                        if (!_isEditing) {
                                          // refresh controllers from model
                                          _firstController.text = user.firstName;
                                          _lastController.text = user.lastName;
                                          _classController.text = user.classSection ?? '';
                                        }
                                      });
                                    },
                                    child: Text(_isEditing ? 'Cancel' : 'Edit'),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_isEditing)
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _firstController,
                                        decoration: const InputDecoration(labelText: 'First name'),
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Please enter first name' : null,
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _lastController,
                                        decoration: const InputDecoration(labelText: 'Last name'),
                                      ),
                                      const SizedBox(height: 8),
                                      TextFormField(
                                        controller: _classController,
                                        decoration: const InputDecoration(labelText: 'Class / Section (optional)'),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: auth.isLoading ? null : _save,
                                        child: auth.isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('First name'),
                                      subtitle: Text(user.firstName.isNotEmpty ? user.firstName : '-'),
                                    ),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Last name'),
                                      subtitle: Text(user.lastName.isNotEmpty ? user.lastName : '-'),
                                    ),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Class / Section'),
                                      subtitle: Text(user.classSection ?? '-'),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () async {
                                        await auth.logout();
                                        if (!mounted) return;
                                        Navigator.of(context).pushReplacementNamed('/login');
                                      },
                                      child: const Text('Sign out'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
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
