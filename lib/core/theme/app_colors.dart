import 'package:flutter/material.dart';

class AppColors {
  // Brand colors matching Scanora specifications
  static const Color primary = Color(0xFF176BFF); // Scanora Primary Blue (#176BFF)
  static const Color primaryBlue = Color(0xFFEA580C); // Warm Brand Orange
  static const Color primaryDark = Color(0xFFC2410C); // Deep Burnt Orange
  static const Color primaryLight = Color(0xFFFFEDD5); // Light Cream/Orange
  static const Color navy = Color(0xFF101828);
  static const Color appBackground = Color(0xFFF6F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFF667085);
  static const Color border = Color(0xFFE4E7EC);
  static const Color success = Color(0xFF16B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Scanora UI accents
  static const Color lensOrange = Color(0xFFEA580C);
  static const Color lensOrangeDark = Color(0xFFC2410C);
  static const Color lensOrangeLight = Color(0xFFFFEDD5);
  static const Color cloudBlue = Color(0xFFEA580C);
  static const Color pdfRed = Color(0xFFEA580C);
  static const Color cardBorderLight = Color(0xFFE2E5EB);
  static const Color cardBorderDark = Color(0xFF2C303D);
  static const Color cardBgLight = Color(0xFFFFFFFF);
  static const Color cardBgDark = Color(0xFF1C1F28);

  // Signature Sunset Aurora Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFFF7A3D), // Vibrant warm coral-orange
      Color(0xFFEA580C), // Scanora signature orange
      Color(0xFFDC2626), // Deep warm crimson
      Color(0xFF991B1B), // Rich elegant ruby
    ],
  );

  static const LinearGradient primaryGradientVertical = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF7A3D),
      Color(0xFFEA580C),
      Color(0xFFDC2626),
      Color(0xFF991B1B),
    ],
  );

  // Dark mode colors
  static const Color darkBackground = Color(0xFF12141A);
  static const Color darkSurface = Color(0xFF1E222D);
  static const Color darkBorder = Color(0xFF2C3240);
  static const Color darkSecondaryText = Color(0xFF98A2B3);

  // Folder accent colors
  static const List<Color> folderColors = [
    Color(0xFFEA580C), // Orange
    Color(0xFF8B5CF6), // Purple
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
  ];
}
