import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/providers/quiz_provider.dart';
import 'package:quiz_application/models/user_model.dart';
import 'package:quiz_application/models/quiz_model.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:quiz_application/services/firestore_service.dart';
import 'package:quiz_application/services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // Generic image manipulation
import 'dart:math' as math;
import 'package:quiz_application/utils/snackbar_utils.dart';
import 'starter_screen.dart';

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
  final _yearLevelController = TextEditingController();
  bool _isEditing = false;
  bool _isUploading = false;
  bool _loaded = false;

  @override
  void dispose() {
    _firstController.dispose();
    _lastController.dispose();
    _classController.dispose();
    _yearLevelController.dispose();
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
      _yearLevelController.text = user.yearLevel ?? '';
      
      if (!_loaded) {
        _loaded = true;
        // Defer to next frame to avoid building during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<QuizProvider>().loadUserQuizzes(user.uid);
          }
        });
      }
    } else {
      // if there is no Firestore-backed profile, prefill from Firebase Auth so UI shows values
      final f = fb.FirebaseAuth.instance.currentUser;
      if (f != null) {
        final base = f.displayName ?? f.email?.split('@').first ?? '';
        final parts = base.split(' ');
        _firstController.text = parts.isNotEmpty ? parts.first : '';
        _lastController.text = parts.length > 1
            ? parts.sublist(1).join(' ')
            : '';
        _classController.text = '';
        _yearLevelController.text = '';
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
        SnackBarUtils.showThemedSnackBar(messenger, 'No signed-in user', leading: Icons.error_outline);
        return;
      }
      final fs = FirestoreService();
      final newUser = UserModel(
        uid: fuser.uid,
        email: fuser.email ?? '',
        displayName: fuser.displayName ?? '',
        firstName: _firstController.text.trim(),
        lastName: _lastController.text.trim(),
        classSection: _classController.text.trim().isEmpty
            ? null
            : _classController.text.trim(),
        yearLevel: _yearLevelController.text.trim().isEmpty
            ? null
            : _yearLevelController.text.trim(),
        createdAt: DateTime.now(),
      );
      try {
        await fs.createUser(fuser.uid, newUser);
        if (!mounted) return;
        SnackBarUtils.showThemedSnackBar(messenger, 'Profile created', leading: Icons.check_circle_outline);
        await auth.reloadAndCheckVerified();
        setState(() => _isEditing = false);
      } catch (e) {
        if (!mounted) return;
        SnackBarUtils.showThemedSnackBar(messenger, 'Failed to create profile: $e', leading: Icons.error_outline);
      }
      return;
    }

    final ok = await auth.updateProfile(
      firstName: _firstController.text.trim(),
      lastName: _lastController.text.trim(),
      classSection: _classController.text.trim().isEmpty
          ? null
          : _classController.text.trim(),
      yearLevel: _yearLevelController.text.trim().isEmpty
          ? null
          : _yearLevelController.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      SnackBarUtils.showThemedSnackBar(messenger, 'Profile updated', leading: Icons.check_circle_outline);
      setState(() => _isEditing = false);
    } else {
      SnackBarUtils.showThemedSnackBar(messenger, auth.errorMessage ?? 'Failed to update profile', leading: Icons.error_outline);
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

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    // Prevent double-taps or reentry
    setState(() => _isUploading = true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      
      if (picked == null) {
        setState(() => _isUploading = false);
        return;
      }

      // 2. Read, Convert/Compress to JPEG
      final bytes = await picked.readAsBytes();

      // Use 'image' package to decode and re-encode as JPEG to ensure format
      // and optional compression.
      final cmd = img.Command()
        ..decodeImage(bytes)
        ..encodeJpg(quality: 85); // Compress 85%
      
      final processedBytes = await cmd.getBytesThread();

      if (processedBytes == null) {
        throw Exception('Failed to process image');
      }

      final len = processedBytes.length;
      if (len > 1024 * 1024) {
         if (!mounted) return;
         SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Image is too large (${(len / 1024).round()}KB). Max 1MB.', leading: Icons.error_outline);
         return;
      }
      
      final storage = StorageService();
      // Since we re-encoded, we know it's a JPEG
      final url = await storage.uploadProfileImage(user.uid, processedBytes);

      await auth.updateProfile(
        firstName: user.firstName,
        lastName: user.lastName,
        classSection: user.classSection,
        yearLevel: user.yearLevel,
        photoUrl: url,
      );

      if (mounted) {
        SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Profile picture updated', leading: Icons.check_circle_outline);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showThemedSnackBar(ScaffoldMessenger.of(context), 'Failed to upload image: $e', leading: Icons.error_outline);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Profile picture/upload features removed per user request.

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final QuizProvider quizProvider = context.watch<QuizProvider>();
    final UserModel? user = auth.currentUser;

    final quizzes = quizProvider.userQuizzes;
    final createdCount = quizzes.length;
    final publishedCount = quizzes.where((q) => q.published).length;
    final draftsCount = quizzes.where((q) => !q.published).length;
    final recent = List<QuizModel>.from(quizzes)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color.fromARGB(255, 197, 197, 197),
          ],
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
                colors: [
                  Color.fromARGB(255, 179, 179, 179),
                  Color.fromARGB(255, 255, 255, 255),
                ],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              color: const Color.fromARGB(255, 240, 240, 240),
              child: AppBar(
                scrolledUnderElevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                // Profile Header
                Builder(
                  builder: (ctx) {
                    final u = user;
                    String initial = '?';
                    String name = '';
                    String email = '';

                    if (u != null) {
                      initial = _initials(u);
                      name = u.displayName.isNotEmpty
                          ? u.displayName
                          : '${u.firstName} ${u.lastName}'.trim();
                      email = u.email;
                    } else {
                      final fu = fb.FirebaseAuth.instance.currentUser;
                      email = fu?.email ?? '';
                      final d = fu?.displayName ?? '';
                      name = d.isNotEmpty
                          ? d
                          : (email.isNotEmpty ? email.split('@').first : '');
                      initial = name.isNotEmpty
                          ? name.substring(0, 1).toUpperCase()
                          : '?';
                    }

                    return Column(
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _isUploading ? null : _pickAndUploadImage,
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF000000),
                                        Color.fromARGB(255, 160, 160, 160),
                                        Color.fromARGB(255, 223, 223, 223),
                                        Color(0xFFFFFFFF),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    boxShadow: [],
                                  ),
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.white,
                                    backgroundImage:
                                        (u?.photoUrl != null)
                                            ? NetworkImage(u!.photoUrl!)
                                            : null,
                                    child:
                                        _isUploading
                                            ? const CircularProgressIndicator(
                                              color: Colors.black,
                                            )
                                            : (u?.photoUrl != null
                                                ? null
                                                : Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    fontSize: 40,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF222222),
                                                  ),
                                                )),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF222222),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                            color: Color(0xFF7F8C8D),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),

                // Profile Details Section
                _neumorphicContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Profile details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isEditing ? Icons.close : Icons.edit,
                              color: Colors.black54,
                            ),
                            onPressed: () {
                              setState(() {
                                _isEditing = !_isEditing;
                                if (!_isEditing) {
                                  // Reset fields if canceling
                                  if (user != null) {
                                    _firstController.text = user.firstName;
                                    _lastController.text = user.lastName;
                                    _classController.text =
                                        user.classSection ?? '';
                                    _yearLevelController.text =
                                        user.yearLevel ?? '';
                                  }
                                } else {
                                  // Populate fields if starting edit
                                  if (user != null) {
                                    _firstController.text = user.firstName;
                                    _lastController.text = user.lastName;
                                    _classController.text =
                                        user.classSection ?? '';
                                    _yearLevelController.text =
                                        user.yearLevel ?? '';
                                  }
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(color: Color.fromARGB(76, 0, 0, 0)),
                      const SizedBox(height: 16),
                      if (_isEditing)
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              _gradientBorderedField(
                                controller: _firstController,
                                label: 'First name',
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Please enter first name'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _gradientBorderedField(
                                controller: _lastController,
                                label: 'Last name',
                              ),
                              const SizedBox(height: 16),
                              _gradientBorderedField(
                                controller: _classController,
                                label: 'Class / Section',
                              ),
                              const SizedBox(height: 16),
                              _gradientBorderedField(
                                controller: _yearLevelController,
                                label: 'Year Level',
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(255, 78, 78, 78),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: [
                            _infoRow(
                              'First name',
                              user?.firstName.isNotEmpty == true
                                  ? user!.firstName
                                  : (_firstController.text.isNotEmpty
                                        ? _firstController.text
                                        : '-'),
                            ),
                            _infoRow(
                              'Last name',
                              user?.lastName.isNotEmpty == true
                                  ? user!.lastName
                                  : (_lastController.text.isNotEmpty
                                        ? _lastController.text
                                        : '-'),
                            ),
                            _infoRow(
                              'Class / Section',
                              user?.classSection ??
                                  (_classController.text.isNotEmpty
                                      ? _classController.text
                                      : '-'),
                            ),
                            _infoRow(
                              'Year Level',
                              user?.yearLevel ??
                                  (_yearLevelController.text.isNotEmpty
                                      ? _yearLevelController.text
                                      : '-'),
                            ),
                            const SizedBox(height: 24),
                            Center(
                              child: SizedBox(
                                height: 45,
                                width: double.infinity,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.asset(
                                        'assets/images/signOut_button.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: _handleSignOut,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          splashColor: Colors.black.withValues(
                                            alpha: 0.3,
                                          ),
                                          highlightColor: Colors.black
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _neumorphicContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Usage / Metrics',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      const Divider(color: Color.fromARGB(76, 0, 0, 0)),
                      const SizedBox(height: 16),
                      _infoRow('Quizzes created', '$createdCount Created'),
                      _infoRow(
                        'Quizzes published',
                        '$publishedCount Published',
                      ),
                      _infoRow('Drafts', '$draftsCount Drafts'),
                      const SizedBox(height: 16),
                      const Text(
                        'Recent activity',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 121, 121, 121),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (recent.isEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: CustomPaint(
                            painter: _GradientPainter(
                              strokeWidth: 2,
                              radius: 14,
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black, Colors.white],
                              ),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'No recent activity',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color.fromARGB(255, 139, 139, 139),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: List.generate(
                            math.min(5, recent.length),
                            (i) {
                              final q = recent[i];
                              final ago = _relativeTime(q.createdAt);
                              return Container(
                                key: ValueKey(q.id),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: CustomPaint(
                                  painter: _GradientPainter(
                                    strokeWidth: 2,
                                    radius: 14,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.black, Colors.white],
                                    ),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () {
                                          Navigator.of(context).pushNamed('/edit_quiz', arguments: q.id);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(q.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color.fromARGB(220, 34, 34, 34))),
                                                    const SizedBox(height: 4),
                                                    Text(ago, style: const TextStyle(fontSize: 11, color: Color.fromARGB(255, 139, 139, 139))),
                                                  ],
                                                ),
                                              ),
                                              Text(q.published ? 'Published' : 'Draft', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 59, 59, 59))),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.chevron_right, color: Color.fromARGB(255, 141, 141, 141), size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _neumorphicContainer({required Widget child}) {
    return CustomPaint(
      painter: _GradientPainter(
        strokeWidth: 2,
        radius: 24,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF000000),
            Color.fromARGB(255, 187, 187, 187),
            Color.fromARGB(255, 173, 173, 173),
            Color(0xFFFFFFFF),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ),
    );
  }

  Widget _gradientBorderedField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
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
              Color(0xFF000000),
              Color(0xFF484848),
              Color(0xFFFFFDFD),
              Color(0xFFD5D5D5),
              Color(0xFF7C7979),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
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
          child: TextFormField(
            controller: controller,
            validator: validator,
            style: const TextStyle(color: Colors.black87, fontSize: 16),
            cursorColor: Colors.black87,
            selectionControls: materialTextSelectionControls,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: label,
              hintStyle: const TextStyle(color: Colors.black54),
            ),
          ),
        ),
      ),
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
              style: const TextStyle(color: Color.fromARGB(178, 37, 37, 37), fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
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

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 48) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
