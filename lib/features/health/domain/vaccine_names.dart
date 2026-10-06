import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/pets/domain/pet.dart';

/// Names offered while typing. Free text is always allowed.
List<String> doseSuggestions(PetSpecies? species, DoseKind kind) {
  if (kind == DoseKind.dewormer) {
    return const ['Vermífugo', 'Drontal', 'Milbemax', 'Endogard', 'Vermivet'];
  }
  return switch (species) {
    PetSpecies.cat => const [
      'V3 (tríplice felina)',
      'V4 (quádrupla felina)',
      'V5 (quíntupla felina)',
      'Raiva',
      'FeLV (leucemia felina)',
    ],
    _ => const [
      'V8',
      'V10',
      'Raiva',
      'Giardíase',
      'Tosse dos canis',
      'Gripe canina',
      'Leishmaniose',
    ],
  };
}

/// How long until the next dose, as a starting point the person can change.
int defaultIntervalMonths(DoseKind kind) => switch (kind) {
  DoseKind.vaccine => 12,
  DoseKind.dewormer => 3,
};
