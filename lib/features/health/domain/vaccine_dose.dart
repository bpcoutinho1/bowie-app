import 'dart:convert';

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
    this.proofPaths = const [],
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

  /// Photos proving the dose was given (the vial sticker and the vet's
  /// stamp), in the private bucket `pet-photos`. Several doses may share a
  /// photo of the same card page. Recommended, not required.
  final List<String> proofPaths;

  bool get hasProof => proofPaths.isNotEmpty;

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
      proofPaths: proofPaths,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  VaccineDose copyWithProofs(List<String> paths) {
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
      proofPaths: paths,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
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
      'proof_paths': jsonEncode(proofPaths),
      'updated_by': updatedBy,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static VaccineDose fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    final rawProofs = row['proof_paths'];
    final proofs = rawProofs is String ? jsonDecode(rawProofs) : rawProofs;
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
      proofPaths: [
        for (final path in (proofs as List?) ?? const [])
          if (path is String) path,
      ],
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}
