import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PdfDocumentIcon extends StatelessWidget {
  final double size;

  const PdfDocumentIcon({
    super.key,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final width = size * 0.85;
    final height = size * 1.1;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Outer page outline with folded top-right corner
          CustomPaint(
            size: Size(width, height),
            painter: _PdfPagePainter(),
          ),
          // Inner red/orange PDF badge label
          Positioned(
            left: 2,
            right: 2,
            bottom: 2,
            child: Container(
              height: height * 0.38,
              decoration: BoxDecoration(
                color: AppColors.pdfRed,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: const Text(
                'PDF',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
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

    final foldSize = size.width * 0.32;

    final path = Path()
      ..moveTo(0, 2)
      ..lineTo(0, size.height - 2)
      ..arcToPoint(Offset(2, size.height), radius: const Radius.circular(2))
      ..lineTo(size.width - 2, size.height)
      ..arcToPoint(Offset(size.width, size.height - 2), radius: const Radius.circular(2))
      ..lineTo(size.width, foldSize)
      ..lineTo(size.width - foldSize, 0)
      ..lineTo(2, 0)
      ..arcToPoint(const Offset(0, 2), radius: const Radius.circular(2))
      ..close();

    // Shadow
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withAlpha(20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Page body
    canvas.drawPath(path, paintFill);
    canvas.drawPath(path, paintStroke);

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
