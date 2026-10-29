import 'package:bowie/core/dates.dart';
import 'package:bowie/features/pets/domain/dog_size.dart';

enum PetSpecies {
  dog('Cão'),
  cat('Gato');

  const PetSpecies(this.label);

  final String label;
}

enum PetSex {
  male('Macho'),
  female('Fêmea');

  const PetSex(this.label);

  final String label;
}

/// "do Bowie", "da Mia", or "de Luna" while the sex is unknown.
String ofPet(Pet pet) => switch (pet.sex) {
  PetSex.male => 'do ${pet.name}',
  PetSex.female => 'da ${pet.name}',
  null => 'de ${pet.name}',
};

class Pet {
  const Pet({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.species,
    this.sex,
    this.breed,
    this.birthDate,
    this.birthDateEstimated = false,
    this.weightKg,
    this.size,
    this.photoPath,
    this.createdAt,
    this.deletedAt,
  });

  final String id;
  final String name;

  /// Null only for pets created before these fields existed.
  final PetSpecies? species;
  final PetSex? sex;
  final String? breed;

  /// A calendar day. When [birthDateEstimated] is true it was derived from an
  /// approximate age in years.
  final DateTime? birthDate;
  final bool birthDateEstimated;
  final double? weightKg;

  /// The size a tutor chose for a dog. Null means it follows the weight
  /// (see [petSize]).
  final DogSize? size;

  /// Where the profile photo is in the private bucket `pet-photos`:
  /// `<pet id>/<photo id>.jpg`. The phone keeps a copy (see PetPhotoStore).
  final String? photoPath;

  /// When the pet was registered, as the server keeps it. Null for a pet that
  /// came from the server before the app kept this.
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Pet copyWith({
    String? name,
    PetSpecies? species,
    PetSex? sex,
    String? breed,
    DateTime? birthDate,
    bool? birthDateEstimated,
    double? weightKg,
    DogSize? size,
    String? photoPath,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearBreed = false,
    bool clearWeight = false,
    bool clearSize = false,
    bool clearPhoto = false,
  }) {
    return Pet(
      id: id,
      name: name ?? this.name,
      species: species ?? this.species,
      sex: sex ?? this.sex,
      breed: clearBreed ? null : breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      birthDateEstimated: birthDateEstimated ?? this.birthDateEstimated,
      weightKg: clearWeight ? null : weightKg ?? this.weightKg,
      size: clearSize ? null : size ?? this.size,
      photoPath: clearPhoto ? null : photoPath ?? this.photoPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'name': name,
      'species': species?.name,
      'sex': sex?.name,
      'breed': breed,
      'birth_date': birthDate == null ? null : formatDay(birthDate!),
      'birth_date_estimated': birthDateEstimated,
      'weight_kg': weightKg,
      'size': size?.code,
      'photo_path': photoPath,
      // The server sets it on insert; sending none keeps what it has.
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static Pet fromRow(Map<String, Object?> row) {
    final species = row['species'] as String?;
    final sex = row['sex'] as String?;
    final birth = row['birth_date'] as String?;
    final weight = row['weight_kg'];
    return Pet(
      id: row['id']! as String,
      name: row['name']! as String,
      species: species == null ? null : PetSpecies.values.byName(species),
      sex: sex == null ? null : PetSex.values.byName(sex),
      breed: row['breed'] as String?,
      birthDate: birth == null ? null : parseDay(birth),
      birthDateEstimated: _bool(row['birth_date_estimated']),
      weightKg: weight == null ? null : (weight as num).toDouble(),
      size: DogSize.fromCode(row['size'] as String?),
      photoPath: row['photo_path'] as String?,
      createdAt: _optionalDate(row['created_at']),
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: _optionalDate(row['deleted_at']),
    );
  }
}

/// SQLite stores booleans as 0/1; Postgres sends true/false.
bool _bool(Object? value) => value == true || value == 1;

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  return DateTime.parse(value as String).toUtc();
}
