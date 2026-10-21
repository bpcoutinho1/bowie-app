import 'dart:convert';

import 'package:bowie/core/dates.dart';

enum DoseKind {
  vaccine('vaccine', 'Vacina'),
  dewormer('dewormer', 'Vermífugo'),
  fleaTick('flea_tick', 'Pulgas e carrapatos');

  const DoseKind(this.code, this.label);

  /// As saved in the database.
  final String code;
  final String label;

  static DoseKind? fromCode(String? code) =>
      values.where((kind) => kind.code == code).firstOrNull;

  /// "Revacinar em", "Próxima dose em", "Trocar em".
  String get dueLabel => switch (this) {
    vaccine => 'Revacinar em',
    dewormer => 'Próxima dose em',
    fleaTick => 'Trocar em',
  };
}

/// Days before the due date the phone reminds (docs/produto/notificacoes.md).
const reminderDayOptions = [7, 14, 30];
const defaultReminderDays = 7;

/// One applied dose of a vaccine, a dewormer or a flea and tick protection,
/// as written on the vaccine card.
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
    this.remindDays = defaultReminderDays,
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

  /// The reminder goes off this many days before [nextDueOn]: 7, 14 or 30.
  final int remindDays;

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
      remindDays: remindDays,
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
      remindDays: remindDays,
      updatedBy: updatedBy,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'pet_id': petId,
      'kind': kind.code,
      'name': name,
      'applied_on': formatDay(appliedOn),
      'next_due_on': formatDay(nextDueOn),
      'product': product,
      'lot': lot,
      'veterinarian': veterinarian,
      'notes': notes,
      'proof_paths': jsonEncode(proofPaths),
      'remind_days': remindDays,
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
      kind: DoseKind.fromCode(row['kind'] as String?) ?? DoseKind.vaccine,
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
      remindDays: switch (row['remind_days']) {
        final num days when reminderDayOptions.contains(days.toInt()) =>
          days.toInt(),
        _ => defaultReminderDays,
      },
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}
