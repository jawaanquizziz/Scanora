import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_overlay.dart';
import '../../models/scan_page.dart';
import '../../services/image_service.dart';

class CropScreen extends StatefulWidget {
  final ScanPage page;
  final bool isSingleStep; // If true, pops with processed page; else pushes to filter screen

  const CropScreen({
    super.key,
    required this.page,
    this.isSingleStep = false,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  late ScanPage _currentPage;
  bool _isProcessing = false;

  // Normalized crop bounds (0.0 to 1.0)
  late double _left;
  late double _top;
  late double _right;
  late double _bottom;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.page.copyWith();
    _left = _currentPage.cropLeft;
    _top = _currentPage.cropTop;
    _right = _currentPage.cropRight;
    _bottom = _currentPage.cropBottom;
  }

  void _rotateClockwise() {
    setState(() {
      _currentPage.rotationAngle = (_currentPage.rotationAngle + 90) % 360;
    });
  }

  void _resetCrop() {
    setState(() {
      _left = 0.0;
      _top = 0.0;
      _right = 1.0;
      _bottom = 1.0;
    });
  }

  Future<void> _applyCropAndFinish() async {
    setState(() {
      _isProcessing = true;
    });

    _currentPage.cropLeft = _left;
    _currentPage.cropTop = _top;
    _currentPage.cropRight = _right;
    _currentPage.cropBottom = _bottom;

    try {
      final processedPath = await ImageService().processPage(_currentPage);
      _currentPage.processedImagePath = processedPath;

      if (!mounted) return;
      Navigator.of(context).pop(_currentPage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to crop image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Crop & Rotate',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _resetCrop,
            child: const Text('Reset', style: TextStyle(color: Colors.white70)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonal(
              onPressed: _isProcessing ? null : _applyCropAndFinish,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: Stack(
                          children: [
                            // Base image rotated
                            RotatedBox(
                              quarterTurns: _currentPage.rotationAngle ~/ 90,
                              child: Image.file(
                                File(_currentPage.originalImagePath),
                                fit: BoxFit.contain,
                              ),
                            ),
                            // Interactive Crop Overlay
                            Positioned.fill(
                              child: _CropOverlay(
                                left: _left,
                                top: _top,
                                right: _right,
                                bottom: _bottom,
                                onChanged: (l, t, r, b) {
                                  setState(() {
                                    _left = l;
                                    _top = t;
                                    _right = r;
                                    _bottom = b;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Bottom Action Bar
              Container(
                color: const Color(0xFF16181F),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.rotate_right_rounded,
                      label: 'Rotate 90°',
                      onTap: _rotateClockwise,
                    ),
                    _buildActionButton(
                      icon: Icons.aspect_ratio_rounded,
                      label: 'Reset Crop',
                      onTap: _resetCrop,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isProcessing)
            const LoadingOverlay(message: 'Applying crop...'),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropOverlay extends StatefulWidget {
  final double left;
  final double top;
  final double right;
  final double bottom;
  final Function(double l, double t, double r, double b) onChanged;

  const _CropOverlay({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.onChanged,
  });

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  static const double handleSize = 28.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final pixelLeft = widget.left * w;
        final pixelTop = widget.top * h;
        final pixelRight = widget.right * w;
        final pixelBottom = widget.bottom * h;
        final boxW = pixelRight - pixelLeft;
        final boxH = pixelBottom - pixelTop;

        return Stack(
          children: [
            // Darkened backdrop around the crop area
            CustomPaint(
              size: Size(w, h),
              painter: _CropBackdropPainter(
                rect: Rect.fromLTRB(pixelLeft, pixelTop, pixelRight, pixelBottom),
              ),
            ),

            // Crop Box with Grid Lines
            Positioned(
              left: pixelLeft,
              top: pixelTop,
              width: boxW,
              height: boxH,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final dxNorm = details.delta.dx / w;
                  final dyNorm = details.delta.dy / h;
                  double newL = (widget.left + dxNorm).clamp(0.0, 1.0 - (widget.right - widget.left));
                  double newT = (widget.top + dyNorm).clamp(0.0, 1.0 - (widget.bottom - widget.top));
                  final currW = widget.right - widget.left;
                  final currH = widget.bottom - widget.top;
                  widget.onChanged(newL, newT, (newL + currW).clamp(0.0, 1.0), (newT + currH).clamp(0.0, 1.0));
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryBlue, width: 2),
                  ),
                  child: CustomPaint(
                    painter: _GridLinesPainter(),
                  ),
                ),
              ),
            ),

            // Top-Left Handle
            _buildHandle(
              x: pixelLeft - handleSize / 2,
              y: pixelTop - handleSize / 2,
              onDrag: (dx, dy) {
                final newL = (widget.left + dx / w).clamp(0.0, widget.right - 0.1);
                final newT = (widget.top + dy / h).clamp(0.0, widget.bottom - 0.1);
                widget.onChanged(newL, newT, widget.right, widget.bottom);
              },
            ),

            // Top-Right Handle
            _buildHandle(
              x: pixelRight - handleSize / 2,
              y: pixelTop - handleSize / 2,
              onDrag: (dx, dy) {
                final newR = (widget.right + dx / w).clamp(widget.left + 0.1, 1.0);
                final newT = (widget.top + dy / h).clamp(0.0, widget.bottom - 0.1);
                widget.onChanged(widget.left, newT, newR, widget.bottom);
              },
            ),

            // Bottom-Left Handle
            _buildHandle(
              x: pixelLeft - handleSize / 2,
              y: pixelBottom - handleSize / 2,
              onDrag: (dx, dy) {
                final newL = (widget.left + dx / w).clamp(0.0, widget.right - 0.1);
                final newB = (widget.bottom + dy / h).clamp(widget.top + 0.1, 1.0);
                widget.onChanged(newL, widget.top, widget.right, newB);
              },
            ),

            // Bottom-Right Handle
            _buildHandle(
              x: pixelRight - handleSize / 2,
              y: pixelBottom - handleSize / 2,
              onDrag: (dx, dy) {
                final newR = (widget.right + dx / w).clamp(widget.left + 0.1, 1.0);
                final newB = (widget.bottom + dy / h).clamp(widget.top + 0.1, 1.0);
                widget.onChanged(widget.left, widget.top, newR, newB);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildHandle({
    required double x,
    required double y,
    required Function(double dx, double dy) onDrag,
  }) {
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (details) => onDrag(details.delta.dx, details.delta.dy),
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryBlue, width: 3),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropBackdropPainter extends CustomPainter {
  final Rect rect;
  _CropBackdropPainter({required this.rect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withAlpha(140);
    final fullRect = Offset.zero & size;
    final path = Path()
      ..addRect(fullRect)
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CropBackdropPainter oldDelegate) => oldDelegate.rect != rect;
}

class _GridLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(90)
      ..strokeWidth = 1.0;

    final stepX = size.width / 3;
    final stepY = size.height / 3;

    canvas.drawLine(Offset(stepX, 0), Offset(stepX, size.height), paint);
    canvas.drawLine(Offset(stepX * 2, 0), Offset(stepX * 2, size.height), paint);
    canvas.drawLine(Offset(0, stepY), Offset(size.width, stepY), paint);
    canvas.drawLine(Offset(0, stepY * 2), Offset(size.width, stepY * 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
