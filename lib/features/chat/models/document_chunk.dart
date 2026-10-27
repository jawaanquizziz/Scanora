class DocumentChunk {
  final String chunkId;
  final String documentId;
  final int pageNumber;
  final String text;
  final int tokenEstimate;
  final double score;

  const DocumentChunk({
    required this.chunkId,
    required this.documentId,
    required this.pageNumber,
    required this.text,
    this.tokenEstimate = 0,
    this.score = 0.0,
  });

  DocumentChunk copyWith({
    String? chunkId,
    String? documentId,
    int? pageNumber,
    String? text,
    int? tokenEstimate,
    double? score,
  }) {
    return DocumentChunk(
      chunkId: chunkId ?? this.chunkId,
      documentId: documentId ?? this.documentId,
      pageNumber: pageNumber ?? this.pageNumber,
      text: text ?? this.text,
      tokenEstimate: tokenEstimate ?? this.tokenEstimate,
      score: score ?? this.score,
    );
  }

  Map<String, dynamic> toJson() => {
    'chunkId': chunkId,
    'documentId': documentId,
    'pageNumber': pageNumber,
    'text': text,
    'tokenEstimate': tokenEstimate,
    'score': score,
  };

  factory DocumentChunk.fromJson(Map<String, dynamic> json) => DocumentChunk(
    chunkId: json['chunkId'] as String? ?? '',
    documentId: json['documentId'] as String? ?? '',
    pageNumber: json['pageNumber'] as int? ?? 1,
    text: json['text'] as String? ?? '',
    tokenEstimate: json['tokenEstimate'] as int? ?? 0,
    score: (json['score'] as num?)?.toDouble() ?? 0.0,
  );
}
