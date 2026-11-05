import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Official multi-color Google Drive triangle icon rendered with vector paths.
class GoogleDriveLogo extends StatelessWidget {
  final double size;

  const GoogleDriveLogo({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleDriveLogoPainter(),
      ),
    );
  }
}

class _GoogleDriveLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Normalized 87.3 x 78 viewBox coordinates for official Google Drive icon
    double sx(double x) => (x / 87.3) * w;
    double sy(double y) => (y / 78.0) * h;

    // 1. Top-left green arm (#00AC47)
    final greenPaint = Paint()
      ..color = const Color(0xFF00AC47)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final greenPath = Path()
      ..moveTo(sx(43.65), sy(25.0))
      ..lineTo(sx(29.9), sy(1.2))
      ..cubicTo(sx(28.55), sy(2.0), sx(27.4), sy(3.1), sx(26.6), sy(4.5))
      ..lineTo(sx(1.2), sy(48.55))
      ..cubicTo(sx(0.4), sy(49.95), sx(0.0), sy(51.5), sx(0.0), sy(53.0))
      ..lineTo(sx(27.5), sy(53.0))
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // 2. Top-right yellow arm (#FFBA00)
    final yellowPaint = Paint()
      ..color = const Color(0xFFFFBA00)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final yellowPath = Path()
      ..moveTo(sx(73.55), sy(53.0))
      ..lineTo(sx(87.3), sy(53.0))
      ..cubicTo(sx(87.3), sy(51.5), sx(86.9), sy(49.95), sx(86.1), sy(48.55))
      ..lineTo(sx(60.7), sy(4.5))
      ..cubicTo(sx(59.9), sy(3.1), sx(58.75), sy(2.0), sx(57.4), sy(1.2))
      ..lineTo(sx(43.65), sy(25.0))
      ..lineTo(sx(59.8), sy(53.0))
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // 3. Top dark-green diamond junction (#00832D)
    final darkGreenPaint = Paint()
      ..color = const Color(0xFF00832D)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final darkGreenPath = Path()
      ..moveTo(sx(43.65), sy(25.0))
      ..lineTo(sx(57.4), sy(1.2))
      ..cubicTo(sx(56.05), sy(0.4), sx(54.5), sy(0.0), sx(52.9), sy(0.0))
      ..lineTo(sx(34.4), sy(0.0))
      ..cubicTo(sx(32.8), sy(0.0), sx(31.25), sy(0.45), sx(29.9), sy(1.2))
      ..close();
    canvas.drawPath(darkGreenPath, darkGreenPaint);

    // 4. Bottom-left dark-blue corner (#0066DA)
    final darkBluePaint = Paint()
      ..color = const Color(0xFF0066DA)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final darkBluePath = Path()
      ..moveTo(sx(6.6), sy(66.85))
      ..lineTo(sx(10.45), sy(73.5))
      ..cubicTo(sx(11.25), sy(74.9), sx(12.4), sy(76.0), sx(13.75), sy(76.8))
      ..lineTo(sx(27.5), sy(53.0))
      ..lineTo(sx(0.0), sy(53.0))
      ..cubicTo(sx(0.0), sy(54.55), sx(0.4), sy(56.1), sx(1.2), sy(57.5))
      ..close();
    canvas.drawPath(darkBluePath, darkBluePaint);

    // 5. Bottom-right red corner (#EA4335)
    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final redPath = Path()
      ..moveTo(sx(73.55), sy(76.8))
      ..cubicTo(sx(74.9), sy(76.0), sx(76.05), sy(74.9), sx(76.85), sy(73.5))
      ..lineTo(sx(78.45), sy(70.75))
      ..lineTo(sx(86.1), sy(57.5))
      ..cubicTo(sx(86.9), sy(56.1), sx(87.3), sy(54.55), sx(87.3), sy(53.0))
      ..lineTo(sx(59.8), sy(53.0))
      ..close();
    canvas.drawPath(redPath, redPaint);

    // 6. Bottom light-blue bar (#2684FC)
    final lightBluePaint = Paint()
      ..color = const Color(0xFF2684FC)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final lightBluePath = Path()
      ..moveTo(sx(59.8), sy(53.0))
      ..lineTo(sx(27.5), sy(53.0))
      ..lineTo(sx(13.75), sy(76.8))
      ..cubicTo(sx(15.1), sy(77.6), sx(16.65), sy(78.0), sx(18.25), sy(78.0))
      ..lineTo(sx(69.05), sy(78.0))
      ..cubicTo(sx(70.65), sy(78.0), sx(72.2), sy(77.55), sx(73.55), sy(76.8))
      ..close();
    canvas.drawPath(lightBluePath, lightBluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Official 4-color Google "G" icon for Google Sign-In buttons.
class GoogleGLogo extends StatelessWidget {
  final double size;

  const GoogleGLogo({
    super.key,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleGPainter(),
      ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.22;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    double deg(double d) => d * math.pi / 180.0;

    // Red top-left arc
    canvas.drawArc(rect, deg(215), deg(105), false, arcPaint(const Color(0xFFEA4335)));
    // Yellow left arc
    canvas.drawArc(rect, deg(145), deg(70), false, arcPaint(const Color(0xFFFBBC05)));
    // Green bottom arc
    canvas.drawArc(rect, deg(45), deg(100), false, arcPaint(const Color(0xFF34A853)));
    // Blue right arc
    canvas.drawArc(rect, deg(-12), deg(57), false, arcPaint(const Color(0xFF4285F4)));

    // Blue horizontal crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth * 0.48,
        size.width * 0.48,
        strokeWidth * 0.96,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders the signed-in Google user's profile picture with a Google Drive badge
/// and graceful initials fallback.
class GoogleAccountAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? displayName;
  final String? email;
  final double radius;
  final bool showDriveBadge;

  const GoogleAccountAvatar({
    super.key,
    required this.photoUrl,
    this.displayName,
    this.email,
    this.radius = 24,
    this.showDriveBadge = true,
  });

  String _getInitial() {
    final name = (displayName ?? '').trim();
    if (name.isNotEmpty) return name[0].toUpperCase();
    final mail = (email ?? '').trim();
    if (mail.isNotEmpty) return mail[0].toUpperCase();
    return 'G';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diameter = radius * 2;

    return SizedBox(
      width: diameter + (showDriveBadge ? 4 : 0),
      height: diameter + (showDriveBadge ? 4 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
              color: AppColors.primaryBlue.withAlpha(30),
            ),
            child: ClipOval(
              child: (photoUrl != null && photoUrl!.trim().isNotEmpty)
                  ? Image.network(
                      photoUrl!.trim(),
                      width: diameter,
                      height: diameter,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildFallbackInitial(),
                    )
                  : _buildFallbackInitial(),
            ),
          ),
          if (showDriveBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: EdgeInsets.all(radius * 0.14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2430) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(35),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: GoogleDriveLogo(size: radius * 0.56),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackInitial() {
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF1A73E8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        _getInitial(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.85,
        ),
      ),
    );
  }
}

