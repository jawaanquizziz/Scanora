import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/extracted_document_text.dart';

class DocumentTextExtractionService {
  static final DocumentTextExtractionService _instance =
      DocumentTextExtractionService._internal();
  factory DocumentTextExtractionService() => _instance;
  DocumentTextExtractionService._internal();

  Directory? _cacheDir;

  Future<Directory> _getCacheDirectory() async {
    if (_cacheDir != null && await _cacheDir!.exists()) {
      return _cacheDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/scanora_text_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  File _getCacheFile(Directory dir, String docId) {
    return File('${dir.path}/text_$docId.json');
  }

  /// Extracts text from the given PDF document page-by-page.
  /// Reuses cached results if available and up-to-date.
  Future<ExtractedDocumentText> extractText({
    required String documentId,
    required String filePath,
    String? thumbnailPath,
    bool forceRefresh = false,
    void Function(int currentPage, int totalPages)? onProgress,
  }) async {
    final pdfFile = File(filePath);
    if (!await pdfFile.exists()) {
      throw FileNotFoundException('PDF file does not exist at: $filePath');
    }

    final cacheDir = await _getCacheDirectory();
    final cacheFile = _getCacheFile(cacheDir, documentId);
    final lastModified = (await pdfFile.lastModified()).millisecondsSinceEpoch;

    // Check cache (only accept if it contains actual non-empty extracted text)
    if (!forceRefresh && await cacheFile.exists()) {
      try {
        final content = await cacheFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final cached = ExtractedDocumentText.fromJson(json);

        final bool hasText = cached.pages.any((p) => p.text.trim().isNotEmpty);
        if (cached.fileModifiedTimestamp == lastModified &&
            cached.pages.isNotEmpty &&
            hasText) {
          return cached;
        }
      } catch (_) {
        // Cache corrupted, fall through to re-extract
      }
    }

    // Read PDF bytes
    final pdfBytes = await pdfFile.readAsBytes();
    final PdfDocument pdfDoc = PdfDocument(inputBytes: pdfBytes);
    final int totalPages = pdfDoc.pages.count;

    final List<ExtractedPageText> extractedPages = [];
    TextRecognizer? textRecognizer;

    try {
      for (int i = 0; i < totalPages; i++) {
        final int oneBasedPage = i + 1;
        onProgress?.call(oneBasedPage, totalPages);

        String pageText = '';
        bool usedOcr = false;

        // 1. Attempt digital text extraction first
        try {
          final digitalText = PdfTextExtractor(pdfDoc).extractText(
            startPageIndex: i,
            endPageIndex: i,
          );
          if (digitalText.trim().length >= 20) {
            pageText = digitalText.trim();
          }
        } catch (_) {
          // Digital extraction failed or unsupported format
        }

        // 2. If page has no digital text (scanned image), use Google ML Kit OCR on high-res raster
        if (pageText.isEmpty && !kIsWeb) {
          try {
            textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

            // Rasterize at 220 DPI to guarantee sharp OCR on dense tables, roll numbers, and names
            final rasterStream = Printing.raster(pdfBytes, pages: [i], dpi: 220);
            await for (final rasterPage in rasterStream) {
              final imageBytes = await rasterPage.toPng();
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/ocr_page_${documentId}_$i.png');
              await tempFile.writeAsBytes(imageBytes);

              try {
                final inputImage = InputImage.fromFilePath(tempFile.path);
                final recognized = await textRecognizer.processImage(inputImage);
                if (recognized.text.trim().isNotEmpty) {
                  pageText = recognized.text.trim();
                  usedOcr = true;
                  debugPrint('High-Res OCR extracted from page $i: ${pageText.length} chars');
                }
              } finally {
                if (await tempFile.exists()) {
                  await tempFile.delete();
                }
              }
              break;
            }
          } catch (e) {
            debugPrint('Raster OCR note for page $i: $e');
          }
        }

        extractedPages.add(
          ExtractedPageText(
            pageNumber: oneBasedPage,
            text: pageText,
            isOcr: usedOcr,
          ),
        );
      }
    } finally {
      pdfDoc.dispose();
      await textRecognizer?.close();
    }

    final result = ExtractedDocumentText(
      documentId: documentId,
      filePath: filePath,
      totalPages: totalPages,
      extractedAt: DateTime.now(),
      fileModifiedTimestamp: lastModified,
      pages: extractedPages,
    );

    // Write to cache
    try {
      await cacheFile.writeAsString(jsonEncode(result.toJson()));
    } catch (_) {}

    return result;
  }

  /// Invalidate and remove cached text for a specific document.
  Future<void> clearCacheForDocument(String documentId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = _getCacheFile(cacheDir, documentId);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (_) {}
  }

  /// Invalidate and remove all cached extracted texts.
  Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        final files = cacheDir.listSync();
        for (final f in files) {
          if (f is File) {
            await f.delete();
          }
        }
      }
    } catch (_) {}
  }
}

class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);
  @override
  String toString() => 'FileNotFoundException: $message';
}
