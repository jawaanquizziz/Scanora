import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  Directory? _appDir;
  Directory? _docsDir;
  Directory? _thumbnailsDir;
  Directory? _tempDir;

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      _appDir = await getApplicationDocumentsDirectory();
      _docsDir = Directory('${_appDir!.path}/scanora_documents');
      _thumbnailsDir = Directory('${_appDir!.path}/scanora_thumbnails');
      _tempDir = Directory('${_appDir!.path}/scanora_temp');

      if (!await _docsDir!.exists()) await _docsDir!.create(recursive: true);
      if (!await _thumbnailsDir!.exists()) await _thumbnailsDir!.create(recursive: true);
      if (!await _tempDir!.exists()) await _tempDir!.create(recursive: true);
    } catch (_) {}
  }

  Future<String> get documentsPath async {
    if (_docsDir == null) await init();
    return _docsDir!.path;
  }

  Future<String> get thumbnailsPath async {
    if (_thumbnailsDir == null) await init();
    return _thumbnailsDir!.path;
  }

  Future<String> get tempPath async {
    if (_tempDir == null) await init();
    return _tempDir!.path;
  }

  Future<String> createTempImagePath(String extension) async {
    final tPath = await tempPath;
    final id = DateTime.now().millisecondsSinceEpoch;
    return '$tPath/temp_$id.$extension';
  }

  Future<String> createPdfPath(String sanitizedTitle) async {
    final dPath = await documentsPath;
    var targetPath = '$dPath/$sanitizedTitle.pdf';
    var counter = 1;
    while (await File(targetPath).exists()) {
      targetPath = '$dPath/${sanitizedTitle}_$counter.pdf';
      counter++;
    }
    return targetPath;
  }

  Future<String> createThumbnailPath(String docId) async {
    final tPath = await thumbnailsPath;
    return '$tPath/thumb_$docId.jpg';
  }

  Future<void> clearTempFiles() async {
    if (kIsWeb) return;
    try {
      final tPath = await tempPath;
      final dir = Directory(tPath);
      if (await dir.exists()) {
        final files = dir.listSync();
        for (final f in files) {
          try {
            await f.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<int> getTotalStorageBytes() async {
    if (kIsWeb) return 0;
    int total = 0;
    try {
      if (_appDir == null) await init();
      if (await _docsDir!.exists()) {
        for (final entity in _docsDir!.listSync(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
      if (await _thumbnailsDir!.exists()) {
        for (final entity in _thumbnailsDir!.listSync(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  Future<int> getTempStorageBytes() async {
    if (kIsWeb) return 0;
    int total = 0;
    try {
      if (_tempDir == null) await init();
      if (await _tempDir!.exists()) {
        for (final entity in _tempDir!.listSync(recursive: true)) {
          if (entity is File) {
            total += await entity.length();
          }
        }
      }
    } catch (_) {}
    return total;
  }

  Future<void> deleteDocumentFiles(String filePath, String? thumbnailPath) async {
    if (kIsWeb) return;
    try {
      final pdfFile = File(filePath);
      if (await pdfFile.exists()) {
        await pdfFile.delete();
      }
    } catch (_) {}

    try {
      if (thumbnailPath != null) {
        final thumbFile = File(thumbnailPath);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }
    } catch (_) {}
  }
}
