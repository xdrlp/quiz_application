import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Logo extends StatelessWidget {
  final double? height;
  const Logo({super.key, this.height});

  @override
  Widget build(BuildContext context) {
    // Try the PNG first (user-provided). If it fails to load, fall back to the SVG placeholder.
    return Image.asset(
      'assets/images/logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return SvgPicture.asset(
          'assets/images/logo.svg',
          height: height,
          fit: BoxFit.contain,
          semanticsLabel: 'App logo',
        );
      },
    );
  }
}
