class SourceCitation {
  final int pageNumber;
  final String snippet;
  final bool isVerified;
  final double relevanceScore;

  const SourceCitation({
    required this.pageNumber,
    required this.snippet,
    this.isVerified = true,
    this.relevanceScore = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'snippet': snippet,
    'isVerified': isVerified,
    'relevanceScore': relevanceScore,
  };

  factory SourceCitation.fromJson(Map<String, dynamic> json) => SourceCitation(
    pageNumber: json['pageNumber'] as int? ?? 1,
    snippet: json['snippet'] as String? ?? '',
    isVerified: json['isVerified'] as bool? ?? true,
    relevanceScore: (json['relevanceScore'] as num?)?.toDouble() ?? 1.0,
  );
}
