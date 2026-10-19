class ScannedDocument {
  final String id;
  final String title;
  final String filePath; // PDF path
  final String? thumbnailPath;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int pageCount;
  final int fileSizeBytes;
  final bool isFavorite;
  final String? folderId;

  ScannedDocument({
    required this.id,
    required this.title,
    required this.filePath,
    this.thumbnailPath,
    required this.createdAt,
    required this.modifiedAt,
    required this.pageCount,
    this.fileSizeBytes = 0,
    this.isFavorite = false,
    this.folderId,
  });

  ScannedDocument copyWith({
    String? id,
    String? title,
    String? filePath,
    String? thumbnailPath,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? pageCount,
    int? fileSizeBytes,
    bool? isFavorite,
    String? folderId,
    bool clearFolder = false,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      pageCount: pageCount ?? this.pageCount,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isFavorite: isFavorite ?? this.isFavorite,
      folderId: clearFolder ? null : (folderId ?? this.folderId),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'thumbnailPath': thumbnailPath,
    'createdAt': createdAt.toIso8601String(),
    'modifiedAt': modifiedAt.toIso8601String(),
    'pageCount': pageCount,
    'fileSizeBytes': fileSizeBytes,
    'isFavorite': isFavorite,
    'folderId': folderId,
  };

  factory ScannedDocument.fromJson(Map<String, dynamic> json) => ScannedDocument(
    id: json['id'] as String,
    title: json['title'] as String,
    filePath: json['filePath'] as String,
    thumbnailPath: json['thumbnailPath'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    modifiedAt: DateTime.tryParse(json['modifiedAt'] as String? ?? '') ?? DateTime.now(),
    pageCount: json['pageCount'] as int? ?? 1,
    fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
    isFavorite: json['isFavorite'] as bool? ?? false,
    folderId: json['folderId'] as String?,
  );
}
