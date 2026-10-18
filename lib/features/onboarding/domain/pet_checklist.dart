import 'package:bowie/features/pets/domain/pet.dart';

/// One essential of a pet's sheet (docs/produto/primeiro-uso.md).
class ChecklistItem {
  const ChecklistItem({
    required this.label,
    required this.done,
    required this.route,
  });

  /// "Foto", "Vacinas".
  final String label;
  final bool done;

  /// Where to fill it in.
  final String route;
}

/// The essentials of the sheet, in the order worth doing them. Medications,
/// allergies and exams are extras: they never count against the sheet.
List<ChecklistItem> petChecklist(Pet pet, {required bool hasVaccines}) => [
  ChecklistItem(
    label: 'Vacinas',
    done: hasVaccines,
    route: '/saude/carteirinha?pet=${pet.id}',
  ),
  ChecklistItem(
    label: 'Foto',
    done: pet.photoPath != null,
    route: '/pets/${pet.id}',
  ),
  ChecklistItem(
    label: 'Nascimento',
    done: pet.birthDate != null,
    route: '/pets/${pet.id}',
  ),
  ChecklistItem(
    label: 'Peso',
    done: pet.weightKg != null,
    route: '/pets/${pet.id}',
  ),
];
