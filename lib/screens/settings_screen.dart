import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quiz_application/providers/auth_provider.dart';
import 'package:quiz_application/services/local_violation_store.dart';
import 'package:quiz_application/screens/report_bug_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification Preferences
  bool _notifySubmission = true;
  bool _notifyResultUpdate = true;

  // Quiz Creation Defaults
  bool _defaultShuffleQuestions = false;
  bool _defaultShuffleOptions = false;
  bool _defaultSingleResponse = false;

  // App Info
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppInfo();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Load local defaults
    if (!mounted) return;
    
    // Load user preferences from AuthProvider (Firestore) if available
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    
    setState(() {
      if (user != null) {
        _notifySubmission = user.notifySubmission;
        _notifyResultUpdate = user.notifyResultUpdate;
      }
      _defaultShuffleQuestions = prefs.getBool('default_shuffle_questions') ?? false;
      _defaultShuffleOptions = prefs.getBool('default_shuffle_options') ?? false;
      _defaultSingleResponse = prefs.getBool('default_single_response') ?? false;
    });
  }

  Future<void> _updateNotificationPref(bool submission, bool result) async {
    setState(() {
      _notifySubmission = submission;
      _notifyResultUpdate = result;
    });
    // Save to Firestore via AuthProvider
    await context.read<AuthProvider>().updateNotificationPreferences(
      notifySubmission: submission,
      notifyResultUpdate: result,
    );
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${info.version} (Build ${info.buildNumber})';
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _clearCache() async {
    try {
      await LocalViolationStore.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App cache cleared successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear cache: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data (quizzes, attempts, profile) will be permanently lost.',
          style: TextStyle(color: Color(0xFF555555), fontSize: 15),
        ),
        backgroundColor: Color(0xFFFAFAFA),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF222222))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.deleteAccount();
      if (mounted && authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${authProvider.errorMessage}')),
        );
      } else if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/splash', (route) => false);
      }
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
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
            Color.fromARGB(255, 197, 197, 197),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(65),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color.fromARGB(255, 179, 179, 179), Color.fromARGB(255, 255, 255, 255)],
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
                  'Settings',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Notification Preferences Section
                _buildSectionHeader('Notification Preferences'),
                const SizedBox(height: 12),
                _buildSettingItemCard(
                  title: 'Quiz Submission Alerts',
                  subtitle: 'Get notified when someone submits your quiz',
                  child: _buildSettingSwitch(
                    _notifySubmission,
                    (v) => _updateNotificationPref(v, _notifyResultUpdate),
                  ),
                ),
                const SizedBox(height: 10),
                _buildSettingItemCard(
                  title: 'Result Updates',
                  subtitle: 'Get notified when your answers are re-evaluated',
                  child: _buildSettingSwitch(
                    _notifyResultUpdate,
                    (v) => _updateNotificationPref(_notifySubmission, v),
                  ),
                ),
                const SizedBox(height: 32),
                // Quiz Creation Defaults Section
                _buildSectionHeader('Quiz Creation Defaults'),
                const SizedBox(height: 12),
                _buildSettingItemCard(
                  title: 'Shuffle Questions',
                  subtitle: 'Randomize question order by default',
                  child: _buildSettingSwitch(
                    _defaultShuffleQuestions,
                    (v) {
                      setState(() => _defaultShuffleQuestions = v);
                      _saveBool('default_shuffle_questions', v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _buildSettingItemCard(
                  title: 'Shuffle Options',
                  subtitle: 'Randomize answer choices by default',
                  child: _buildSettingSwitch(
                    _defaultShuffleOptions,
                    (v) {
                      setState(() => _defaultShuffleOptions = v);
                      _saveBool('default_shuffle_options', v);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                _buildSettingItemCard(
                  title: 'Single Response Per User',
                  subtitle: 'Allow only one submission per user',
                  child: _buildSettingSwitch(
                    _defaultSingleResponse,
                    (v) {
                      setState(() => _defaultSingleResponse = v);
                      _saveBool('default_single_response', v);
                    },
                  ),
                ),
                const SizedBox(height: 32),
                // Data & Storage Section
                _buildSectionHeader('Data & Storage'),
                const SizedBox(height: 12),
                _buildActionItemCard(
                  icon: Icons.cleaning_services,
                  title: 'Clear App Cache',
                  subtitle: 'Clears temporary data like violation logs',
                  onTap: _clearCache,
                ),
                const SizedBox(height: 10),
                _buildActionItemCard(
                  icon: Icons.delete_forever,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data',
                  titleColor: Colors.red,
                  onTap: _deleteAccount,
                ),
                const SizedBox(height: 32),
                // Support & Info Section
                _buildSectionHeader('Support & Info'),
                const SizedBox(height: 12),
                _buildActionItemCard(
                  icon: Icons.bug_report,
                  title: 'Report Issue',
                  subtitle: 'Send us your feedback and bug reports',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const ReportBugDialog(screenName: 'Settings'),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildActionItemCard(
                  icon: Icons.help,
                  title: 'Help & FAQ',
                  subtitle: 'Learn how to use the app effectively',
                  onTap: () => _launchUrl('https://example.com/help'),
                ),
                const SizedBox(height: 10),
                _buildActionItemCard(
                  icon: Icons.policy,
                  title: 'Terms & Privacy',
                  subtitle: 'Review our policies and agreements',
                  onTap: () => _launchUrl('https://example.com/privacy'),
                ),
                const SizedBox(height: 10),
                _buildActionItemCard(
                  icon: Icons.info,
                  title: 'App Version',
                  subtitle: _appVersion.isEmpty ? 'Loading...' : _appVersion,
                  isClickable: false,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF222222),
        fontSize: 16,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSettingItemCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 139, 139, 139),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItemCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? titleColor,
    VoidCallback? onTap,
    bool isClickable = true,
  }) {
    return GestureDetector(
      onTap: isClickable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
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
                onTap: isClickable ? onTap : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(icon, color: titleColor ?? Colors.black, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                color: titleColor ?? const Color(0xFF222222),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 139, 139, 139),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isClickable) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Color.fromARGB(255, 139, 139, 139), size: 18),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSwitch(bool value, Function(bool) onChanged) {
    return Transform.scale(
      scale: 0.8,
      child: Theme(
        data: ThemeData(
          useMaterial3: true,
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
              return Colors.white;
            }),
            trackColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF222222);
              }
              return const Color.fromARGB(255, 189, 189, 189);
            }),
          ),
        ),
        child: Switch(
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

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
