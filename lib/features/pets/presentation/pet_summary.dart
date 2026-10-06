import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_age.dart';

/// "Cão · Border Collie · 5 anos". Empty for pets saved before the profile.
String petSummary(Pet pet, DateTime today) {
  final birth = pet.birthDate;
  return [
    ?pet.species?.label,
    ?pet.breed,
    if (birth != null)
      describeAge(birth, today, estimated: pet.birthDateEstimated),
  ].join(' · ');
}
