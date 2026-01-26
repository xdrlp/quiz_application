import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_bug_dialog.dart';

// ==========================================
// CONFIGURATION: TWEAK DESIGN HERE
// ==========================================

// --- Colors ---
const Color _kBackgroundColor = Color.fromARGB(255, 255, 255, 255); // Main background (Light Grey)
const Color _kTextColor = Color(0xFF4A4A4A);       // Primary text color (Dark Grey)
const Color _kRedAccentColor = Color(0xFFFF3B30);  // Primary accent (Red)

// Neumorphism Shadows
const Color _kShadowLight = Colors.white;          // Light highlight
const Color _kShadowDark = Color(0xFFA3B1C6);      // Dark shadow

// Gradient Button Colors
const Color _kGradientStart = Color(0xFFFF3B30);   
const Color _kGradientEnd = Color(0xFFFF5E3A);     

// --- Dimensions & Sizes ---
const double _kHorizontalPadding = 32.0; // Horizontal padding for whole screen
const double _kLogoSize = 140.0;

// Buttons
const double _kButtonHeight = 56.0;
const double _kButtonRadius = 50.0; // Fully rounded (pill shape)

// --- Spacing (Vertical Gaps) ---
const double _kGapLogoTitle = 40.0;
const double _kGapTitleSubtitle = 8.0;
const double _kGapSubtitleBullet = 16.0;
const double _kGapBulletLogin = 60.0;
const double _kGapLoginOr = 24.0;
const double _kGapOrSignup = 24.0;
const double _kGapSignupFooter = 60.0;

// --- Typography (Font Sizes) ---
const double _kTitleFontSize = 32.0;
const double _kSubtitleFontSize = 16.0;
const double _kBulletTextFontSize = 14.0;
const double _kButtonTextFontSize = 18.0;
const double _kFooterTextFontSize = 14.0;

// ==========================================

class StarterScreen extends StatelessWidget {
  const StarterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Set status bar to dark icons for light background compatibility
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

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

    return Scaffold(
      backgroundColor: _kBackgroundColor,
      body: SafeArea(
        child: SizedBox.expand(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kHorizontalPadding, vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
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
                          color: _kRedAccentColor,
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
                      color: _kTextColor.withValues(alpha: 0.6),
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

                  // Footer Info
                  GestureDetector(
                    onTap: () => showReportBugDialog(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: _kFooterTextFontSize + 4, color: _kTextColor.withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text(
                          'Learn more about Quiz Guard',
                          style: TextStyle(
                            fontSize: _kFooterTextFontSize,
                            color: _kTextColor.withValues(alpha: 0.5),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
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
    return Container(
      width: double.infinity,
      height: _kButtonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kButtonRadius),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover, // Or BoxFit.fill depending on aspect ratio
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_kButtonRadius), 
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

