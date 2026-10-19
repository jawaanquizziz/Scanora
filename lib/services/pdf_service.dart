import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'file_service.dart';

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  Future<File> generatePdf({
    required List<String> imagePaths,
    required String title,
    String pageFormat = 'A4',
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'Scanora',
      creator: 'Scanora Document Scanner',
    );

    final format = pageFormat.toUpperCase() == 'LETTER'
        ? PdfPageFormat.letter
        : PdfPageFormat.a4;

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
              child: pw.Center(
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              ),
            );
          },
        ),
      );
    }

    final fileService = FileService();
    final pdfPath = await fileService.createPdfPath(title);
    final pdfFile = File(pdfPath);
    await pdfFile.writeAsBytes(await pdf.save());

    return pdfFile;
  }
}
