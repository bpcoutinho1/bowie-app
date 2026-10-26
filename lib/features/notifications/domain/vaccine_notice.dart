import 'package:bowie/core/text.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/pets/domain/pet.dart';

/// Days after the pet is registered before the app asks for its vaccines.
const vaccineNoticeAfterDays = 7;

/// A vaccine every pet of a species should have, and the names that count
/// for it on the card (docs/produto/notificacoes.md#vacinas-que-faltam).
class EssentialVaccine {
  const EssentialVaccine(this.label, this.patterns, {this.suggestion});

  /// "V8 ou V10".
  final String label;

  /// Lowercase, without accents, matched anywhere in the dose's name.
  final List<Pattern> patterns;

  /// The name the form starts with: "V10".
  final String? suggestion;

  bool matches(String name) {
    final folded = foldText(name);
    return patterns.any((pattern) => folded.contains(pattern));
  }
}

/// In order of importance.
final dogEssentials = [
  EssentialVaccine('Raiva', [
    'raiva',
    'antirrabica',
    'anti-rabica',
    'rabica',
    'rabies',
  ], suggestion: 'Raiva'),
  EssentialVaccine('V8 ou V10', [
    RegExp(r'\bv ?(8|10|11|12)\b'),
    'octupla',
    'decupla',
    'polivalente',
  ], suggestion: 'V10'),
  EssentialVaccine('Tosse dos canis', [
    'tosse',
    'bordetel',
    'traqueobronquite',
    RegExp(r'\bkc\b'),
  ], suggestion: 'Tosse dos canis'),
  EssentialVaccine('Giárdia', ['giard'], suggestion: 'Giardíase'),
];

final catEssentials = [
  EssentialVaccine('Raiva', [
    'raiva',
    'antirrabica',
    'anti-rabica',
    'rabica',
    'rabies',
  ], suggestion: 'Raiva'),
  EssentialVaccine('V3, V4 ou V5', [
    RegExp(r'\bv ?(3|4|5)\b'),
    'triplice',
    'quadrupla',
    'quintupla',
  ], suggestion: 'V5 (quíntupla felina)'),
];

List<EssentialVaccine> essentialsFor(PetSpecies species) => switch (species) {
  PetSpecies.dog => dogEssentials,
  PetSpecies.cat => catEssentials,
};

/// "Ainda não tem todas as vacinas": the essentials missing from a pet.
class VaccineNotice {
  const VaccineNotice({required this.pet, required this.missing});

  final Pet pet;

  /// In order of importance, at least one.
  final List<EssentialVaccine> missing;

  /// "O Bowie ainda não tem todas as vacinas cadastradas."
  String get title {
    final article = switch (pet.sex) {
      PetSex.male => 'O ',
      PetSex.female => 'A ',
      null => '',
    };
    return '$article${pet.name} ainda não tem todas as vacinas cadastradas.';
  }

  /// "Faltam: Raiva, V8 ou V10 e Giárdia."
  String get body {
    final names = [for (final vaccine in missing) vaccine.label];
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
    return names.length == 1 ? 'Falta: $list.' : 'Faltam: $list.';
  }
}

/// The notice for [pet], or null: less than 7 days since it was registered
/// (counted in calendar days), species unknown, or every essential vaccine
/// has a dose.
VaccineNotice? vaccineNotice(
  Pet pet,
  Iterable<VaccineDose> doses,
  DateTime today,
) {
  final species = pet.species;
  final created = pet.createdAt;
  if (species == null || created == null) return null;
  DateTime utcDay(DateTime day) => DateTime.utc(day.year, day.month, day.day);
  final since = utcDay(today).difference(utcDay(created.toLocal())).inDays;
  if (since < vaccineNoticeAfterDays) return null;
  final names = [
    for (final dose in doses)
      if (dose.kind == DoseKind.vaccine && dose.deletedAt == null) dose.name,
  ];
  final missing = [
    for (final vaccine in essentialsFor(species))
      if (!names.any(vaccine.matches)) vaccine,
  ];
  return missing.isEmpty ? null : VaccineNotice(pet: pet, missing: missing);
}
