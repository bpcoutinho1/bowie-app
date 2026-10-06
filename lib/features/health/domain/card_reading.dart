import 'package:bowie/core/dates.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';

/// Fields of a read dose that may need a second look.
enum ReadField { kind, name, appliedOn, nextDueOn, product, lot, veterinarian }

const _wireFields = {
  'kind': ReadField.kind,
  'name': ReadField.name,
  'applied_on': ReadField.appliedOn,
  'next_due_on': ReadField.nextDueOn,
  'product': ReadField.product,
  'lot': ReadField.lot,
  'veterinarian': ReadField.veterinarian,
};

/// One dose as read from a photo. Anything may be missing; a person reviews it
/// before it becomes a [VaccineDose].
class ReadDose {
  const ReadDose({
    required this.kind,
    required this.name,
    this.appliedOn,
    this.nextDueOn,
    this.product,
    this.lot,
    this.veterinarian,
    this.uncertain = const {},
  });

  factory ReadDose.fromJson(Map<String, dynamic> json) {
    return ReadDose(
      kind: json['kind'] == 'dewormer' ? DoseKind.dewormer : DoseKind.vaccine,
      name: _text(json['name']) ?? '',
      appliedOn: _day(json['applied_on']),
      nextDueOn: _day(json['next_due_on']),
      product: _text(json['product']),
      lot: _text(json['lot']),
      veterinarian: _text(json['veterinarian']),
      uncertain: {
        for (final field in (json['uncertain_fields'] as List?) ?? const [])
          ?_wireFields[field],
      },
    );
  }

  final DoseKind kind;
  final String name;
  final DateTime? appliedOn;
  final DateTime? nextDueOn;
  final String? product;
  final String? lot;
  final String? veterinarian;
  final Set<ReadField> uncertain;

  /// What still stops this dose from being saved, or null when it can be.
  String? problemOn(DateTime today) {
    final applied = appliedOn;
    final due = nextDueOn;
    if (name.trim().isEmpty) return 'Falta o nome';
    if (applied == null) return 'Falta a data da aplicação';
    if (due == null) return 'Falta a data da próxima dose';
    if (dayOf(applied).isAfter(today)) return 'Aplicação no futuro';
    if (!due.isAfter(applied)) return 'Próxima dose antes da aplicação';
    return null;
  }

  ReadDose copyWith({
    DoseKind? kind,
    String? name,
    DateTime? appliedOn,
    DateTime? nextDueOn,
    String? product,
    String? lot,
    String? veterinarian,
    Set<ReadField>? uncertain,
  }) {
    return ReadDose(
      kind: kind ?? this.kind,
      name: name ?? this.name,
      appliedOn: appliedOn ?? this.appliedOn,
      nextDueOn: nextDueOn ?? this.nextDueOn,
      product: product ?? this.product,
      lot: lot ?? this.lot,
      veterinarian: veterinarian ?? this.veterinarian,
      uncertain: uncertain ?? this.uncertain,
    );
  }
}

class ReadWeight {
  const ReadWeight({required this.weightKg, this.measuredOn});

  final double weightKg;
  final DateTime? measuredOn;
}

/// What the cloud reading returned for a set of photos.
class CardReading {
  const CardReading({
    required this.isVaccineCard,
    required this.doses,
    required this.weights,
    this.issues,
  });

  factory CardReading.fromJson(Map<String, dynamic> json) {
    return CardReading(
      isVaccineCard: json['is_vaccine_card'] == true,
      doses: [
        for (final item in (json['doses'] as List?) ?? const [])
          if (item is Map) ReadDose.fromJson(Map<String, dynamic>.from(item)),
      ],
      weights: [
        for (final item in (json['weights'] as List?) ?? const [])
          if (item is Map && item['weight_kg'] is num)
            ReadWeight(
              weightKg: (item['weight_kg'] as num).toDouble(),
              measuredOn: _day(item['measured_on']),
            ),
      ],
      issues: _text(json['issues']),
    );
  }

  final bool isVaccineCard;
  final List<ReadDose> doses;
  final List<ReadWeight> weights;

  /// A short note about the photo, such as a cropped page.
  final String? issues;

  /// The most recent weight with a date, or the last one read.
  ReadWeight? get latestWeight {
    if (weights.isEmpty) return null;
    final dated = weights.where((w) => w.measuredOn != null).toList()
      ..sort((a, b) => b.measuredOn!.compareTo(a.measuredOn!));
    return dated.firstOrNull ?? weights.last;
  }
}

/// A read dose on the review screen.
class ReviewItem {
  ReviewItem({
    required this.dose,
    required this.alreadySaved,
    required this.selected,
  });

  ReadDose dose;

  /// The pet already has a dose with this name and application date.
  final bool alreadySaved;
  bool selected;
}

/// Turns a reading into review items: repeated doses (the same page in two
/// photos) appear once, doses the pet already has start unselected, and doses
/// with missing data start unselected until someone completes them.
List<ReviewItem> buildReview(
  CardReading reading,
  Iterable<VaccineDose> existing,
  DateTime today,
) {
  String key(DoseKind kind, String name, DateTime? applied) =>
      '${groupKey(kind, name)}@${applied == null ? '' : formatDay(applied)}';

  final saved = {
    for (final dose in existing)
      if (dose.deletedAt == null) key(dose.kind, dose.name, dose.appliedOn),
  };
  final seen = <String>{};
  final items = <ReviewItem>[];
  for (final dose in reading.doses) {
    final k = key(dose.kind, dose.name, dose.appliedOn);
    if (dose.appliedOn != null && !seen.add(k)) continue;
    final alreadySaved = dose.appliedOn != null && saved.contains(k);
    items.add(
      ReviewItem(
        dose: dose,
        alreadySaved: alreadySaved,
        selected: !alreadySaved && dose.problemOn(today) == null,
      ),
    );
  }
  // Same order as the card: by name, oldest dose first.
  items.sort((a, b) {
    final byName = foldText(a.dose.name).compareTo(foldText(b.dose.name));
    if (byName != 0) return byName;
    final x = a.dose.appliedOn, y = b.dose.appliedOn;
    if (x == null || y == null) return x == y ? 0 : (x == null ? 1 : -1);
    return x.compareTo(y);
  });
  return items;
}

String? _text(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.isEmpty ? null : text;
}

DateTime? _day(Object? value) {
  if (value is! String || value.length < 10) return null;
  try {
    return parseDay(value);
  } on FormatException {
    return null;
  }
}
