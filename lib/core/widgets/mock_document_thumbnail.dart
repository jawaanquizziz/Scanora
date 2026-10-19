import 'dart:io';
import 'package:flutter/material.dart';

class MockDocumentThumbnail extends StatelessWidget {
  final String? imagePath;
  final String title;
  final double width;
  final double height;

  const MockDocumentThumbnail({
    super.key,
    this.imagePath,
    required this.title,
    this.width = double.infinity,
    this.height = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: BoxFit.cover,
        );
      }
    }

    // Realistic handwritten document canvas matching Image 2
    return CustomPaint(
      size: Size(width, height),
      painter: _DocumentPagePainter(title: title),
    );
  }
}

class _DocumentPagePainter extends CustomPainter {
  final String title;

  _DocumentPagePainter({required this.title});

  @override
  void paint(Canvas canvas, Size size) {
    // Paper background
    final bgPaint = Paint()..color = const Color(0xFFFBFBFB);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Margin line (left vertical line)
    final marginPaint = Paint()
      ..color = const Color(0xFFFFCDD2)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(size.width * 0.16, 0), Offset(size.width * 0.16, size.height), marginPaint);

    // Horizontal ruled lines
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;

    final lineSpacing = size.height / 18;
    for (double y = lineSpacing * 2; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Top header text
    final headerPaint = TextPainter(
      text: const TextSpan(
        text: 'FR. CONCEICAO RODRIGUES INST. OF TECH.',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 4.8,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    headerPaint.layout(maxWidth: size.width * 0.8);
    headerPaint.paint(canvas, Offset(size.width * 0.18, lineSpacing * 0.8));

    // Simulated handwritten notes / diagrams based on title
    final inkPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final blueInkPaint = Paint()
      ..color = const Color(0xFF1E40AF)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final redInkPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    if (title.contains('DLDA (2)') || title.contains('remedial')) {
      // Flowchart / Mindmap / Logic blocks
      final boxPaint = Paint()
        ..color = const Color(0xFF64748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;

      // Central logic block
      final centerBox = Rect.fromCenter(
        center: Offset(size.width * 0.55, size.height * 0.42),
        width: size.width * 0.45,
        height: size.height * 0.10,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(centerBox, const Radius.circular(6)), boxPaint);

      // Connected sub-nodes
      final node1 = Rect.fromCenter(
        center: Offset(size.width * 0.35, size.height * 0.26),
        width: size.width * 0.28,
        height: size.height * 0.07,
      );
      final node2 = Rect.fromCenter(
        center: Offset(size.width * 0.72, size.height * 0.26),
        width: size.width * 0.28,
        height: size.height * 0.07,
      );
      final node3 = Rect.fromCenter(
        center: Offset(size.width * 0.55, size.height * 0.62),
        width: size.width * 0.38,
        height: size.height * 0.08,
      );

      canvas.drawOval(node1, boxPaint);
      canvas.drawOval(node2, boxPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(node3, const Radius.circular(6)), boxPaint);

      // Connectors
      canvas.drawLine(centerBox.topCenter, node1.bottomCenter, blueInkPaint);
      canvas.drawLine(centerBox.topCenter, node2.bottomCenter, blueInkPaint);
      canvas.drawLine(centerBox.bottomCenter, node3.topCenter, blueInkPaint);
    } else if (title.contains('remedial') || title.contains('DLDA (1)')) {
      // Truth table & logic gate
      final tablePaint = Paint()
        ..color = const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final tableRect = Rect.fromLTWH(size.width * 0.22, size.height * 0.32, size.width * 0.65, size.height * 0.32);
      canvas.drawRect(tableRect, tablePaint);

      // Table columns & rows
      canvas.drawLine(Offset(tableRect.left + tableRect.width * 0.25, tableRect.top), Offset(tableRect.left + tableRect.width * 0.25, tableRect.bottom), tablePaint);
      canvas.drawLine(Offset(tableRect.left + tableRect.width * 0.5, tableRect.top), Offset(tableRect.left + tableRect.width * 0.5, tableRect.bottom), tablePaint);
      canvas.drawLine(Offset(tableRect.left + tableRect.width * 0.75, tableRect.top), Offset(tableRect.left + tableRect.width * 0.75, tableRect.bottom), tablePaint);

      for (int i = 1; i <= 4; i++) {
        final rowY = tableRect.top + (tableRect.height / 5) * i;
        canvas.drawLine(Offset(tableRect.left, rowY), Offset(tableRect.right, rowY), tablePaint);
      }

      // Logic comparator block at top
      final compRect = Rect.fromLTWH(size.width * 0.36, size.height * 0.18, size.width * 0.38, size.height * 0.10);
      canvas.drawRect(compRect, boxPaint(inkPaint));
      // Red mark
      canvas.drawCircle(Offset(size.width * 0.30, size.height * 0.16), 5, redInkPaint);
    } else {
      // General handwritten lined paragraph notes
      for (int i = 3; i <= 14; i++) {
        final y = lineSpacing * i - 2;
        final strokeLen = (i % 3 == 0) ? size.width * 0.65 : size.width * 0.74;
        canvas.drawLine(
          Offset(size.width * 0.20, y),
          Offset(size.width * 0.20 + strokeLen, y),
          (i % 5 == 0) ? redInkPaint : (i % 2 == 0 ? blueInkPaint : inkPaint),
        );
      }
    }
  }

  Paint boxPaint(Paint original) {
    return Paint()
      ..color = original.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = original.strokeWidth;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
