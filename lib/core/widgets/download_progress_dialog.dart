import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DownloadProgressDialog extends StatefulWidget {
  final String documentTitle;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;

  const DownloadProgressDialog({
    super.key,
    required this.documentTitle,
    this.onComplete,
    this.onCancel,
  });

  static Future<bool> show({
    required BuildContext context,
    required String documentTitle,
    VoidCallback? onComplete,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DownloadProgressDialog(
        documentTitle: documentTitle,
        onComplete: onComplete,
        onCancel: () => Navigator.of(ctx).pop(false),
      ),
    );
    return result ?? false;
  }

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double _progress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startSimulatedProgress();
  }

  void _startSimulatedProgress() {
    // Smooth progress simulation to give exact UX matching Image 3
    _timer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 1.0) {
          _progress += 0.035;
          if (_progress > 1.0) _progress = 1.0;
        } else {
          timer.cancel();
          Future.delayed(const Duration(milliseconds: 250), () {
            if (mounted) {
              Navigator.of(context).pop(true);
              widget.onComplete?.call();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (_progress * 100).toInt();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Downloading...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.navy,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),

            // Document Name Subtitle
            Text(
              widget.documentTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 28),

            // Linear Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 5,
                backgroundColor: isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lensOrange),
              ),
            ),
            const SizedBox(height: 10),

            // Progress text: "0%" on left, "0/100" on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ),
                Text(
                  '$percent/100',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Cancel action button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _timer?.cancel();
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    Navigator.of(context).pop(false);
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  foregroundColor: AppColors.lensOrange,
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lensOrange,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
