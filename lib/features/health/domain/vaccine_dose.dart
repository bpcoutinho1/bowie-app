import 'package:bowie/core/dates.dart';

enum DoseKind {
  vaccine('Vacina'),
  dewormer('Vermífugo');

  const DoseKind(this.label);

  final String label;
}

/// One applied dose of a vaccine or dewormer, as written on the vaccine card.
class VaccineDose {
  const VaccineDose({
    required this.id,
    required this.petId,
    required this.kind,
    required this.name,
    required this.appliedOn,
    required this.nextDueOn,
    required this.updatedAt,
    this.product,
    this.lot,
    this.veterinarian,
    this.notes,
    this.updatedBy,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final DoseKind kind;

  /// "V10", "Raiva", the dewormer's name.
  final String name;
  final DateTime appliedOn;

  /// "Revacinar em" on the card. Drives status and reminders.
  final DateTime nextDueOn;
  final String? product;
  final String? lot;
  final String? veterinarian;
  final String? notes;

  /// The user who saved this version, so tutors can see who changed it.
  final String? updatedBy;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  VaccineDose copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? updatedBy,
  }) {
    return VaccineDose(
      id: id,
      petId: petId,
      kind: kind,
      name: name,
      appliedOn: appliedOn,
      nextDueOn: nextDueOn,
      product: product,
      lot: lot,
      veterinarian: veterinarian,
      notes: notes,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'pet_id': petId,
      'kind': kind.name,
      'name': name,
      'applied_on': formatDay(appliedOn),
      'next_due_on': formatDay(nextDueOn),
      'product': product,
      'lot': lot,
      'veterinarian': veterinarian,
      'notes': notes,
      'updated_by': updatedBy,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static VaccineDose fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    return VaccineDose(
      id: row['id']! as String,
      petId: row['pet_id']! as String,
      kind: DoseKind.values.byName(row['kind']! as String),
      name: row['name']! as String,
      appliedOn: parseDay(row['applied_on']! as String),
      nextDueOn: parseDay(row['next_due_on']! as String),
      product: row['product'] as String?,
      lot: row['lot'] as String?,
      veterinarian: row['veterinarian'] as String?,
      notes: row['notes'] as String?,
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}
