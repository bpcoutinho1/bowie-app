import 'dart:convert';

import 'package:bowie/core/dates.dart';

/// How often a medication is given (docs/produto/saude.md#medicamentos).
enum MedFrequency {
  daily('daily', 'Todo dia'),
  weekly('weekly', 'Toda semana'),
  monthly('monthly', 'Todo mês'),
  everyDays('every_days', 'A cada X dias'),
  everyMonths('every_months', 'A cada X meses');

  const MedFrequency(this.wire, this.label);

  final String wire;
  final String label;

  static MedFrequency fromWire(String value) =>
      values.firstWhere((f) => f.wire == value, orElse: () => daily);
}

/// The periods of a daily medication, each with its own time.
enum DosePeriod {
  morning('morning', 'Manhã', '07:00'),
  afternoon('afternoon', 'Tarde', '13:00'),
  night('night', 'Noite', '19:00');

  const DosePeriod(this.wire, this.label, this.defaultTime);

  final String wire;
  final String label;
  final String defaultTime;

  static DosePeriod? fromWire(String? value) =>
      values.where((p) => p.wire == value).firstOrNull;
}

/// What one dose is counted in. Labels are singular and plural.
enum DoseUnit {
  tablet('tablet', 'comprimido', 'comprimidos'),
  chew('chew', 'tablete', 'tabletes'),
  capsule('capsule', 'cápsula', 'cápsulas'),
  drop('drop', 'gota', 'gotas'),
  ml('ml', 'ml', 'ml'),
  sachet('sachet', 'sachê', 'sachês'),
  pipette('pipette', 'pipeta', 'pipetas'),
  application('application', 'aplicação', 'aplicações'),
  collar('collar', 'coleira', 'coleiras'),
  unit('unit', 'unidade', 'unidades');

  const DoseUnit(this.wire, this.singular, this.plural);

  final String wire;
  final String singular;
  final String plural;

  static DoseUnit fromWire(String value) =>
      values.firstWhere((u) => u.wire == value, orElse: () => unit);
}

/// A time of day for a daily medication: "manhã às 07:00".
class DoseTime {
  const DoseTime(this.period, this.time);

  final DosePeriod period;

  /// "07:00".
  final String time;

  Map<String, String> toJson() => {'period': period.wire, 'time': time};
}

/// A medication the pet takes: Omega 3 every morning, a flea collar every 8
/// months.
class Medication {
  const Medication({
    required this.id,
    required this.petId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.frequency,
    required this.startOn,
    required this.updatedAt,
    this.strength,
    this.interval = 1,
    this.times = const [],
    this.endOn,
    this.notes,
    this.updatedBy,
    this.deletedAt,
  });

  final String id;
  final String petId;
  final String name;

  /// "75 mg". Optional.
  final String? strength;

  /// How many units per dose: 2, 0.5.
  final double amount;
  final DoseUnit unit;
  final MedFrequency frequency;

  /// X in "a cada X dias" or "a cada X meses". 1 otherwise.
  final int interval;

  /// The periods of a daily medication, by time. Empty for the others.
  final List<DoseTime> times;
  final DateTime startOn;

  /// Null when the medication is for good ("uso contínuo").
  final DateTime? endOn;
  final String? notes;
  final String? updatedBy;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get continuous => endOn == null;

  /// "2 comprimidos · 75 mg".
  String get doseText {
    final number = amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toString().replaceAll('.', ',');
    final unitText = amount <= 1 ? unit.singular : unit.plural;
    return ['$number $unitText', ?strength].join(' · ');
  }

  /// "Manhã e noite", "Toda semana", "A cada 8 meses".
  String get scheduleText => switch (frequency) {
    MedFrequency.daily => _joinPt([for (final t in times) t.period.label]),
    MedFrequency.everyDays => 'A cada $interval dias',
    MedFrequency.everyMonths => 'A cada $interval meses',
    _ => frequency.label,
  };

  bool isActiveOn(DateTime day) {
    final d = dayOf(day);
    if (d.isBefore(dayOf(startOn))) return false;
    final end = endOn;
    return end == null || !d.isAfter(dayOf(end));
  }

  /// Whether a dose is due on [day].
  bool isDueOn(DateTime day) {
    if (!isActiveOn(day)) return false;
    final start = dayOf(startOn);
    final d = dayOf(day);
    switch (frequency) {
      case MedFrequency.daily:
        return true;
      case MedFrequency.weekly:
        return daysBetween(start, d) % 7 == 0;
      case MedFrequency.everyDays:
        return daysBetween(start, d) % interval == 0;
      case MedFrequency.monthly:
      case MedFrequency.everyMonths:
        final step = frequency == MedFrequency.monthly ? 1 : interval;
        final months = (d.year - start.year) * 12 + d.month - start.month;
        return months % step == 0 && addMonths(start, months) == d;
    }
  }

  /// The next day a dose is due, from [today] on. Null after the end.
  DateTime? nextDueOn(DateTime today) {
    var day = dayOf(today);
    if (day.isBefore(dayOf(startOn))) day = dayOf(startOn);
    // A flea collar every 8 months is the longest gap expected; look a bit
    // further to be safe.
    for (var i = 0; i < 800; i++) {
      final candidate = day.add(Duration(days: i));
      final end = endOn;
      if (end != null && candidate.isAfter(dayOf(end))) return null;
      if (isDueOn(candidate)) return candidate;
    }
    return null;
  }

