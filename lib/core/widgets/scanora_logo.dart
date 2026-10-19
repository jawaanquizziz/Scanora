import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The official Scanora brand logo featuring the faceted lens shutter aperture
/// and the distinctive 'S' badge.
class ScanoraLogo extends StatelessWidget {
  final double size;
  final bool hasShadow;

  const ScanoraLogo({
    super.key,
    this.size = 36,
    this.hasShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: AppColors.lensOrange.withAlpha(65),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: FacetedLensPainter(),
      ),
    );
  }
}

/// Scalable CustomPainter for the Scanora faceted lens logo.
class FacetedLensPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Facet segments in warm orange, coral, amber, and red-orange gradient shades
    final colors = [
      const Color(0xFFF97316), // Bright Orange
      const Color(0xFFFB923C), // Light Amber Orange
      const Color(0xFFEA580C), // Deep Orange
      const Color(0xFFC2410C), // Crimson Coral
      const Color(0xFF9A3412), // Deep Rust
      const Color(0xFFF59E0B), // Warm Amber
    ];

    // Clip to circle
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.save();
    canvas.clipPath(circlePath);

    // Draw faceted shutter aperture petals
    const count = 6;
    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi / count) - (math.pi / 6);
      final nextAngle = angle + (2 * math.pi / count);

      final p1 = center;
      final p2 = Offset(
        center.dx + radius * 1.25 * math.cos(angle),
        center.dy + radius * 1.25 * math.sin(angle),
      );
      final p3 = Offset(
        center.dx + radius * 1.25 * math.cos(nextAngle),
        center.dy + radius * 1.25 * math.sin(nextAngle),
      );

      final facetPath = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawPath(facetPath, paint);
    }

    // Inner dark central aperture polygon (scales with width)
    final innerPath = Path();
    final innerRadius = size.width * (18.0 / 130.0);
    for (int i = 0; i < count; i++) {
      final angle = i * 2 * math.pi / count;
      final pt = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      if (i == 0) {
        innerPath.moveTo(pt.dx, pt.dy);
      } else {
        innerPath.lineTo(pt.dx, pt.dy);
      }
    }
    innerPath.close();

    final innerPaint = Paint()
      ..color = const Color(0xFF7C2D12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerPaint);

    canvas.restore();

    // Prominent bold rounded square badge on left/center with 'S' emblem
    final badgeWidth = size.width * 0.44;
    final badgeHeight = size.height * 0.44;
    final cornerRadius = math.max(1.5, size.width * (8.0 / 130.0));
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - (size.width * 0.12), center.dy),
        width: badgeWidth,
        height: badgeHeight,
      ),
      Radius.circular(cornerRadius),
    );

    // Badge shadow
    final blurSigma = math.max(0.5, size.width * (4.0 / 130.0));
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = Colors.black.withAlpha(45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma),
    );

    // Badge fill
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = const Color(0xFFEA580C)
        ..style = PaintingStyle.fill,
    );

    // White 'S' lettermark on badge
    final fontSize = math.max(8.0, size.width * (34.0 / 130.0));
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'Roboto',
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (center.dx - (size.width * 0.12)) - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A composite brand widget showing the Scanora logo paired with the "Scanora" wordmark.
class ScanoraBrand extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final Color? textColor;
  final FontWeight fontWeight;
  final double spacing;
  final bool hasLogoShadow;

  const ScanoraBrand({
    super.key,
    this.logoSize = 28,
    this.fontSize = 20,
    this.textColor,
    this.fontWeight = FontWeight.w700,
    this.spacing = 10,
    this.hasLogoShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = textColor ?? (isDark ? Colors.white : AppColors.navy);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ScanoraLogo(
          size: logoSize,
          hasShadow: hasLogoShadow,
        ),
        SizedBox(width: spacing),
        Text(
          'Scanora',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: -0.4,
            color: color,
          ),
        ),
      ],
    );
  }
}
