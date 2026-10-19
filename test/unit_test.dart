import 'package:flutter_test/flutter_test.dart';
import 'package:scanora/core/utils/date_formatter.dart';
import 'package:scanora/core/utils/file_utils.dart';
import 'package:scanora/models/app_settings.dart';
import 'package:scanora/models/document_folder.dart';
import 'package:scanora/models/scan_page.dart';
import 'package:scanora/models/scanned_document.dart';

void main() {
  group('FileUtils Tests', () {
    test('formatFileSize correctly formats bytes', () {
      expect(FileUtils.formatFileSize(500), '500 B');
      expect(FileUtils.formatFileSize(1024), '1.0 KB');
      expect(FileUtils.formatFileSize(1024 * 1024 * 2), '2.0 MB');
    });

    test('sanitizeFileName removes illegal filesystem characters', () {
      expect(FileUtils.sanitizeFileName('My:Scan*File?'), 'My_Scan_File_');
      expect(FileUtils.sanitizeFileName('   '), 'Scan_Doc');
      expect(FileUtils.sanitizeFileName('Normal_File_123'), 'Normal_File_123');
    });
  });

  group('DateFormatter Tests', () {
    test('generateDefaultDocName has expected prefix', () {
      final name = DateFormatter.generateDefaultDocName();
      expect(name.startsWith('Scan_'), isTrue);
    });
  });

  group('Models Serialization Tests', () {
    test('ScannedDocument JSON serialization & deserialization', () {
      final now = DateTime.now();
      final doc = ScannedDocument(
        id: 'doc_123',
        title: 'Invoice',
        filePath: '/data/invoice.pdf',
        thumbnailPath: '/data/thumb.jpg',
        createdAt: now,
        modifiedAt: now,
        pageCount: 3,
        fileSizeBytes: 2048,
        isFavorite: true,
        folderId: 'folder_1',
      );

      final json = doc.toJson();
      final decoded = ScannedDocument.fromJson(json);

      expect(decoded.id, 'doc_123');
      expect(decoded.title, 'Invoice');
      expect(decoded.pageCount, 3);
      expect(decoded.isFavorite, isTrue);
      expect(decoded.folderId, 'folder_1');
    });

    test('ScanPage crop bounds and rotation', () {
      final page = ScanPage(
        id: 'page_1',
        originalImagePath: '/tmp/orig.jpg',
        processedImagePath: '/tmp/proc.jpg',
        rotationAngle: 90,
        filter: FilterType.enhance,
        cropLeft: 0.1,
        cropTop: 0.1,
        cropRight: 0.9,
        cropBottom: 0.9,
      );

      expect(page.rotationAngle, 90);
      expect(page.filter, FilterType.enhance);
      expect(page.filter.displayName, 'Magic');

      final copy = page.copyWith(rotationAngle: 180);
      expect(copy.rotationAngle, 180);
      expect(copy.filter, FilterType.enhance);
    });

    test('DocumentFolder and AppSettings serialization', () {
      final folder = DocumentFolder(
        id: 'f_1',
        name: 'Work',
        colorValue: 0xFF176BFF,
        createdAt: DateTime.now(),
      );
      final fJson = folder.toJson();
      final fDecoded = DocumentFolder.fromJson(fJson);
      expect(fDecoded.name, 'Work');

      final settings = const AppSettings(defaultPageSize: 'Letter');
      final sJson = settings.toJson();
      final sDecoded = AppSettings.fromJson(sJson);
      expect(sDecoded.defaultPageSize, 'Letter');
    });
  });
}
