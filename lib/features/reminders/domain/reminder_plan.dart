import 'package:bowie/core/dates.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_age.dart';

/// Reminders go off this many days before the date (docs/produto/notificacoes.md).
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
/// - each vaccine or dewormer, 7 days before its latest dose expires;
/// - each pet's birthday, 7 days before (not for estimated birth dates).
List<Reminder> planReminders({
  required List<Pet> pets,
  required Map<String, List<VaccineDose>> dosesByPet,
  required DateTime now,
}) {
  final today = dayOf(now);
  DateTime when(DateTime day) {
    final remind = day.subtract(const Duration(days: reminderDaysBefore));
    return DateTime(remind.year, remind.month, remind.day, reminderHour);
  }

  final reminders = <Reminder>[];
  for (final pet in pets) {
    if (pet.deletedAt != null) continue;
    final of = ofPet(pet);
    for (final group in groupDoses(dosesByPet[pet.id] ?? const [], today)) {
      final at = when(group.latest.nextDueOn);
      if (!at.isAfter(now)) continue;
      final vaccine = group.kind == DoseKind.vaccine;
      reminders.add(
        Reminder(
          at: at,
          title: vaccine
              ? 'Vacina perto de vencer'
              : 'Vermífugo perto de vencer',
          body: vaccine
              ? 'A vacina ${group.name} $of vence em $reminderDaysBefore dias.'
              : 'O vermífugo ${group.name} $of vence em $reminderDaysBefore '
                    'dias.',
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
