import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../models/scanned_document.dart';
import 'file_service.dart';
import 'storage_service.dart';

class PdfThumbnailService {
  static final PdfThumbnailService _instance = PdfThumbnailService._internal();
  factory PdfThumbnailService() => _instance;
  PdfThumbnailService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final Set<String> _inFlightGenerations = {};

  Uint8List? getCachedBytes(String docId) => _memoryCache[docId];

  Future<Uint8List?> getOrRenderBytes(ScannedDocument doc) async {
    // 1. If memory cache has it, return immediately
    if (_memoryCache.containsKey(doc.id)) {
      return _memoryCache[doc.id];
    }

    // 2. If thumbnailPath exists on disk, read and cache
    if (!kIsWeb && doc.thumbnailPath != null && doc.thumbnailPath!.isNotEmpty) {
      try {
        final file = File(doc.thumbnailPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          _memoryCache[doc.id] = bytes;
          return bytes;
        }
      } catch (_) {}
    }

    // 3. Otherwise rasterize page 0 from PDF file
    if (!kIsWeb && doc.filePath.isNotEmpty) {
      try {
        final pdfFile = File(doc.filePath);
        if (await pdfFile.exists()) {
          final generatedBytes = await _rasterizeAndSave(doc);
          if (generatedBytes != null) {
            _memoryCache[doc.id] = generatedBytes;
            return generatedBytes;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  Future<Uint8List?> _rasterizeAndSave(ScannedDocument doc) async {
    if (_inFlightGenerations.contains(doc.id)) {
      return null;
    }
    _inFlightGenerations.add(doc.id);

    try {
      final pdfFile = File(doc.filePath);
      final pdfBytes = await pdfFile.readAsBytes();

      final rasterStream = Printing.raster(pdfBytes, pages: [0], dpi: 90);
      await for (final page in rasterStream) {
        final pngBytes = await page.toPng();

        // Save to disk thumbnail path
        final fileService = FileService();
        final thumbPath = await fileService.createThumbnailPath(doc.id);
        final thumbFile = File(thumbPath);
        await thumbFile.writeAsBytes(pngBytes);

        // Update document model in storage in background
        final updatedDoc = doc.copyWith(thumbnailPath: thumbPath);
        Future.microtask(() {
          StorageService().updateDocument(updatedDoc);
        });

        return pngBytes;
      }
    } catch (e) {
      debugPrint('PdfThumbnailService error for ${doc.id}: $e');
    } finally {
      _inFlightGenerations.remove(doc.id);
    }

    return null;
  }

  Future<String?> createThumbnailFromPdf(String pdfPath, String docId) async {
    if (kIsWeb) return null;
    try {
      final pdfFile = File(pdfPath);
      if (!await pdfFile.exists()) return null;

      final pdfBytes = await pdfFile.readAsBytes();
      final rasterStream = Printing.raster(pdfBytes, pages: [0], dpi: 90);
      await for (final page in rasterStream) {
        final pngBytes = await page.toPng();
        final fileService = FileService();
        final thumbPath = await fileService.createThumbnailPath(docId);
        final thumbFile = File(thumbPath);
        await thumbFile.writeAsBytes(pngBytes);
        _memoryCache[docId] = pngBytes;
        return thumbPath;
      }
    } catch (e) {
      debugPrint('Failed to generate thumbnail from PDF: $e');
    }
    return null;
  }
}
