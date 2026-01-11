import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'report_bug_dialog.dart';

// StarterScreen — pixel-conscious copy of the provided reference image.
class StarterScreen extends StatelessWidget {
  const StarterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Local helper to show the Report a bug dialog. Uses absolute-positioned
    // fields and tappable areas so you can tweak X/Y/width/height easily.
    void showReportBugDialog(BuildContext parentContext) {
      showGeneralDialog(
        context: parentContext,
        barrierDismissible: true,
        barrierLabel: 'ReportBug',
        barrierColor: const Color.fromRGBO(0, 0, 0, 0.25),
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (context, animation, secondaryAnimation) {
          return const ReportBugDialog();
        },
      );
    }
    // Ensure the platform status bar is opaque black — some OEM themes
    // make the status bar translucent which lets the background image show
    // through; explicitly set it here to guarantee a black bar.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    // Using LayoutBuilder for exact placements; MediaQuery size not required here.

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: Colors.black, // keep status/notification bar black to match other screens
      resizeToAvoidBottomInset: false, // prevent dialog/background resizing when keyboard opens
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Full-screen shared background image (covers whole screen).
            // Draw a black strip at the top equal to the status bar height so
            // the image does not appear underneath the status bar on devices
            // where the bar is transparent.
            Positioned.fill(
              child: Builder(builder: (ctx) {
                final topPad = MediaQuery.of(ctx).padding.top;
                return Column(
                  children: [
                    Container(height: topPad, color: Colors.black),
                    Expanded(
                      child: Image.asset(
                        'assets/images/background.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                  ],
                );
              }),
            ),

            // Decorative elements overlay (separate from background so buttons can be positioned above)
            Positioned(
              left: 0,
              right: 0,
              top: 45,
              child: Image.asset(
                'assets/images/starter_elements.png',
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
              ),
            ),

            // Overlay interactive hit areas positioned to match the visual image.
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(builder: (context, constraints) {
                  // Base artboard dimensions (user-provided)
                  const baseW = 1080.0;
                  const baseH = 1920.0;

                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final scaleX = w / baseW;
                  final scaleY = h / baseH;

                  // User-specified element sizes & positions (in the 1080x1920 canvas)
                  // Updated per user's latest spec (artboard 1080×1920 px)
                  // Login button original top-left Y (for vertical placement)
                  const loginY = 905.0;
                  // Sign up button original top-left Y
                  const signupY = 1100.0;
                  const pillW = 654.0, pillH = 88.0;

                  final loginTop = loginY * scaleY;
                  final signupTop = signupY * scaleY;
                  final pillHeight = pillH * scaleY;
                  // Simple absolute button sizing (based on artboard px scaled to device).
                  // Adjust these multipliers to change only the two button sizes.
                  const double buttonWidthMultiplier = 1.55; // change to e.g. 1.2 to widen buttons
                  const double buttonHeightMultiplier = 1.15; // change to e.g. 1.1 to increase height
                  final double buttonWidth = pillW * scaleX * buttonWidthMultiplier;
                  final double buttonHeight = pillH * scaleY * buttonHeightMultiplier;
                  // tappable overlay multipliers (independent tuning)
                  const double overlayWidthMultiplier = 1.0;
                  const double overlayHeightMultiplier = 1.0;
                  // Use straightforward tops from artboard positions so placement is absolute and predictable
                  final double loginTopAdjusted = loginTop;
                  final double signupTopAdjusted = signupTop;
                  // helper for Learn more sizing remains based on pillHeight (stable)
                  final learnMoreBase = pillHeight;
                  // final pillRadius = scaledPillHeight / 2.0; // not currently used
                  // forgot-password removed; keep constants if needed later

                  return Stack(
                    children: [
                      // Login button: placed at the upper position
                      Positioned(
                        left: (w - buttonWidth) / 2.0,
                        top: loginTopAdjusted,
                        width: buttonWidth,
                        child: SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Visual button artwork is part of `starter_elements.png` now.
                              // Keep an invisible tappable overlay so ripples and taps work.
                              // top: slightly smaller interactive surface so ripples appear above
                              Center(
                                child: Builder(builder: (ctx) {
                                  final padX = buttonWidth * 0.05;
                                  final padY = buttonHeight * 0.08; // taller to avoid touching rounded ends
                                  final overlayW = (buttonWidth * overlayWidthMultiplier - (padX * 2)).clamp(0.0, buttonWidth * overlayWidthMultiplier);
                                  final overlayH = (buttonHeight * overlayHeightMultiplier - (padY * 2)).clamp(0.0, buttonHeight * overlayHeightMultiplier);
                                  final overlayRadius = overlayH / 3;
                                  return Material(
                                    color: const Color.fromARGB(0, 180, 175, 175),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(overlayRadius)),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () async {
                                        final navigator = Navigator.of(context);
                                        final messenger = ScaffoldMessenger.of(context);
                                        try {
                                          await navigator.pushNamed('/login');
                                        } catch (_) {
                                          messenger.showSnackBar(const SnackBar(content: Text('Route "/login" not available')));
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      splashColor: const Color.fromARGB(108, 15, 15, 15),
                                      highlightColor: const Color.fromARGB(0, 0, 0, 0),
                                      child: SizedBox(width: overlayW, height: overlayH),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Sign Up button: placed at the lower position
                      Positioned(
                        left: (w - buttonWidth) / 2.0,
                        top: signupTopAdjusted,
                        width: buttonWidth,
                        child: SizedBox(
                          width: buttonWidth,
                          height: buttonHeight,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Visual button artwork is part of `starter_elements.png` now.
                              // Keep an invisible tappable overlay so ripples and taps work.
                              Center(
                                child: Builder(builder: (ctx) {
                                  final padX = buttonWidth * 0.05;
                                  final padY = buttonHeight * 0.08;
                                  final overlayW = (buttonWidth * overlayWidthMultiplier - (padX * 2)).clamp(0.0, buttonWidth * overlayWidthMultiplier);
                                  final overlayH = (buttonHeight * overlayHeightMultiplier - (padY * 2)).clamp(0.0, buttonHeight * overlayHeightMultiplier);
                                  final overlayRadius = overlayH / 3;
                                  return Material(
                                    color: const Color.fromARGB(0, 0, 0, 0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(overlayRadius)),
                                    clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                      onTap: () async {
                                        final navigator = Navigator.of(context);
                                        final messenger = ScaffoldMessenger.of(context);
                                        try {
                                          await navigator.pushNamed('/signup');
                                        } catch (_) {
                                          messenger.showSnackBar(const SnackBar(content: Text('Route "/signup" not available')));
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      splashColor: const Color.fromARGB(108, 15, 15, 15),
                                      highlightColor: const Color.fromARGB(0, 0, 0, 0),
                                      child: SizedBox(width: overlayW, height: overlayH),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Contact icon (top-right) — opens a Report a bug dialog
                      Positioned(
                        right: 50.0 * scaleX,
                        top: 12.0 * scaleY,
                        child: IconButton(
                          onPressed: () {
                            showReportBugDialog(context);
                          },
                          icon: Icon(Icons.contact_mail, color: const Color.fromARGB(0, 255, 255, 255)),
                          tooltip: 'Report a bug',
                        ),
                      ),

                      // 'Learn more' text button moved to bottom (larger hit area, underlined)
                      Positioned(
                        left: (w - buttonWidth) / 2.0,
                        right: (w - buttonWidth) / 2.0,
                        bottom: 24 * scaleY,
                        child: Center(
                            child: TextButton(
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  final messenger = ScaffoldMessenger.of(context);
                                  try {
                                    await navigator.pushNamed('/about');
                                  } catch (_) {
                                    messenger.showSnackBar(const SnackBar(content: Text('Route "/about" not available')));
                                  }
                                },
                                style: TextButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 8 * scaleY)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline, color: const Color.fromARGB(179, 16, 15, 15), size: learnMoreBase * 0.40),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Learn more about Quiz Guard',
                                      style: TextStyle(
                                        fontFamily: 'CanvaSans',
                                        fontWeight: FontWeight.w600,
                                        color: const Color.fromARGB(179, 51, 49, 49),
                                        fontSize: learnMoreBase * 0.30,
                                        decoration: TextDecoration.underline,
                                        decorationColor: const Color.fromARGB(179, 27, 26, 26),
                                        decorationThickness: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),

                      // 'or' label removed — visuals handled in `starter_elements.png`

                      // Forgot password removed from starter screen
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// (Removed unused private widgets: _MetalPillButton and _TopWaveClipper)

// (Removed legacy gradient-drawn pill button and inner-shadow painter —
// image-backed `_ImagePillButton` is used instead.)

// Image-backed pill button: uses an asset PNG to draw the button background.
// ignore: unused_element, unused_element_parameter
// ignore: unused_element, unused_element_parameter
class _ImagePillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double borderRadius;
  final String assetPath;
  final bool showLabel;
  final double? height;
  final Color? splashColor;

  // ignore: unused_element_parameter
  const _ImagePillButton({required this.label, required this.onTap, required this.borderRadius, required this.assetPath, this.showLabel = true, this.height, this.splashColor});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : MediaQuery.of(context).size.width * 0.9;
      // small horizontal padding so any outer shadow/rounded edge in the PNG isn't clipped
      final horizontalPad = maxW * 0.02;
      final imageWidth = (maxW - (horizontalPad * 2)).clamp(0.0, maxW);

      // slightly larger vertical padding to increase visual size and touch target
      const verticalPad = 10.0;

      final overlay = splashColor ?? const Color.fromRGBO(255,255,255,0.12);
      final targetHeight = height;

      // If a target height is provided, render using the same Container+DecorationImage
      // approach as the login screen so visuals and ripple match exactly.
      if (targetHeight != null) {
        // Use Material with shape+clip so Ink.image paints into the material's ink
        // surface and ripples appear on top. This preserves rounded corners.
        Widget body = Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
          clipBehavior: Clip.antiAlias,
          child: Ink.image(
            image: AssetImage(assetPath),
            fit: BoxFit.contain,
            width: imageWidth,
            height: targetHeight,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              overlayColor: WidgetStateProperty.resolveWith((states) => overlay),
              splashFactory: InkRipple.splashFactory,
              child: Center(
                child: showLabel
                    ? Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontFamily: 'CanvaSans',
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x66000000))],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );

        return body;
      }

      // Otherwise fall back to flexible image that sizes by intrinsic height.
      Widget body = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Material(
          color: Colors.transparent,
          child: Ink.image(
            image: AssetImage(assetPath),
            fit: BoxFit.fitWidth,
            width: imageWidth,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              overlayColor: WidgetStateProperty.resolveWith((states) => overlay),
              splashFactory: InkRipple.splashFactory,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad, vertical: verticalPad),
                child: Center(
                  child: showLabel
                      ? Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'CanvaSans',
                            fontWeight: FontWeight.w600,
                            shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Color(0x66000000))],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );

      return body;
    });
  }
}
 
