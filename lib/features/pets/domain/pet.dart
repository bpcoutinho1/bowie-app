class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String name;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Pet copyWith({String? name, DateTime? updatedAt, DateTime? deletedAt}) {
    return Pet(
      id: id,
      name: name ?? this.name,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static Pet fromRow(Map<String, Object?> row) {
    return Pet(
      id: row['id']! as String,
      name: row['name']! as String,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: _optionalDate(row['deleted_at']),
    );
  }
}

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String).toUtc();
}
