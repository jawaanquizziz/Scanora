import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect, Size;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'file_service.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  /// Generates a PDF from a list of image paths with optional diagonal
  /// anti-fraud watermark and password encryption.
  Future<File> generatePdf({
    required List<String> imagePaths,
    required String title,
    String pageFormat = 'A4',
    String? watermarkText,
    String? password,
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'Scanora',
      creator: 'Scanora Document Scanner',
    );

    final format = pageFormat.toUpperCase() == 'LETTER'
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;

    final hasWatermark = watermarkText != null && watermarkText.trim().isNotEmpty;
    final cleanWatermark = watermarkText?.trim().toUpperCase() ?? '';

    for (final path in imagePaths) {
      final file = File(path);
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                fit: pw.StackFit.expand,
                children: [
                  pw.Center(
                    child: pw.Image(
                      image,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                  if (hasWatermark)
                    pw.Center(
                      child: pw.Transform.rotate(
                        angle: -math.pi / 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: const PdfColor(0.85, 0.15, 0.15, 0.28),
                              width: 3,
                            ),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Text(
                            cleanWatermark,
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 38,
                              fontWeight: pw.FontWeight.bold,
                              color: const PdfColor(0.85, 0.15, 0.15, 0.28),
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }

    final rawBytes = Uint8List.fromList(await pdf.save());
    final fileService = FileService();
    final pdfPath = await fileService.createPdfPath(title);
    final pdfFile = File(pdfPath);

    if (password != null && password.trim().isNotEmpty) {
      final cleanPassword = password.trim();
      // Save unencrypted sidecar in private storage for instant, lossless internal preview after password verification
      try {
        await File('$pdfPath.unlocked').writeAsBytes(rawBytes);
      } catch (_) {}

      final encryptedBytes = _encryptBytes(rawBytes, cleanPassword);
      await pdfFile.writeAsBytes(encryptedBytes);
    } else {
      await pdfFile.writeAsBytes(rawBytes);
    }

    return pdfFile;
  }

  /// Applies a diagonal watermark and/or password protection to an existing PDF file
  /// (e.g. a PDF returned directly by Google ML Kit Document Scanner or edited in PdfViewerScreen).
  Future<File> applySecurityOrWatermarkToPdf({
    required String pdfPath,
    String? watermarkText,
    String? password,
    String? currentPassword,
  }) async {
    final pdfFile = File(pdfPath);
    final unlockedSidecar = File('$pdfPath.unlocked');

    Uint8List sourceBytes;
    if (await unlockedSidecar.exists()) {
      sourceBytes = await unlockedSidecar.readAsBytes();
    } else {
      sourceBytes = await pdfFile.readAsBytes();
    }

    // Open document with Syncfusion (strip existing password if needed)
    sf.PdfDocument sfDoc;
    try {
      sfDoc = sf.PdfDocument(
        inputBytes: sourceBytes,
        password: currentPassword?.trim(),
      );
    } catch (_) {
      sfDoc = sf.PdfDocument(inputBytes: sourceBytes);
    }

    // Apply diagonal watermark across all pages if requested
    if (watermarkText != null && watermarkText.trim().isNotEmpty) {
      final cleanWatermark = watermarkText.trim().toUpperCase();
      final font = sf.PdfStandardFont(
        sf.PdfFontFamily.helvetica,
        36,
        style: sf.PdfFontStyle.bold,
      );
      final brush = sf.PdfSolidBrush(sf.PdfColor(215, 38, 38));
      final pen = sf.PdfPen(sf.PdfColor(215, 38, 38), width: 2.5);

      for (int i = 0; i < sfDoc.pages.count; i++) {
        final page = sfDoc.pages[i];
        final pageSize = page.getClientSize();
        final graphics = page.graphics;

        graphics.save();
        graphics.setTransparency(0.24);
        graphics.translateTransform(pageSize.width / 2, pageSize.height / 2);
        graphics.rotateTransform(-38);

        final textSize = font.measureString(cleanWatermark);
        final boxWidth = textSize.width + 36;
        final boxHeight = textSize.height + 18;

        graphics.drawRectangle(
          pen: pen,
          bounds: Rect.fromCenter(
            center: Offset.zero,
            width: boxWidth,
            height: boxHeight,
          ),
        );
        graphics.drawString(
          cleanWatermark,
          font,
          brush: brush,
          bounds: Rect.fromCenter(
            center: Offset.zero,
            width: boxWidth,
            height: textSize.height,
          ),
          format: sf.PdfStringFormat(
            alignment: sf.PdfTextAlignment.center,
            lineAlignment: sf.PdfVerticalAlignment.middle,
          ),
        );
        graphics.restore();
      }
    }

    // Save clean unencrypted bytes first
    sfDoc.security.userPassword = '';
    sfDoc.security.ownerPassword = '';
    final cleanBytes = Uint8List.fromList(sfDoc.saveSync());
    sfDoc.dispose();

    if (password != null && password.trim().isNotEmpty) {
      final cleanPassword = password.trim();
      try {
        await unlockedSidecar.writeAsBytes(cleanBytes);
      } catch (_) {}
      final encryptedBytes = _encryptBytes(cleanBytes, cleanPassword);
      await pdfFile.writeAsBytes(encryptedBytes);
    } else {
      try {
        if (await unlockedSidecar.exists()) {
          await unlockedSidecar.delete();
        }
      } catch (_) {}
      await pdfFile.writeAsBytes(cleanBytes);
    }

    return pdfFile;
  }

  Uint8List _encryptBytes(Uint8List cleanBytes, String cleanPassword) {
    try {
      final sfDoc = sf.PdfDocument(inputBytes: cleanBytes);
      final security = sfDoc.security;
      // Use AES-128 with distinct owner password to avoid Syncfusion R6 user==owner collision bug
      security.algorithm = sf.PdfEncryptionAlgorithm.aesx128Bit;
      security.userPassword = cleanPassword;
      security.ownerPassword = '${cleanPassword}_scanora_owner';
      final encrypted = Uint8List.fromList(sfDoc.saveSync());
      sfDoc.dispose();
      return encrypted;
    } catch (_) {
      return cleanBytes;
    }
  }

  /// Verifies the password and returns decrypted PDF bytes for rendering in `PdfPreview`.
  /// Returns `null` if the password is incorrect.
  Future<Uint8List?> unlockPdf({
    required String filePath,
    required String enteredPassword,
    String? expectedPassword,
  }) async {
    final cleanEntered = enteredPassword.trim();
    if (cleanEntered.isEmpty) return null;

    // 1. If we have the expected password stored in ScannedDocument metadata,
    // verify against it directly (case-sensitive, trimmed).
    if (expectedPassword != null && expectedPassword.trim().isNotEmpty) {
      if (cleanEntered != expectedPassword.trim()) {
        return null; // Wrong password
      }

      // Password matches! Return the unencrypted sidecar if available
      final sidecar = File('$filePath.unlocked');
      if (await sidecar.exists()) {
        return await sidecar.readAsBytes();
      }
    }

    // 2. Otherwise (or if no sidecar exists), read the PDF file and decrypt
    final file = File(filePath);
    if (!await file.exists()) return null;
    final encryptedBytes = await file.readAsBytes();

    final decrypted = decryptPdfBytes(
      encryptedBytes,
      cleanEntered,
      expectedPassword: expectedPassword,
    );

    // Cache the unlocked sidecar for future fast unlocks if decryption succeeded
    if (decrypted != null) {
      try {
        await File('$filePath.unlocked').writeAsBytes(decrypted);
      } catch (_) {}
    }

    return decrypted;
  }

  /// Synchronously decrypts PDF bytes with [password].
  /// Handles both AES-128 and legacy AES-256 Syncfusion documents cleanly.
  Uint8List? decryptPdfBytes(
    Uint8List encryptedBytes,
    String password, {
    String? expectedPassword,
  }) {
    final cleanPassword = password.trim();
    if (cleanPassword.isEmpty) return null;

    if (expectedPassword != null &&
        expectedPassword.trim().isNotEmpty &&
        cleanPassword != expectedPassword.trim()) {
      return null;
    }

    // Attempt 1: Open with user password in Syncfusion
    sf.PdfDocument? sfDoc;
    try {
      sfDoc = sf.PdfDocument(inputBytes: encryptedBytes, password: cleanPassword);
    } catch (_) {
      // Check if the PDF bytes were already unencrypted (e.g. app-level password lock)
      if (expectedPassword != null && cleanPassword == expectedPassword.trim()) {
        try {
          final unencDoc = sf.PdfDocument(inputBytes: encryptedBytes);
          unencDoc.dispose();
          return encryptedBytes;
        } catch (_) {}
      }
      return null;
    }

    // Password was accepted by Syncfusion! Now strip encryption for PdfPreview:
    try {
      sfDoc.security.userPassword = '';
      sfDoc.security.ownerPassword = '';
      final out = Uint8List.fromList(sfDoc.saveSync());
      sfDoc.dispose();

      // Verify the saved bytes can be opened without a password
      final verifyDoc = sf.PdfDocument(inputBytes: out);
      verifyDoc.dispose();
      return out;
    } catch (_) {
      // Fallback for Syncfusion AES-256 userPassword == ownerPassword bug:
      // Clone pages via template into a brand new unencrypted PdfDocument
      try {
        final newDoc = sf.PdfDocument();
        newDoc.pageSettings.margins.all = 0;
        for (int i = 0; i < sfDoc.pages.count; i++) {
          final srcPage = sfDoc.pages[i];
          final template = srcPage.createTemplate();
          newDoc.pageSettings.size = Size(srcPage.size.width, srcPage.size.height);
          final dstPage = newDoc.pages.add();
          dstPage.graphics.drawPdfTemplate(template, Offset.zero);
        }
        final clonedBytes = Uint8List.fromList(newDoc.saveSync());
        newDoc.dispose();
        sfDoc.dispose();
        return clonedBytes;
      } catch (_) {
        sfDoc.dispose();
        return null;
      }
    }
  }
}
