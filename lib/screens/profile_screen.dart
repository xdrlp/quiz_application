import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:quiz_application/services/firestore_service.dart';
import 'starter_screen.dart';

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

  Future<void> _handleSignOut() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const StarterScreen()),
      (route) => false,
    );
  }

  // Profile picture/upload features removed per user request.

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final UserModel? user = auth.currentUser;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.fromARGB(255, 255, 255, 255), Color.fromARGB(217, 255, 255, 255)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromARGB(255, 169, 169, 169), Color.fromARGB(255, 255, 255, 255)],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color.fromARGB(108, 244, 244, 244), Color.fromARGB(205, 223, 223, 223)],
                ),
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text('Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // Profile Header
                Builder(builder: (ctx) {
                  final u = user;
                  String initial = '?';
                  String name = '';
                  String email = '';

                  if (u != null) {
                    initial = _initials(u);
                    name = u.displayName.isNotEmpty ? u.displayName : '${u.firstName} ${u.lastName}'.trim();
                    email = u.email;
                  } else {
                    final fu = fb.FirebaseAuth.instance.currentUser;
                    email = fu?.email ?? '';
                    final d = fu?.displayName ?? '';
                    name = d.isNotEmpty ? d : (email.isNotEmpty ? email.split('@').first : '');
                    initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
                  }

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2C3E50), Color(0xFFBDC3C7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          child: Text(
                            initial,
                            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                      ),
                      const SizedBox(height: 4),
                      Text(email, style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 16)),
                      const SizedBox(height: 32),
                    ],
                  );
                }),

                // Profile Details Section
                _neumorphicContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Profile details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                          IconButton(
                            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: Colors.black54),
                            onPressed: () {
                              setState(() {
                                _isEditing = !_isEditing;
                                if (!_isEditing) {
                                  // Reset fields if canceling
                                  if (user != null) {
                                    _firstController.text = user.firstName;
                                    _lastController.text = user.lastName;
                                    _classController.text = user.classSection ?? '';
                                  }
                                } else {
                                  // Populate fields if starting edit
                                  if (user != null) {
                                    _firstController.text = user.firstName;
                                    _lastController.text = user.lastName;
                                    _classController.text = user.classSection ?? '';
                                  }
                                }
                              });
                            },
                          )
                        ],
                      ),
                      const Divider(color: Colors.black12),
                      const SizedBox(height: 16),
                      if (_isEditing)
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _firstController,
                                decoration: _inputDecoration('First name'),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter first name' : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _lastController,
                                decoration: _inputDecoration('Last name'),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _classController,
                                decoration: _inputDecoration('Class / Section'),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2C3E50),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 2,
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            _infoRow('First name', user?.firstName.isNotEmpty == true ? user!.firstName : (_firstController.text.isNotEmpty ? _firstController.text : '-')),
                            _infoRow('Last name', user?.lastName.isNotEmpty == true ? user!.lastName : (_lastController.text.isNotEmpty ? _lastController.text : '-')),
                            _infoRow('Class / Section', user?.classSection ?? (_classController.text.isNotEmpty ? _classController.text : '-')),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _handleSignOut,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFC0392B)),
                                  foregroundColor: const Color(0xFFC0392B),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _neumorphicContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(2), // Thinner border
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.black12], // Subtle border gradient
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.8),
            blurRadius: 10,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5), // Solid light background for the card itself
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF7F8C8D)),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2C3E50), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF7F8C8D), fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
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
