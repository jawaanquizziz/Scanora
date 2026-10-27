class ExtractedPageText {
  final int pageNumber; // 1-based page number
  final String text;
  final bool isOcr;

  const ExtractedPageText({
    required this.pageNumber,
    required this.text,
    this.isOcr = false,
  });

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'text': text,
    'isOcr': isOcr,
  };

  factory ExtractedPageText.fromJson(Map<String, dynamic> json) => ExtractedPageText(
    pageNumber: json['pageNumber'] as int? ?? 1,
    text: json['text'] as String? ?? '',
    isOcr: json['isOcr'] as bool? ?? false,
  );
}

class ExtractedDocumentText {
  final String documentId;
  final String filePath;
  final int totalPages;
  final DateTime extractedAt;
  final int fileModifiedTimestamp;
  final List<ExtractedPageText> pages;

  const ExtractedDocumentText({
    required this.documentId,
    required this.filePath,
    required this.totalPages,
    required this.extractedAt,
    required this.fileModifiedTimestamp,
    required this.pages,
  });

  String get fullText => pages.map((p) => p.text).join('\n\n');

  bool get isEmpty => pages.every((p) => p.text.trim().isEmpty);

  Map<String, dynamic> toJson() => {
    'documentId': documentId,
    'filePath': filePath,
    'totalPages': totalPages,
    'extractedAt': extractedAt.toIso8601String(),
    'fileModifiedTimestamp': fileModifiedTimestamp,
    'pages': pages.map((p) => p.toJson()).toList(),
  };

  factory ExtractedDocumentText.fromJson(Map<String, dynamic> json) => ExtractedDocumentText(
    documentId: json['documentId'] as String? ?? '',
    filePath: json['filePath'] as String? ?? '',
    totalPages: json['totalPages'] as int? ?? 0,
    extractedAt: DateTime.tryParse(json['extractedAt'] as String? ?? '') ?? DateTime.now(),
    fileModifiedTimestamp: json['fileModifiedTimestamp'] as int? ?? 0,
    pages: (json['pages'] as List<dynamic>?)
            ?.map((e) => ExtractedPageText.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
