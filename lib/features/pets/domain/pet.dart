enum PetSpecies {
  dog('Cão'),
  cat('Gato');

  const PetSpecies(this.label);

  final String label;
}

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.species,
    this.breed,
    this.birthDate,
    this.birthDateEstimated = false,
    this.weightKg,
    this.deletedAt,
  });

  final String id;
  final String name;

  /// Null only for pets created before these fields existed.
  final PetSpecies? species;
  final String? breed;

  /// A calendar day. When [birthDateEstimated] is true it was derived from an
  /// approximate age in years.
  final DateTime? birthDate;
  final bool birthDateEstimated;
  final double? weightKg;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Pet copyWith({
    String? name,
    PetSpecies? species,
    String? breed,
    DateTime? birthDate,
    bool? birthDateEstimated,
    double? weightKg,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearBreed = false,
    bool clearWeight = false,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: clearBreed ? null : breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      birthDateEstimated: birthDateEstimated ?? this.birthDateEstimated,
      weightKg: clearWeight ? null : weightKg ?? this.weightKg,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'species': species?.name,
      'breed': breed,
      'birth_date': birthDate == null ? null : formatDay(birthDate!),
      'birth_date_estimated': birthDateEstimated,
      'weight_kg': weightKg,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static Pet fromRow(Map<String, Object?> row) {
    final species = row['species'] as String?;
    final birth = row['birth_date'] as String?;
    final weight = row['weight_kg'];
    return Pet(
      id: row['id']! as String,
      name: row['name']! as String,
      species: species == null ? null : PetSpecies.values.byName(species),
      breed: row['breed'] as String?,
      birthDate: birth == null ? null : parseDay(birth),
      birthDateEstimated: _bool(row['birth_date_estimated']),
      weightKg: weight == null ? null : (weight as num).toDouble(),
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: _optionalDate(row['deleted_at']),
    );
  }
}

/// `yyyy-mm-dd`, the format Postgres uses for `date`.
String formatDay(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-${two(day.month)}-${two(day.day)}';
}

DateTime parseDay(String value) {
  final day = DateTime.parse(value.substring(0, 10));
  return DateTime(day.year, day.month, day.day);
}

/// SQLite stores booleans as 0/1; Postgres sends true/false.
bool _bool(Object? value) => value == true || value == 1;

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String).toUtc();
}