  Medication copyWith({
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? updatedBy,
  }) {
    return Medication(
      id: id,
      petId: petId,
      name: name,
      strength: strength,
      amount: amount,
      unit: unit,
      frequency: frequency,
      interval: interval,
      times: times,
      startOn: startOn,
      endOn: endOn,
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
      'name': name,
      'strength': strength,
      'amount': amount,
      'unit': unit.wire,
      'frequency': frequency.wire,
      'interval_count': interval,
      'times': jsonEncode([for (final t in times) t.toJson()]),
      'start_on': formatDay(startOn),
      'end_on': endOn == null ? null : formatDay(endOn!),
      'notes': notes,
      'updated_by': updatedBy,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static Medication fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    final end = row['end_on'] as String?;
    final rawTimes = row['times'];
    final decoded = rawTimes is String ? jsonDecode(rawTimes) : rawTimes;
    final times = <DoseTime>[
      for (final item in (decoded as List?) ?? const [])
        if (item is Map &&
            DosePeriod.fromWire(item['period'] as String?) != null)
          DoseTime(
            DosePeriod.fromWire(item['period'] as String?)!,
            item['time'] as String? ?? '',
          ),
    ]..sort((a, b) => a.time.compareTo(b.time));
    return Medication(
      id: row['id']! as String,
      petId: row['pet_id']! as String,
      name: row['name']! as String,
      strength: row['strength'] as String?,
      amount: (row['amount']! as num).toDouble(),
      unit: DoseUnit.fromWire(row['unit']! as String),
      frequency: MedFrequency.fromWire(row['frequency']! as String),
      interval: (row['interval_count'] as num?)?.toInt() ?? 1,
      times: times,
      startOn: parseDay(row['start_on']! as String),
      endOn: end == null ? null : parseDay(end),
      notes: row['notes'] as String?,
      updatedBy: row['updated_by'] as String?,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}

/// A dose marked as given: who gave it and when.
class MedDose {
  const MedDose({
    required this.id,
    required this.medicationId,
    required this.petId,
    required this.dueOn,
    required this.givenBy,
    required this.givenByEmail,
    required this.givenAt,
    required this.updatedAt,
    this.period,
    this.deletedAt,
  });

  /// The same for every tutor marking the same dose, so two marks of one
  /// dose become one record (see doseId).
  final String id;
  final String medicationId;
  final String petId;
  final DateTime dueOn;

  /// Null for medications that are not daily.
  final DosePeriod? period;
  final String givenBy;
  final String givenByEmail;
  final DateTime givenAt;
  final DateTime updatedAt;

  /// Set when the mark is undone.
  final DateTime? deletedAt;

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'medication_id': medicationId,
      'pet_id': petId,
      'due_on': formatDay(dueOn),
      'period': period?.wire,
      'given_by': givenBy,
      'given_by_email': givenByEmail,
      'given_at': givenAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  static MedDose fromRow(Map<String, Object?> row) {
    final deleted = row['deleted_at'] as String?;
    return MedDose(
      id: row['id']! as String,
      medicationId: row['medication_id']! as String,
      petId: row['pet_id']! as String,
      dueOn: parseDay(row['due_on']! as String),
      period: DosePeriod.fromWire(row['period'] as String?),
      givenBy: row['given_by']! as String,
      givenByEmail: row['given_by_email']! as String,
      givenAt: DateTime.parse(row['given_at']! as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
      deletedAt: deleted == null ? null : DateTime.parse(deleted).toUtc(),
    );
  }
}

/// One dose to give on a day: a medication at a period (or the day of a
/// non-daily one), and the mark if someone gave it.
class DoseSlot {
  const DoseSlot({required this.medication, this.time, this.given});

  final Medication medication;

  /// Null for medications that are not daily.
  final DoseTime? time;
  final MedDose? given;
}

/// What to give on [day], by time; non-daily medications first.
List<DoseSlot> dosesOn(
  DateTime day,
  Iterable<Medication> medications,
  Iterable<MedDose> doses,
) {
  final d = dayOf(day);
  final marks = {
    for (final dose in doses)
      if (dose.deletedAt == null && dose.dueOn == d)
        '${dose.medicationId}|${dose.period?.wire ?? ''}': dose,
  };
  final slots = <DoseSlot>[];
  for (final med in medications) {
    if (med.deletedAt != null || !med.isDueOn(d)) continue;
    if (med.frequency == MedFrequency.daily) {
      for (final time in med.times) {
        slots.add(
          DoseSlot(
            medication: med,
            time: time,
            given: marks['${med.id}|${time.period.wire}'],
          ),
        );
      }
    } else {
      slots.add(DoseSlot(medication: med, given: marks['${med.id}|']));
    }
  }
  slots.sort((a, b) {
    final x = a.time?.time ?? '', y = b.time?.time ?? '';
    final byTime = x.compareTo(y);
    return byTime != 0
        ? byTime
        : a.medication.name.compareTo(b.medication.name);
  });
  return slots;
}

String _joinPt(List<String> items) {
  if (items.isEmpty) return '';
  final lower = [for (final item in items) item.toLowerCase()];
  final text = lower.length == 1
      ? lower.single
      : '${lower.sublist(0, lower.length - 1).join(', ')} e ${lower.last}';
  return text[0].toUpperCase() + text.substring(1);
}
