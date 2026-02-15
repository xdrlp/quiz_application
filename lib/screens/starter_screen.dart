import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import 'report_bug_dialog.dart';

// ==========================================
// CONFIGURATION: TWEAK DESIGN HERE
// ==========================================

// --- Colors ---
const Color _kTextColor = Color(0xFF222222); // Primary text color (Dark Grey)

// Neumorphism Shadows
// Neumorphism shadows and gradient colors removed (unused)

// --- Dimensions & Sizes ---
const double _kHorizontalPadding = 32.0; // Horizontal padding for whole screen
const double _kLogoSize = 140.0;

// Buttons
// Reduced height and corner radius to make buttons less rounded and better sized
const double _kButtonHeight = 44.0; // slightly smaller

// --- Spacing (Vertical Gaps) ---
const double _kGapLogoTitle = 16.0;
const double _kGapTitleSubtitle = 4.0;
const double _kGapSubtitleBullet = 8.0;
const double _kGapBulletLogin = 100.0;
const double _kGapLoginOr = 12.0;
const double _kGapOrSignup = 12.0;
const double _kGapSignupFooter = 30.0;

// --- Typography (Font Sizes) ---
const double _kTitleFontSize = 32.0;
const double _kSubtitleFontSize = 16.0;
const double _kBulletTextFontSize = 14.0;
// _kButtonTextFontSize removed (unused)
const double _kFooterTextFontSize = 12.0;

// ==========================================

class StarterScreen extends StatelessWidget {
  const StarterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Set status bar to dark icons for light background compatibility
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    void showReportBugDialog(BuildContext parentContext) {
      showGeneralDialog(
        context: parentContext,
        barrierDismissible: true,
        barrierLabel: 'ReportBug',
        barrierColor: const Color.fromRGBO(0, 0, 0, 0.25),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const ReportBugDialog(screenName: 'StarterScreen');
        },
      );
    }

    final mq = MediaQuery.of(context);
    final bool isWide = mq.size.width >= 700;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [
            Color(0xFFFFFFFF),
            Color.fromARGB(255, 207, 207, 207),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: 'Report a bug',
              onPressed: () => showReportBugDialog(context),
              icon: Icon(
                Icons.bug_report_outlined,
                color: _kTextColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Builder(
            builder: (_) {
              final Widget content = Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kHorizontalPadding,
                  vertical: 0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 0),
                    // Logo
                    Image.asset(
                      'assets/images/logo.png',
                      width: _kLogoSize,
                      height: _kLogoSize,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: _kGapLogoTitle),

                    // Title
                    Text(
                      'Quiz Guard',
                      style: TextStyle(
                        fontSize: _kTitleFontSize,
                        fontWeight: FontWeight.bold,
                        color: _kTextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: _kGapTitleSubtitle),

                    // Subtitle
                    Text(
                      'Honest learning, real results',
                      style: TextStyle(
                        fontSize: _kSubtitleFontSize,
                        fontWeight: FontWeight.w600,
                        color: _kTextColor.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: _kGapSubtitleBullet),

                    // Bullet Point
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 230, 0, 0),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Real-time monitoring',
                          style: TextStyle(
                            fontSize: _kBulletTextFontSize,
                            fontWeight: FontWeight.w500,
                            color: _kTextColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: _kGapBulletLogin),

                    // Log in Button
                    _GradientButton(
                      onTap: () => Navigator.pushNamed(context, '/login'),
                      text: 'Log in',
                      backgroundGradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFD4D4D4),
                          Color(0xFFC9C9C9),
                        ],
                      ),
                      textGradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.fromARGB(220, 26, 26, 26), Color.fromARGB(246, 0, 0, 0)],
                      ),
                      textShadows: const [
                        Shadow(
                          color: Color.fromARGB(54, 0, 0, 0),
                          offset: Offset(1.2, 1.2),
                          blurRadius: 0.5,
                        ),
                      ],
                    ),

                    const SizedBox(height: _kGapLoginOr),
                    Text(
                      'or',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color.fromARGB(
                          255,
                          43,
                          43,
                          43,
                        ).withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: _kGapOrSignup),

                    // Create Account Button
                    _GradientButton(
                      onTap: () => Navigator.pushNamed(context, '/signup'),
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
                    ),

                    const SizedBox(height: _kGapSignupFooter),
                  ],
                ),
              );

              final Widget footer = GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Browser Compatibility Notice'),
                        content: const Text(
                          'For the best experience with Quiz Guard, please ensure:\n\n'
                          '• Allow cookies and site data for this site in your browser settings\n'
                          '• Disable ad blockers or privacy extensions temporarily\n'
                          '• Allow third-party cookies if prompted\n\n'
                          'This helps the app connect to our secure servers for quiz access.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: _kFooterTextFontSize + 4,
                        color: const Color.fromARGB(
                          255,
                          2,
                          2,
                          2,
                        ).withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Browser Settings for Best Experience',
                        style: TextStyle(
                          fontSize: _kFooterTextFontSize,
                          color: const Color.fromARGB(
                            255,
                            0,
                            0,
                            0,
                          ).withValues(alpha: 0.5),
                          decoration: TextDecoration.underline,
                          decorationColor: const Color.fromARGB(
                            255,
                            41,
                            41,
                            41,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );

              final Widget mainContent = Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: content,
                    ),
                  ),
                  footer,
                ],
              );

              if (isWide) {
                return SizedBox.expand(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Center(child: mainContent),
                  ),
                );
              }

              return SizedBox.expand(child: mainContent);
            },
          ),
        ),
      ),
    );
  }
}

// Helper Widget for Gradient Button
class _GradientButton extends StatefulWidget {
  final VoidCallback onTap;
  final String text;
  final LinearGradient backgroundGradient;
  final LinearGradient? textGradient;
  final List<Shadow>? textShadows;

  const _GradientButton({
    required this.onTap,
    required this.text,
    required this.backgroundGradient,
    this.textGradient,
    this.textShadows,
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
        height: _kButtonHeight,
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
                      return (widget.textGradient ??
                          const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFE9E9E9), Color(0xFFFFFFFF)],
                          )).createShader(bounds);
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
