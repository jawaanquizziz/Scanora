import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/scanned_document.dart';
import '../../services/pdf_thumbnail_service.dart';
import '../theme/app_colors.dart';

class DocumentThumbnailView extends StatefulWidget {
  final ScannedDocument doc;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool showBadge;
  final BoxFit fit;

  const DocumentThumbnailView({
    super.key,
    required this.doc,
    this.width,
    this.height,
    this.borderRadius,
    this.showBadge = true,
    this.fit = BoxFit.cover,
  });

  @override
  State<DocumentThumbnailView> createState() => _DocumentThumbnailViewState();
}

class _DocumentThumbnailViewState extends State<DocumentThumbnailView> {
  Uint8List? _cachedBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadThumbnail();
  }

  @override
  void didUpdateWidget(covariant DocumentThumbnailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.id != widget.doc.id ||
        oldWidget.doc.thumbnailPath != widget.doc.thumbnailPath ||
        oldWidget.doc.filePath != widget.doc.filePath) {
      _cachedBytes = null;
      _checkAndLoadThumbnail();
    }
  }

  void _checkAndLoadThumbnail() {
    // If thumbnail file exists, no need for async rendering
    if (!kIsWeb &&
        widget.doc.thumbnailPath != null &&
        widget.doc.thumbnailPath!.isNotEmpty) {
      final file = File(widget.doc.thumbnailPath!);
      if (file.existsSync()) {
        return;
      }
    }

    // Check memory cache
    final mem = PdfThumbnailService().getCachedBytes(widget.doc.id);
    if (mem != null) {
      _cachedBytes = mem;
      return;
    }

    // Otherwise lazily fetch or render from PDF file
    _isLoading = true;
    PdfThumbnailService().getOrRenderBytes(widget.doc).then((bytes) {
      if (mounted && bytes != null) {
        setState(() {
          _cachedBytes = bytes;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(8);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget imageContent;

    // 1. Direct file thumbnail if present and exists
    if (!kIsWeb &&
        widget.doc.thumbnailPath != null &&
        widget.doc.thumbnailPath!.isNotEmpty &&
        File(widget.doc.thumbnailPath!).existsSync()) {
      imageContent = Image.file(
        File(widget.doc.thumbnailPath!),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildFallbackPreview(isDark),
      );
    } else if (_cachedBytes != null) {
      // 2. Memory bytes from rasterized PDF
      imageContent = Image.memory(
        _cachedBytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => _buildFallbackPreview(isDark),
      );
    } else {
      // 3. Fallback or Loading state
      imageContent = _buildFallbackPreview(isDark);
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : const Color(0xFFFBFBFB),
          border: Border.all(
            color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
            width: 0.8,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageContent,

            // PDF Badge overlay on top corner or bottom corner
            if (widget.showBadge)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.pdfRed.withAlpha(230),
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),

            // Loading spinner indicator if rasterizing
            if (_isLoading && _cachedBytes == null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha(15),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.lensOrange),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackPreview(bool isDark) {
    return CustomPaint(
      size: Size(widget.width ?? double.infinity, widget.height ?? double.infinity),
      painter: _MiniDocumentContentPainter(
        title: widget.doc.title,
        isDark: isDark,
      ),
    );
  }
}

class _MiniDocumentContentPainter extends CustomPainter {
  final String title;
  final bool isDark;

  _MiniDocumentContentPainter({
    required this.title,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paper sheet
    final paperPaint = Paint()
      ..color = isDark ? const Color(0xFF232733) : const Color(0xFFFAFAFA);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paperPaint);

    // Subtle header bar
    final headerPaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(18) : Colors.black.withAlpha(10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.12, size.width * 0.65, 4),
        const Radius.circular(2),
      ),
      headerPaint,
    );

    // Realistic miniature text lines inside document
    final linePaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(14) : Colors.black.withAlpha(8);

    final lineCount = (size.height / 10).clamp(4, 14).toInt();
    final spacing = (size.height * 0.70) / lineCount;

    for (int i = 0; i < lineCount; i++) {
      final y = size.height * 0.22 + (i * spacing);
      final lineWidth = (i % 3 == 0)
          ? size.width * 0.55
          : (i % 2 == 0)
              ? size.width * 0.75
              : size.width * 0.68;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.12, y, lineWidth, 2.5),
          const Radius.circular(1.2),
        ),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniDocumentContentPainter oldDelegate) {
    return oldDelegate.title != title || oldDelegate.isDark != isDark;
  }
}
