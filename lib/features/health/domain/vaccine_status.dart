import 'package:bowie/core/dates.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';

export 'package:bowie/core/text.dart' show foldText;

/// From docs/produto/saude.md: more than 30 days left is up to date, 30 or
/// fewer is due soon, past the date is overdue. Older doses of the same
/// vaccine are replaced and never overdue.
enum VaccineStatus { upToDate, dueSoon, overdue, replaced }

const dueSoonDays = 30;

VaccineStatus statusOf(DateTime nextDueOn, DateTime today) {
  final days = daysBetween(today, nextDueOn);
  if (days < 0) return VaccineStatus.overdue;
  if (days <= dueSoonDays) return VaccineStatus.dueSoon;
  return VaccineStatus.upToDate;
}

/// "Vence em 12 dias", "Vence hoje", "Venceu há 3 dias", "Em dia até 04/05/2027".
String describeDue(DateTime nextDueOn, DateTime today) {
  final days = daysBetween(today, nextDueOn);
  if (days < 0) {
    final late = -days;
    return late == 1 ? 'Venceu ontem' : 'Venceu há $late dias';
  }
  if (days == 0) return 'Vence hoje';
  if (days == 1) return 'Vence amanhã';
  if (days <= dueSoonDays) return 'Vence em $days dias';
  return 'Em dia até ${formatDayBr(nextDueOn)}';
}

/// Vaccines that go by many names on the card and replace one another, such
/// as V10 followed by DHPPi+L the next year (docs/produto/saude.md). Each
/// one's patterns are lowercase, without accents, matched anywhere in the
/// name. A name that fits none groups only with the same name.
class VaccineFamily {
  const VaccineFamily(this.key, this.patterns);

  /// What the doses of the family share, as in [VaccineDose.series].
  final String key;
  final List<Pattern> patterns;

  bool matches(String folded) => patterns.any(folded.contains);
}

/// In this order: a name that fits two families (rare) takes the first.
final vaccineFamilies = [
  VaccineFamily('raiva', [
    'raiva',
    'antirrabica',
    'anti-rabica',
    'rabica',
    'rabies',
    'rabisin',
  ]),
  // V8, V10 and the like for dogs; V3, V4 and V5 for cats. A pet is one
  // species, so the two never meet.
  VaccineFamily('polivalente', [
    RegExp(r'\bv ?(3|4|5|8|10|11|12)\b'),
    'polivalente',
    'multipla',
    'triplice',
    'quadrupla',
    'quintupla',
    'octupla',
    'decupla',
    'dectupla',
    RegExp(r'\bd(h|a2?)pp'),
  ]),
  VaccineFamily('tosse dos canis', [
    'tosse',
    'bordetel',
    'traqueobronquite',
    RegExp(r'\bkc\b'),
  ]),
  VaccineFamily('giardia', ['giard']),
  VaccineFamily('leishmaniose', ['leish']),
  VaccineFamily('felv', ['felv', 'leucemia']),
];

/// The family of a vaccine's name, or null.
String? vaccineFamily(String name) {
  final folded = foldText(name.trim());
  for (final family in vaccineFamilies) {
    if (family.matches(folded)) return family.key;
  }
  return null;
}

/// What makes doses the same vaccine: the series a tutor joined them to,
/// else the family of the name (vaccines only), else the name itself,
/// ignoring case and accents.
String groupKey(DoseKind kind, String name, {String? series}) {
  final joined = series?.trim();
  final key = joined != null && joined.isNotEmpty
      ? joined
      : (kind == DoseKind.vaccine ? vaccineFamily(name) : null) ??
            foldText(name.trim());
  return '${kind.name}:$key';
}

String doseGroupKey(VaccineDose dose) =>
    groupKey(dose.kind, dose.name, series: dose.series);

/// The series part of a group key, to save in [VaccineDose.series].
String seriesOf(String groupKey) =>
    groupKey.substring(groupKey.indexOf(':') + 1);

/// Names a tutor joined to another vaccine, by the key the name alone would
/// have, and the series each went to. A new dose with one of these names
/// joins the same vaccine.
Map<String, String> joinedSeries(Iterable<VaccineDose> doses) => {
  for (final dose in doses)
    if (dose.deletedAt == null && dose.series != null)
      groupKey(dose.kind, dose.name): dose.series!,
};

/// The series a new dose called [name] joins, given the pet's [joined]
/// names, or null to follow the name.
String? seriesFor(DoseKind kind, String name, Map<String, String> joined) =>
    joined[groupKey(kind, name)];

/// All doses of the same vaccine (or dewormer) for one pet. The latest one
/// sets the status; the others are history.
class VaccineGroup {
  VaccineGroup(this.key, List<VaccineDose> doses)
    : doses = List.of(doses)
        ..sort((a, b) {
          final applied = b.appliedOn.compareTo(a.appliedOn);
          return applied != 0 ? applied : b.updatedAt.compareTo(a.updatedAt);
        });

  /// From [groupKey].
  final String key;

  /// Newest first.
  final List<VaccineDose> doses;

  /// Some dose was joined to this vaccine by hand.
  bool get hasJoined => doses.any((dose) => dose.series != null);

  /// The other names the doses go by, as on the card: "V10, Nobivac".
  List<String> get otherNames {
    final seen = {foldText(name)};
    return [
      for (final dose in doses)
        if (seen.add(foldText(dose.name))) dose.name,
    ];
  }

  VaccineDose get latest => doses.first;
  String get name => latest.name;
  DoseKind get kind => latest.kind;

  VaccineStatus statusOn(DateTime today) => statusOf(latest.nextDueOn, today);

  VaccineStatus doseStatus(VaccineDose dose, DateTime today) {
    return identical(dose, latest) ? statusOn(today) : VaccineStatus.replaced;
  }
}

/// Groups doses by [doseGroupKey]. Overdue first,
/// then due soon, then up to date; within each, the nearest date first.
List<VaccineGroup> groupDoses(Iterable<VaccineDose> doses, DateTime today) {
  final byKey = <String, List<VaccineDose>>{};
  for (final dose in doses) {
    if (dose.deletedAt != null) continue;
    byKey.putIfAbsent(doseGroupKey(dose), () => []).add(dose);
  }
  final groups = [
    for (final entry in byKey.entries) VaccineGroup(entry.key, entry.value),
  ];
  int rank(VaccineStatus status) => switch (status) {
    VaccineStatus.overdue => 0,
    VaccineStatus.dueSoon => 1,
    VaccineStatus.upToDate => 2,
    VaccineStatus.replaced => 3,
  };
  groups.sort((a, b) {
    final byStatus = rank(a.statusOn(today)).compareTo(rank(b.statusOn(today)));
    if (byStatus != 0) return byStatus;
    return a.latest.nextDueOn.compareTo(b.latest.nextDueOn);
  });
  return groups;
}

/// "V10", "V10 e Nobivac", "V10, V8 e Nobivac".
String joinNames(List<String> names) => names.length <= 1
    ? names.join()
    : '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
