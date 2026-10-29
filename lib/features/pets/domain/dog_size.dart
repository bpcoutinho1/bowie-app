import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_age.dart';

/// The size of a dog by its adult weight (docs/produto/pets.md#porte).
enum DogSize {
  mini('mini', 'Mini'),
  small('small', 'Pequeno'),
  medium('medium', 'Médio'),
  large('large', 'Grande'),
  giant('giant', 'Gigante');

  const DogSize(this.code, this.label);

  /// As saved in the database.
  final String code;
  final String label;

  static DogSize? fromCode(String? code) =>
      values.where((size) => size.code == code).firstOrNull;

  /// "Até 5 kg", "Acima de 25 até 45 kg".
  String get range => switch (this) {
    mini => 'Até 5 kg',
    small => 'Acima de 5 até 10 kg',
    medium => 'Acima de 10 até 25 kg',
    large => 'Acima de 25 até 45 kg',
    giant => 'Acima de 45 kg',
  };
}

/// Up to 5 kg is Mini; above 5 up to 10, Pequeno; above 10 up to 25, Médio;
/// above 25 up to 45, Grande; above 45, Gigante.
DogSize dogSizeForWeight(double kg) {
  if (kg <= 5) return DogSize.mini;
  if (kg <= 10) return DogSize.small;
  if (kg <= 25) return DogSize.medium;
  if (kg <= 45) return DogSize.large;
  return DogSize.giant;
}

/// How the app knows the size.
enum SizeSource {
  /// Chosen by a tutor.
  chosen,

  /// From the current weight.
  weight,

  /// Under 1 year old: the weight does not tell the adult size yet.
  puppy,

  /// No weight yet.
  unknown,
}

/// The size shown for a dog, and where it comes from. Null for cats.
({DogSize? size, SizeSource source})? petSize({
  required PetSpecies? species,
  required DogSize? chosen,
  required double? weightKg,
  required DateTime? birthDate,
  required DateTime today,
}) {
  if (species != PetSpecies.dog) return null;
  if (chosen != null) return (size: chosen, source: SizeSource.chosen);
  if (birthDate != null && ageInYears(birthDate, today) < 1) {
    return (size: null, source: SizeSource.puppy);
  }
  if (weightKg == null) return (size: null, source: SizeSource.unknown);
  return (size: dogSizeForWeight(weightKg), source: SizeSource.weight);
}
