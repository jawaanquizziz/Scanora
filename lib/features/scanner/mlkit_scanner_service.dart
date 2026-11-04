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
import '../../services/google_drive_service.dart';
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
  static Future<ScannedDocument?> startScan({
    required BuildContext context,
    String? customTitle,
    String? folderId,
  }) async {
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

      if ((pdfUri == null || pdfUri.isEmpty) && images.isEmpty) {
        return null;
      }

      if (!context.mounted) return null;

      final defaultName = customTitle?.trim().isNotEmpty == true
          ? FileUtils.sanitizeFileName(customTitle!.trim())
          : DateFormatter.generateDefaultDocName();

      final pageCount = result.pdf?.pageCount ?? (images.isNotEmpty ? images.length : 1);

      final saveConfig = await CustomDialogs.showPdfSaveConfigDialog(
        context: context,
        defaultName: defaultName,
        pageCount: pageCount,
      );

      // User cancelled the save prompt
      if (saveConfig == null) {
        return null;
      }

      final docTitle = saveConfig.title.trim().isNotEmpty
          ? FileUtils.sanitizeFileName(saveConfig.title.trim())
          : defaultName;

      final fileService = FileService();
      final storage = StorageService();
      final docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';

      // Generate thumbnail from first scanned image BEFORE any PDF encryption
      String? thumbPath;
      if (images.isNotEmpty) {
        try {
          thumbPath = await ImageService().createThumbnail(images.first, docId);
        } catch (_) {}
      }

      // Resolve final local PDF path
      String finalPdfPath;

      if (pdfUri != null && pdfUri.isNotEmpty) {
        String cleanPath = pdfUri;
        if (cleanPath.startsWith('file://')) {
          cleanPath = Uri.parse(cleanPath).toFilePath();
        }

        final sourcePdfFile = File(cleanPath);
        if (await sourcePdfFile.exists()) {
          final managedPath = await fileService.createPdfPath(docTitle);
          final copied = await sourcePdfFile.copy(managedPath);
          finalPdfPath = copied.path;

          // Generate thumbnail from unencrypted PDF if not already created from JPEG
          if (thumbPath == null) {
            try {
              thumbPath = await PdfThumbnailService().createThumbnailFromPdf(
                finalPdfPath,
                docId,
              );
            } catch (_) {}
          }

          // Apply Watermark and/or Password encryption if selected
          if ((saveConfig.watermarkText != null && saveConfig.watermarkText!.isNotEmpty) ||
              (saveConfig.password != null && saveConfig.password!.isNotEmpty)) {
            await PdfService().applySecurityOrWatermarkToPdf(
              pdfPath: finalPdfPath,
              watermarkText: saveConfig.watermarkText,
              password: saveConfig.password,
            );
          }
        } else if (images.isNotEmpty) {
          final generated = await PdfService().generatePdf(
            imagePaths: images,
            title: docTitle,
            watermarkText: saveConfig.watermarkText,
            password: saveConfig.password,
          );
          finalPdfPath = generated.path;
        } else {
          return null;
        }
      } else if (images.isNotEmpty) {
        final generated = await PdfService().generatePdf(
          imagePaths: images,
          title: docTitle,
          watermarkText: saveConfig.watermarkText,
          password: saveConfig.password,
        );
        finalPdfPath = generated.path;
      } else {
        return null;
      }

      final pdfFile = File(finalPdfPath);
      final fileSize = await pdfFile.length();

      // Check if target folder is a locked vault folder
      bool isVaultDoc = false;
      if (folderId != null) {
        final folder = storage.folders.where((f) => f.id == folderId).firstOrNull;
        if (folder != null && folder.isLocked) {
          isVaultDoc = true;
        }
      }

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
        isEncrypted: saveConfig.password != null && saveConfig.password!.isNotEmpty,
        password: saveConfig.password,
        watermarkText: saveConfig.watermarkText,
        isVaultLocked: isVaultDoc,
      );

      // Persist document to local storage immediately
      await storage.addDocument(scannedDoc);

      // Background sync to Google Drive if signed in and enabled
      if (saveConfig.syncToDrive && GoogleDriveService().isSignedIn) {
        GoogleDriveService().uploadDocument(scannedDoc);
      }

      return scannedDoc;
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' ||
          e.code == 'RESULT_CANCELED' ||
          e.message?.contains('cancel') == true) {
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
