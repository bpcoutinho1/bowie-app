import 'package:bowie/core/dates.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';

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

/// All doses of the same vaccine (or dewormer) for one pet. The latest one
/// sets the status; the others are history.
class VaccineGroup {
  VaccineGroup(List<VaccineDose> doses)
    : doses = List.of(doses)
        ..sort((a, b) {
          final applied = b.appliedOn.compareTo(a.appliedOn);
          return applied != 0 ? applied : b.updatedAt.compareTo(a.updatedAt);
        });

  /// Newest first.
  final List<VaccineDose> doses;

  VaccineDose get latest => doses.first;
  String get name => latest.name;
  DoseKind get kind => latest.kind;

  VaccineStatus statusOn(DateTime today) => statusOf(latest.nextDueOn, today);

  VaccineStatus doseStatus(VaccineDose dose, DateTime today) {
    return identical(dose, latest) ? statusOn(today) : VaccineStatus.replaced;
  }
}

/// Groups doses by kind and name (ignoring case and accents). Overdue first,
/// then due soon, then up to date; within each, the nearest date first.
List<VaccineGroup> groupDoses(Iterable<VaccineDose> doses, DateTime today) {
  final byKey = <String, List<VaccineDose>>{};
  for (final dose in doses) {
    if (dose.deletedAt != null) continue;
    byKey.putIfAbsent(groupKey(dose.kind, dose.name), () => []).add(dose);
  }
  final groups = [for (final list in byKey.values) VaccineGroup(list)];
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

String groupKey(DoseKind kind, String name) =>
    '${kind.name}:${foldText(name.trim())}';

/// Lowercase without accents, for matching names people type differently.
String foldText(String value) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final out = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    final i = from.indexOf(char);
    out.write(i == -1 ? char : to[i]);
  }
  return out.toString();
}
