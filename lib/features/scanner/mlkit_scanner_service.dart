import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/file_utils.dart';
import '../../core/widgets/custom_dialogs.dart';
import '../../models/scanned_document.dart';
import '../../services/file_service.dart';
import '../../services/image_service.dart';
import '../../services/pdf_service.dart';
import '../../services/pdf_thumbnail_service.dart';
import '../../services/storage_service.dart';
import 'capture_service.dart';
import 'page_review_screen.dart';

class MlKitScanResult {
  final List<String> imagePaths;
  final String? pdfPath;
  final ScannedDocument? document;

  const MlKitScanResult({
    required this.imagePaths,
    this.pdfPath,
    this.document,
  });
}

/// Service that encapsulates the Google ML Kit Document Scanner API on Android,
/// with fallback support for non-Android platforms.
class MlKitScannerService {
  /// Starts the Google ML Kit Document Scanner session.
  ///
  /// Uses native Google Play Services ML Kit Document Scanner on Android:
  /// - Automatic document detection & quad corner cropping
  /// - Real-time perspective correction & stain removal
  /// - Built-in native filters (Color, Grayscale, Monochrome/B&W)
  /// - Automatic & manual capture modes
  /// - Multi-page scanning (up to 100 pages per session)
  /// - PDF and JPEG output enabled simultaneously
  static Future<ScannedDocument?> startScan({
    required BuildContext context,
    String? customTitle,
    String? folderId,
  }) async {
    // Check if running on Android
    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (!isAndroid) {
      return _runDesktopFallback(
        context: context,
        customTitle: customTitle,
        folderId: folderId,
      );
    }

    DocumentScanner? documentScanner;
    try {
      // Configure ML Kit options per specifications:
      // - mode: full (detection, auto-capture, cropping, perspective correction, filters)
      // - formats: both PDF and JPEG
      // - pageLimit: 100 (Google ML Kit maximum allowed pages)
      // - isGalleryImport: true (permits selecting photos from gallery directly in scanner UI)
      final options = DocumentScannerOptions(
        mode: ScannerMode.full,
        documentFormats: {DocumentFormat.pdf, DocumentFormat.jpeg},
        pageLimit: 100,
        isGalleryImport: true,
      );

      documentScanner = DocumentScanner(options: options);

      final DocumentScanningResult result = await documentScanner.scanDocument();

      final pdfUri = result.pdf?.uri;
      final images = result.images ?? [];

      // Check for user cancellation or empty output
      if ((pdfUri == null || pdfUri.isEmpty) && images.isEmpty) {
        return null;
      }

      // Prompt user to name / rename the PDF file BEFORE generating and saving it
      if (!context.mounted) return null;

      final defaultName = customTitle?.trim().isNotEmpty == true
          ? FileUtils.sanitizeFileName(customTitle!.trim())
          : DateFormatter.generateDefaultDocName();

      final pageCount = result.pdf?.pageCount ?? (images.isNotEmpty ? images.length : 1);

      final chosenName = await CustomDialogs.showPdfNamingDialog(
        context: context,
        defaultName: defaultName,
        pageCount: pageCount,
      );

      // User cancelled the naming prompt
      if (chosenName == null) {
        return null;
      }

      final docTitle = chosenName.trim().isNotEmpty
          ? FileUtils.sanitizeFileName(chosenName.trim())
          : defaultName;

      final fileService = FileService();
      final storage = StorageService();

      // Resolve final local PDF path
      String finalPdfPath;

      if (pdfUri != null && pdfUri.isNotEmpty) {
        // Normalize file URI if necessary
        String cleanPath = pdfUri;
        if (cleanPath.startsWith('file://')) {
          cleanPath = Uri.parse(cleanPath).toFilePath();
        }

        final sourcePdfFile = File(cleanPath);
        if (await sourcePdfFile.exists()) {
          final managedPath = await fileService.createPdfPath(docTitle);
          final copied = await sourcePdfFile.copy(managedPath);
          finalPdfPath = copied.path;
        } else if (images.isNotEmpty) {
          // Fallback: build PDF from images
          final generated = await PdfService().generatePdf(
            imagePaths: images,
            title: docTitle,
          );
          finalPdfPath = generated.path;
        } else {
          return null;
        }
      } else if (images.isNotEmpty) {
        // ML Kit returned JPEG images only; assemble PDF with Scanora's PdfService
        final generated = await PdfService().generatePdf(
          imagePaths: images,
          title: docTitle,
        );
        finalPdfPath = generated.path;
      } else {
        return null;
      }

      final pdfFile = File(finalPdfPath);
      final fileSize = await pdfFile.length();
      final docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';

      // Generate thumbnail from first scanned page or rasterize from PDF
      String? thumbPath;
      if (images.isNotEmpty) {
        try {
          thumbPath = await ImageService().createThumbnail(images.first, docId);
        } catch (_) {}
      }
      if (thumbPath == null && finalPdfPath.isNotEmpty) {
        try {
          thumbPath = await PdfThumbnailService().createThumbnailFromPdf(finalPdfPath, docId);
        } catch (_) {}
      }

      // Create ScannedDocument model for local storage
      final scannedDoc = ScannedDocument(
        id: docId,
        title: docTitle,
        filePath: finalPdfPath,
        thumbnailPath: thumbPath,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        pageCount: pageCount,
        fileSizeBytes: fileSize,
        folderId: folderId,
      );

      // Persist document to local storage immediately
      await storage.addDocument(scannedDoc);

      return scannedDoc;
    } on PlatformException catch (e) {
      // User cancelled the ML Kit native flow
      if (e.code == 'CANCELED' || e.code == 'RESULT_CANCELED' || e.message?.contains('cancel') == true) {
        return null;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document scanner: ${e.message ?? e.code}')),
        );
      }
      return null;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanning failed: $e')),
        );
      }
      return null;
    } finally {
      try {
        await documentScanner?.close();
      } catch (_) {}
    }
  }

  /// Cross-platform fallback for Windows/macOS/Linux/Web where ML Kit Document Scanner
  /// is not supported (ML Kit is Android only).
  static Future<ScannedDocument?> _runDesktopFallback({
    required BuildContext context,
    String? customTitle,
    String? folderId,
  }) async {
    if (!context.mounted) return null;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Document Scanner is Android-only. Opening capture fallback on this platform.',
        ),
        duration: Duration(seconds: 3),
      ),
    );

    final page = await CaptureService.captureFromCamera(context);
    if (page != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PageReviewScreen(initialPages: [page]),
        ),
      );
    }
    return null;
  }
}
