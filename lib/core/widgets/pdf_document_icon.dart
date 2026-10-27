import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A crisp, professional PDF document icon with a folded corner
/// and an unmistakable red "PDF" badge that never clips or truncates.
class PdfDocumentIcon extends StatelessWidget {
  final double size;

  const PdfDocumentIcon({
    super.key,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    // Proportional dimensions for an A4 document page
    final width = size * 0.95;
    final height = size * 1.25;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // White paper sheet with folded top-right flap
          CustomPaint(
            size: Size(width, height),
            painter: _PdfPagePainter(),
          ),

          // Red PDF banner at the bottom with FittedBox so "PDF" is always 100% visible
          Positioned(
            left: 1.5,
            right: 1.5,
            bottom: 1.5,
            child: Container(
              height: height * 0.44,
              decoration: BoxDecoration(
                color: AppColors.pdfRed,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(2.5),
                  bottomRight: Radius.circular(2.5),
                  topLeft: Radius.circular(1.5),
                  topRight: Radius.circular(1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 1,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: const FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.center,
                child: Text(
                  'PDF',
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfPagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = AppColors.pdfRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;

    final foldSize = size.width * 0.34;

    final path = Path()
      ..moveTo(0, 2.5)
      ..lineTo(0, size.height - 2.5)
      ..arcToPoint(Offset(2.5, size.height), radius: const Radius.circular(2.5))
      ..lineTo(size.width - 2.5, size.height)
      ..arcToPoint(Offset(size.width, size.height - 2.5), radius: const Radius.circular(2.5))
      ..lineTo(size.width, foldSize)
      ..lineTo(size.width - foldSize, 0)
      ..lineTo(2.5, 0)
      ..arcToPoint(const Offset(0, 2.5), radius: const Radius.circular(2.5))
      ..close();

    // Subtle drop shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Page body
    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintStroke);

    // Miniature content lines in upper part of document
    final linePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final lineY1 = size.height * 0.22;
    final lineY2 = size.height * 0.36;

    canvas.drawLine(Offset(size.width * 0.20, lineY1), Offset(size.width * 0.52, lineY1), linePaint);
    canvas.drawLine(Offset(size.width * 0.20, lineY2), Offset(size.width * 0.74, lineY2), linePaint);

    // Fold flap
    final foldPath = Path()
      ..moveTo(size.width - foldSize, 0)
      ..lineTo(size.width - foldSize, foldSize)
      ..lineTo(size.width, foldSize)
      ..close();

    final foldFill = Paint()
      ..color = const Color(0xFFFFCDD2)
      ..style = PaintingStyle.fill;

    canvas.drawPath(foldPath, foldFill);
    canvas.drawPath(foldPath, paintStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
