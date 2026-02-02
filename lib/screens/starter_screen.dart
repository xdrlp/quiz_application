import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
const double _kButtonRadius = 12.0; // Less rounded

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
                        decoration: TextDecoration.underline,
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

                    // Log in Button (Image Asset)
                    _ImageButton(
                      onTap: () => Navigator.pushNamed(context, '/login'),
                      imagePath: 'assets/images/logIn_button.png',
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

                    // Create Account Button (Image Asset)
                    _ImageButton(
                      onTap: () => Navigator.pushNamed(context, '/signup'),
                      imagePath: 'assets/images/signUp_button.png',
                    ),

                    const SizedBox(height: _kGapSignupFooter),
                  ],
                ),
              );

              final Widget footer = GestureDetector(
                onTap: () {},
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
                        'Learn more about Quiz Guard',
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
                  Expanded(child: content),
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

// Helper Widget for Image Button with Ripple
class _ImageButton extends StatelessWidget {
  final VoidCallback onTap;
  final String imagePath;

  const _ImageButton({required this.onTap, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final double available =
        MediaQuery.of(context).size.width - (_kHorizontalPadding * 2);
    final double buttonWidth = available > 360.0 ? 360.0 : available;

    return Center(
      child: SizedBox(
        width: buttonWidth,
        height: _kButtonHeight,
        child: Stack(
          children: [
            Positioned.fill(child: Image.asset(imagePath, fit: BoxFit.contain)),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(_kButtonRadius),
                  // Stronger ripple to ensure visibility over the image
                  splashColor: Colors.black.withValues(alpha: 0.3),
                  highlightColor: Colors.black.withValues(alpha: 0.1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
