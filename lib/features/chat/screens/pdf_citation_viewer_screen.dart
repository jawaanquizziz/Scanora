import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:scanora/core/theme/app_colors.dart';
import 'package:scanora/models/scanned_document.dart';

class PdfCitationViewerScreen extends StatefulWidget {
  final ScannedDocument document;
  final int targetPageNumber; // 1-based page number
  final String? snippet;

  const PdfCitationViewerScreen({
    super.key,
    required this.document,
    required this.targetPageNumber,
    this.snippet,
  });

  @override
  State<PdfCitationViewerScreen> createState() => _PdfCitationViewerScreenState();
}

class _PdfCitationViewerScreenState extends State<PdfCitationViewerScreen> {
  bool _showOnlyTargetPage = false;

  @override
  Widget build(BuildContext context) {
    final file = File(widget.document.filePath);
    final fileExists = file.existsSync();
    final int zeroBasedPage = (widget.targetPageNumber - 1).clamp(0, widget.document.pageCount - 1);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Page ${widget.targetPageNumber} Citation',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.document.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showOnlyTargetPage = !_showOnlyTargetPage;
              });
            },
            icon: Icon(
              _showOnlyTargetPage ? Icons.filter_none_outlined : Icons.filter_1_outlined,
              size: 18,
            ),
            label: Text(
              _showOnlyTargetPage ? 'All Pages' : 'Page ${widget.targetPageNumber} Only',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner showing the verified cited evidence snippet
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Source: Page ${widget.targetPageNumber} of ${widget.document.pageCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (widget.snippet != null && widget.snippet!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '"${widget.snippet}"',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: !fileExists
                ? const Center(
                    child: Text(
                      'PDF file not found on device.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  )
                : PdfPreview(
                    build: (format) => file.readAsBytes(),
                    pages: _showOnlyTargetPage ? [zeroBasedPage] : null,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    dynamicLayout: false,
                    scrollViewDecoration: const BoxDecoration(
                      color: Color(0xFF1E2026),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
