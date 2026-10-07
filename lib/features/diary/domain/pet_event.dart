import 'dart:convert';

import 'package:bowie/core/dates.dart';

/// What kind of diary entry it is (docs/produto/diario.md).
enum EventKind {
  symptom('symptom', 'Sintoma'),
  vetVisit('vet_visit', 'Consulta'),
  exam('exam', 'Exame'),
  other('other', 'Outro');

  const EventKind(this.wire, this.label);

  final String wire;
  final String label;

  static EventKind fromWire(String value) =>
      values.firstWhere((kind) => kind.wire == value, orElse: () => other);
}

/// Something that happened to the pet, or is scheduled: a diarrhea, a visit
/// to the vet, an ultrasound next week.
class PetEvent {
  const PetEvent({
    required this.id,
    required this.petId,
    required this.kind,
    required this.title,
    required this.occursOn,
    required this.updatedAt,
    this.time,
    this.notes,
    this.contactId,
    this.photoPaths = const [],
    this.updatedBy,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final EventKind kind;

  /// "Diarreia", "Ultrassonografia".
  final String title;

  /// The calendar day.
  final DateTime occursOn;

  /// "09:30", when the time matters (appointments). Null otherwise.
  final String? time;
  final String? notes;

  /// A contact of the pet's house: the vet, the lab.
  final String? contactId;

  /// Photos in the private bucket `pet-photos`, `<pet id>/<photo id>.jpg`,
  /// kept on the phone too (PetPhotoStore). Up to [maxEventPhotos].
  final List<String> photoPaths;
  final String? updatedBy;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Scheduled for a day after [today].
  bool isScheduled(DateTime today) => dayOf(occursOn).isAfter(dayOf(today));

  PetEvent copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? updatedBy,
  }) {
    return PetEvent(
      id: id,
      petId: petId,
      kind: kind,
      title: title,
      occursOn: occursOn,
      time: time,
      notes: notes,
      contactId: contactId,
      photoPaths: photoPaths,
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
      'occurs_on': formatDay(occursOn),
      'occurs_time': time,
      'notes': notes,
      'contact_id': contactId,
      'photo_paths': jsonEncode(photoPaths),
      'updated_by': updatedBy,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static PetEvent fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    final time = row['occurs_time'] as String?;
    final rawPhotos = row['photo_paths'];
    final photos = rawPhotos is String ? jsonDecode(rawPhotos) : rawPhotos;
    return PetEvent(
      id: row['id']! as String,
      petId: row['pet_id']! as String,
      kind: EventKind.fromWire(row['kind']! as String),
      title: row['title']! as String,
      occursOn: parseDay(row['occurs_on']! as String),
      // Postgres sends "09:30:00".
      time: time == null || time.length < 5 ? null : time.substring(0, 5),
      notes: row['notes'] as String?,
      contactId: row['contact_id'] as String?,
      photoPaths: [
        for (final path in (photos as List?) ?? const [])
          if (path is String) path,
      ],
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}

/// Photos per diary entry.
const maxEventPhotos = 4;

/// Titles offered while typing, by kind. Free text is always allowed.
List<String> eventSuggestions(EventKind kind) => switch (kind) {
  EventKind.symptom => const [
    'Diarreia',
    'Vômito',
    'Tosse',
    'Coceira',
    'Falta de apetite',
    'Apatia',
    'Machucado',
    'Mancando',
  ],
  EventKind.vetVisit => const [
    'Consulta de rotina',
    'Retorno',
    'Emergência',
    'Vacinação',
    'Cirurgia',
  ],
  EventKind.exam => const [
    'Exame de sangue (hemograma)',
    'Ultrassonografia',
    'Exame de fezes',
    'Exame de urina',
    'Raio-X',
    'Ecocardiograma',
  ],
  EventKind.other => const ['Banho e tosa', 'Adestramento', 'Fisioterapia'],
};
