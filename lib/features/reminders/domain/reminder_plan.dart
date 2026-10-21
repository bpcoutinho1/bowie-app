import 'package:bowie/core/dates.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_age.dart';

/// Birthday reminders go off this many days before (docs/produto/notificacoes.md).
/// Doses use the days chosen in each one (`VaccineDose.remindDays`).
const reminderDaysBefore = 7;

/// At this hour of the phone's day.
const reminderHour = 9;

/// iOS keeps at most 64 scheduled notifications per app; leave some room.
const maxReminders = 60;

/// A notification scheduled on the phone.
class Reminder {
  const Reminder({
    required this.at,
    required this.title,
    required this.body,
    required this.route,
  });

  /// Local time on the phone.
  final DateTime at;
  final String title;
  final String body;

  /// Where a tap on it leads.
  final String route;

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.route == route;

  @override
  int get hashCode => Object.hash(at, title, body, route);

  @override
  String toString() => 'Reminder($at, $body)';
}

/// The reminders to schedule now, soonest first:
/// - each vaccine, dewormer or flea and tick protection, 7, 14 or 30 days
///   (as chosen in the latest dose) before it expires;
/// - each pet's birthday, 7 days before (not for estimated birth dates).
List<Reminder> planReminders({
  required List<Pet> pets,
  required Map<String, List<VaccineDose>> dosesByPet,
  required DateTime now,
}) {
  final today = dayOf(now);
  DateTime when(DateTime day, [int daysBefore = reminderDaysBefore]) {
    final remind = day.subtract(Duration(days: daysBefore));
    return DateTime(remind.year, remind.month, remind.day, reminderHour);
  }

  final reminders = <Reminder>[];
  for (final pet in pets) {
    if (pet.deletedAt != null) continue;
    final of = ofPet(pet);
    for (final group in groupDoses(dosesByPet[pet.id] ?? const [], today)) {
      final days = group.latest.remindDays;
      final at = when(group.latest.nextDueOn, days);
      if (!at.isAfter(now)) continue;
      reminders.add(
        Reminder(
          at: at,
          title: switch (group.kind) {
            DoseKind.vaccine => 'Vacina perto de vencer',
            DoseKind.dewormer => 'Vermífugo perto de vencer',
            DoseKind.fleaTick => 'Antipulgas perto de vencer',
          },
          body: switch (group.kind) {
            DoseKind.vaccine =>
              'A vacina ${group.name} $of vence em $days dias.',
            DoseKind.dewormer =>
              'O vermífugo ${group.name} $of vence em $days dias.',
            DoseKind.fleaTick =>
              'A proteção contra pulgas e carrapatos $of (${group.name}) '
                  'vence em $days dias.',
          },
          route: '/saude',
        ),
      );
    }

    final birth = pet.birthDate;
    if (birth != null && !pet.birthDateEstimated) {
      var birthday = nextBirthday(birth, today);
      if (!when(birthday).isAfter(now)) {
        birthday = nextBirthday(birth, birthday.add(const Duration(days: 1)));
      }
      reminders.add(
        Reminder(
          at: when(birthday),
          title: 'Aniversário $of',
          // Text chosen by the founder (17 de outubro de 2026).
          body:
              '${pet.name} faz aniversário em $reminderDaysBefore dias! '
              'Faça algo incrível para celebrar este dia!',
          route: '/pets/${pet.id}',
        ),
      );
    }
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  return reminders.take(maxReminders).toList();
}
