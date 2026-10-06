import 'package:bowie/core/dates.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_age.dart';

/// Birthdays are announced from this many days before (docs/produto/pets.md).
const birthdayNoticeDays = 30;

/// The notice shown for a pet's coming birthday, or null when it is more than
/// 30 days away or the birth date is only an estimate.
///
/// "Faltam 30 dias para o aniversário do Bowie", "Amanhã é o aniversário da
/// Mia", "Hoje é o aniversário do Bowie: 6 anos".
String? birthdayNotice(Pet pet, DateTime today) {
  final birth = pet.birthDate;
  if (birth == null || pet.birthDateEstimated) return null;
  final next = nextBirthday(birth, today);
  final days = daysBetween(today, next);
  if (days > birthdayNoticeDays) return null;
  final of = ofPet(pet);
  if (days == 0) {
    final years = next.year - birth.year;
    if (years < 1) return null;
    return 'Hoje é o aniversário $of: ${years == 1 ? '1 ano' : '$years anos'}';
  }
  if (days == 1) return 'Amanhã é o aniversário $of';
  return 'Faltam $days dias para o aniversário $of';
}
