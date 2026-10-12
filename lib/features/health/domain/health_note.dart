/// What a pet needs everyone who cares for it to know
/// (docs/produto/saude.md#cuidados-alergias-e-alimentação).
enum HealthNoteKind {
  specialCare('special_care', 'Cuidado especial', 'Cuidados especiais'),
  allergy('allergy', 'Alergia', 'Alergias'),
  diet('diet', 'Alimentação', 'Alimentação');

  const HealthNoteKind(this.wire, this.label, this.plural);

  final String wire;
  final String label;

  /// Section title.
  final String plural;

  static HealthNoteKind fromWire(String value) =>
      values.firstWhere((k) => k.wire == value, orElse: () => specialCare);
}

/// A note such as "Problema na coluna: evitar arranques e pulos", "Alergia a
/// frango" or "Ração Golden light, 2 vezes ao dia".
class HealthNote {
  const HealthNote({
    required this.id,
    required this.petId,
    required this.kind,
    required this.title,
    required this.updatedAt,
    this.details,
    this.updatedBy,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final HealthNoteKind kind;
  final String title;
  final String? details;
  final String? updatedBy;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  HealthNote copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? updatedBy,
  }) {
    return HealthNote(
      id: id,
      petId: petId,
      kind: kind,
      title: title,
      details: details,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'pet_id': petId,
      'kind': kind.wire,
      'title': title,
      'details': details,
      'updated_by': updatedBy,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static HealthNote fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    return HealthNote(
      id: row['id']! as String,
      petId: row['pet_id']! as String,
      kind: HealthNoteKind.fromWire(row['kind']! as String),
      title: row['title']! as String,
      details: row['details'] as String?,
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}

/// Examples offered while typing, by kind. Free text is always allowed.
List<String> healthNoteSuggestions(HealthNoteKind kind) => switch (kind) {
  HealthNoteKind.specialCare => const [
    'Problema na coluna',
    'Displasia',
    'Cardiopatia',
    'Epilepsia',
    'Diabetes',
    'Pós-operatório',
    'Medo de fogos e trovões',
    'Não se dá bem com outros cães',
  ],
  HealthNoteKind.allergy => const [
    'Frango',
    'Carne bovina',
    'Trigo',
    'Picada de pulga',
    'Dipirona',
    'Penicilina',
  ],
  HealthNoteKind.diet => const [
    'Ração',
    'Alimentação natural',
    'Petiscos permitidos',
    'Não pode comer',
  ],
};
