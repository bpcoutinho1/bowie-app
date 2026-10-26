import 'dart:convert';

import 'package:bowie/core/dates.dart';

/// What kind of diary entry it is (docs/produto/diario.md).
enum EventKind {
  symptom('symptom', 'Sintoma'),
  vetVisit('vet_visit', 'Consulta'),
  exam('exam', 'Exame'),
  weight('weight', 'Peso'),
  other('other', 'Outro');

  const EventKind(this.wire, this.label);

  final String wire;
  final String label;

  static EventKind fromWire(String value) =>
      values.firstWhere((kind) => kind.wire == value, orElse: () => other);
}

/// A document attached to a diary entry, such as an exam result in PDF.
class EventFile {
  const EventFile({required this.path, required this.name});

  /// In the private bucket `pet-photos`, `<pet id>/<file id>.pdf`, kept on
  /// the phone too (PetPhotoStore).
  final String path;

  /// The name the file had when it was chosen: "Hemograma.pdf".
  final String name;

  Map<String, String> toJson() => {'path': path, 'name': name};

  static EventFile? fromJson(Object? json) {
    if (json is! Map) return null;
    final path = json['path'];
    final name = json['name'];
    if (path is! String || path.isEmpty) return null;
    return EventFile(path: path, name: name is String ? name : 'Arquivo.pdf');
  }

  @override
  bool operator ==(Object other) =>
      other is EventFile && other.path == path && other.name == name;

  @override
  int get hashCode => Object.hash(path, name);
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
    this.weightKg,
    this.photoPaths = const [],
    this.files = const [],
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

  /// The weight, in kg, of a [EventKind.weight] entry. Null otherwise.
  final double? weightKg;

  /// Photos in the private bucket `pet-photos`, `<pet id>/<photo id>.jpg`,
  /// kept on the phone too (PetPhotoStore). Up to [maxEventPhotos].
  final List<String> photoPaths;

  /// PDFs, up to [maxEventFiles]. They go in the sheet shared with a vet.
  final List<EventFile> files;
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
      weightKg: weightKg,
      photoPaths: photoPaths,
      files: files,
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
      'weight_kg': weightKg,
      'photo_paths': jsonEncode(photoPaths),
      'files': jsonEncode([for (final file in files) file.toJson()]),
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
    final rawFiles = row['files'];
    final files = rawFiles is String ? jsonDecode(rawFiles) : rawFiles;
    final weight = row['weight_kg'];
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
      // Postgres numeric may arrive as a string.
      weightKg: weight is num
          ? weight.toDouble()
          : weight is String
          ? double.tryParse(weight)
          : null,
      photoPaths: [
        for (final path in (photos as List?) ?? const [])
          if (path is String) path,
      ],
      files: [
        for (final json in (files as List?) ?? const [])
          ?EventFile.fromJson(json),
      ],
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}

/// Photos per diary entry.
const maxEventPhotos = 4;

/// PDFs per diary entry, each up to [maxEventFileBytes].
const maxEventFiles = 5;
const maxEventFileBytes = 10 * 1024 * 1024;

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
  EventKind.weight => const [],
  EventKind.other => const ['Banho e tosa', 'Adestramento', 'Fisioterapia'],
};

/// One weighing, for the chart.
class WeightPoint {
  const WeightPoint(this.day, this.kg);

  final DateTime day;
  final double kg;
}

/// The pet's weighings, the oldest first. Two on the same day: the last saved.
List<WeightPoint> weightHistory(Iterable<PetEvent> events) {
  final byDay = <DateTime, PetEvent>{};
  for (final event in events) {
    final kg = event.weightKg;
    if (event.deletedAt != null || event.kind != EventKind.weight) continue;
    if (kg == null) continue;
    final kept = byDay[event.occursOn];
    if (kept == null || event.updatedAt.isAfter(kept.updatedAt)) {
      byDay[event.occursOn] = event;
    }
  }
  final days = byDay.keys.toList()..sort();
  return [for (final day in days) WeightPoint(day, byDay[day]!.weightKg!)];
}
