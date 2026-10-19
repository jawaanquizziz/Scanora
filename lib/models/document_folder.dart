class DocumentFolder {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;

  DocumentFolder({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  DocumentFolder copyWith({
    String? id,
    String? name,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return DocumentFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DocumentFolder.fromJson(Map<String, dynamic> json) => DocumentFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    colorValue: json['colorValue'] as int? ?? 0xFFEA580C,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}
