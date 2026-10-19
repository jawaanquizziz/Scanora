enum FilterType {
  original,
  enhance,
  grayscale,
  blackAndWhite,
}

extension FilterTypeExtension on FilterType {
  String get displayName {
    switch (this) {
      case FilterType.original:
        return 'Original';
      case FilterType.enhance:
        return 'Magic';
      case FilterType.grayscale:
        return 'Grayscale';
      case FilterType.blackAndWhite:
        return 'B & W';
    }
  }
}

class ScanPage {
  final String id;
  final String originalImagePath;
  String processedImagePath;
  int rotationAngle; // 0, 90, 180, 270
  FilterType filter;
  // Normalized crop bounds (0.0 to 1.0)
  double cropLeft;
  double cropTop;
  double cropRight;
  double cropBottom;

  ScanPage({
    required this.id,
    required this.originalImagePath,
    required this.processedImagePath,
    this.rotationAngle = 0,
    this.filter = FilterType.original,
    this.cropLeft = 0.0,
    this.cropTop = 0.0,
    this.cropRight = 1.0,
    this.cropBottom = 1.0,
  });

  ScanPage copyWith({
    String? id,
    String? originalImagePath,
    String? processedImagePath,
    int? rotationAngle,
    FilterType? filter,
    double? cropLeft,
    double? cropTop,
    double? cropRight,
    double? cropBottom,
  }) {
    return ScanPage(
      id: id ?? this.id,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      processedImagePath: processedImagePath ?? this.processedImagePath,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      filter: filter ?? this.filter,
      cropLeft: cropLeft ?? this.cropLeft,
      cropTop: cropTop ?? this.cropTop,
      cropRight: cropRight ?? this.cropRight,
      cropBottom: cropBottom ?? this.cropBottom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalImagePath': originalImagePath,
    'processedImagePath': processedImagePath,
    'rotationAngle': rotationAngle,
    'filter': filter.index,
    'cropLeft': cropLeft,
    'cropTop': cropTop,
    'cropRight': cropRight,
    'cropBottom': cropBottom,
  };

  factory ScanPage.fromJson(Map<String, dynamic> json) => ScanPage(
    id: json['id'] as String,
    originalImagePath: json['originalImagePath'] as String,
    processedImagePath: json['processedImagePath'] as String,
    rotationAngle: json['rotationAngle'] as int? ?? 0,
    filter: FilterType.values[json['filter'] as int? ?? 0],
    cropLeft: (json['cropLeft'] as num?)?.toDouble() ?? 0.0,
    cropTop: (json['cropTop'] as num?)?.toDouble() ?? 0.0,
    cropRight: (json['cropRight'] as num?)?.toDouble() ?? 1.0,
    cropBottom: (json['cropBottom'] as num?)?.toDouble() ?? 1.0,
  );
}
