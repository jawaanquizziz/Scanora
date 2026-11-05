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

  // Security & Watermark metadata
  final bool isEncrypted;
  final String? password;
  final String? watermarkText;
  final bool isVaultLocked;

  // Google Drive Cloud Sync metadata
  final String? driveFileId;
  final DateTime? syncedAt;
  final String? ownerEmail;

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
    this.isEncrypted = false,
    this.password,
    this.watermarkText,
    this.isVaultLocked = false,
    this.driveFileId,
    this.syncedAt,
    this.ownerEmail,
  });

  bool get isCloudSynced =>
      driveFileId != null &&
      driveFileId!.isNotEmpty &&
      !driveFileId!.startsWith('cloud_backup_');

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
    bool? isEncrypted,
    String? password,
    bool clearPassword = false,
    String? watermarkText,
    bool clearWatermark = false,
    bool? isVaultLocked,
    String? driveFileId,
    DateTime? syncedAt,
    bool clearDriveSync = false,
    String? ownerEmail,
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
      isEncrypted: clearPassword ? false : (isEncrypted ?? this.isEncrypted),
      password: clearPassword ? null : (password ?? this.password),
      watermarkText: clearWatermark ? null : (watermarkText ?? this.watermarkText),
      isVaultLocked: isVaultLocked ?? this.isVaultLocked,
      driveFileId: clearDriveSync ? null : (driveFileId ?? this.driveFileId),
      syncedAt: clearDriveSync ? null : (syncedAt ?? this.syncedAt),
      ownerEmail: ownerEmail ?? this.ownerEmail,
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
    'isEncrypted': isEncrypted,
    'password': password,
    'watermarkText': watermarkText,
    'isVaultLocked': isVaultLocked,
    'driveFileId': driveFileId,
    'syncedAt': syncedAt?.toIso8601String(),
    'ownerEmail': ownerEmail,
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
    isEncrypted: json['isEncrypted'] as bool? ?? false,
    password: json['password'] as String?,
    watermarkText: json['watermarkText'] as String?,
    isVaultLocked: json['isVaultLocked'] as bool? ?? false,
    driveFileId: json['driveFileId'] as String?,
    syncedAt: json['syncedAt'] != null ? DateTime.tryParse(json['syncedAt'] as String) : null,
    ownerEmail: json['ownerEmail'] as String?,
  );
}
