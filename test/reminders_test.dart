import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/onboarding/presentation/onboarding_pages.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/reminders/data/reminder_service.dart';
import 'package:bowie/features/reminders/domain/reminder_plan.dart';
import 'package:bowie/features/reminders/presentation/reminder_providers.dart';

/// The phone's notifications, in memory.
class FakeGateway implements NotificationGateway {
  FakeGateway({this.enabled = false, this.allow = true});

  bool enabled;
  bool allow;
  var asked = 0;
  List<Reminder> scheduled = const [];
  var cleared = 0;
  final _taps = StreamController<String>.broadcast();

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    asked++;
    enabled = allow;
    return allow;
  }

  @override
  Future<void> replaceAll(List<Reminder> reminders) async =>
      scheduled = reminders;

  @override
  Future<void> cancelAll() async {
    cleared++;
    scheduled = const [];
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchRoute() async => null;
}

Pet pet({
  String id = 'p1',
  String name = 'Bowie',
  PetSex? sex = PetSex.male,
  DateTime? birth,
  bool estimated = false,
}) => Pet(
  id: id,
  name: name,
  sex: sex,
  birthDate: birth,
  birthDateEstimated: estimated,
  updatedAt: DateTime.utc(2026),
);

VaccineDose dose(
  String name,
  DateTime applied,
  DateTime due, {
  DoseKind kind = DoseKind.vaccine,
  String petId = 'p1',
}) => VaccineDose(
  id: '$name-$applied',
  petId: petId,
  kind: kind,
  name: name,
  appliedOn: applied,
  nextDueOn: due,
  updatedAt: DateTime.utc(2026),
);

void main() {
  final now = DateTime(2026, 10, 17, 15);

  group('plan', () {
    test('a vaccine is announced 7 days before it expires, at 9:00', () {
      final plan = planReminders(
        pets: [pet()],
        dosesByPet: {
          'p1': [
            // Older dose of the same vaccine: only the latest counts.
            dose('V10', DateTime(2025, 11, 20), DateTime(2026, 11, 20)),
            dose('V10', DateTime(2026, 11, 1), DateTime(2027, 11, 1)),
            dose(
              'Drontal',
              DateTime(2026, 9, 1),
              DateTime(2026, 12, 1),
              kind: DoseKind.dewormer,
            ),
          ],
        },
        now: now,
      );
      expect(plan, [
        Reminder(
          at: DateTime(2026, 11, 24, 9),
          title: 'Vermífugo perto de vencer',
          body: 'O vermífugo Drontal do Bowie vence em 7 dias.',
          route: '/saude',
        ),
        Reminder(
          at: DateTime(2027, 10, 25, 9),
          title: 'Vacina perto de vencer',
          body: 'A vacina V10 do Bowie vence em 7 dias.',
          route: '/saude',
        ),
      ]);
    });

    test('reminders already past are left out', () {
      final plan = planReminders(
        pets: [pet(sex: PetSex.female, name: 'Mia')],
        dosesByPet: {
          'p1': [
            // 7 days before is today at 9:00, already gone at 15:00.
            dose('Raiva', DateTime(2025, 10, 24), DateTime(2026, 10, 24)),
            dose('V4', DateTime(2025, 10, 25), DateTime(2026, 10, 25)),
          ],
        },
        now: now,
      );
      expect(plan.single.body, 'A vacina V4 da Mia vence em 7 dias.');
      expect(plan.single.at, DateTime(2026, 10, 18, 9));
    });

    test('the birthday comes 7 days before, with the founder\'s text', () {
      final plan = planReminders(
        pets: [pet(birth: DateTime(2021, 12, 4))],
        dosesByPet: const {},
        now: now,
      );
      expect(plan.single.at, DateTime(2026, 11, 27, 9));
      expect(plan.single.title, 'Aniversário do Bowie');
      expect(
        plan.single.body,
        'Bowie faz aniversário em 7 dias! '
        'Faça algo incrível para celebrar este dia!',
      );
      expect(plan.single.route, '/pets/p1');
    });

    test('a birthday too close this year moves to the next one', () {
      final plan = planReminders(
        pets: [pet(birth: DateTime(2021, 10, 20))],
        dosesByPet: const {},
        now: now,
      );
      expect(plan.single.at, DateTime(2027, 10, 13, 9));
    });

    test('estimated birth dates get no birthday reminder', () {
      final plan = planReminders(
        pets: [pet(birth: DateTime(2021, 12, 4), estimated: true)],
        dosesByPet: const {},
        now: now,
      );
      expect(plan, isEmpty);
    });

    test('soonest first, and at most 60', () {
      final pets = [
        for (var i = 0; i < 70; i++)
          pet(id: 'p$i', name: 'Pet $i', birth: DateTime(2020, 1, 1 + i % 28)),
      ];
      final plan = planReminders(pets: pets, dosesByPet: const {}, now: now);
      expect(plan, hasLength(maxReminders));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].at.isBefore(plan[i - 1].at), isFalse);
      }
    });
  });

  group('service', () {
    const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
    late PetLocalStore store;

    setUp(() async {
      store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    });
    tearDown(() => store.close());

    test(
      'schedules from the pets on the phone, and clears on sign out',
      () async {
        final pets = PetRepository(store, now: () => now);
        final created = await pets.createPet(
          profile: PetProfile(
            name: 'Bowie',
            species: PetSpecies.dog,
            sex: PetSex.male,
            birthDate: DateTime(2021, 12, 4),
          ),
          owner: bruno,
        );
        await HealthRepository(store, now: () => now).saveDose(
          input: DoseInput(
            petId: created.id,
            kind: DoseKind.vaccine,
            name: 'V10',
            appliedOn: DateTime(2026, 5, 4),
            nextDueOn: DateTime(2027, 5, 4),
          ),
          byUser: bruno,
        );
        final gateway = FakeGateway();
        final service = ReminderService(store, gateway, now: () => now);
        await service.reschedule(bruno);
        expect(gateway.scheduled.map((r) => r.body), [
          'Bowie faz aniversário em 7 dias! '
              'Faça algo incrível para celebrar este dia!',
          'A vacina V10 do Bowie vence em 7 dias.',
        ]);
        await service.clear();
        expect(gateway.scheduled, isEmpty);
      },
    );
  });

  testWidgets('asks for the reminders and schedules them once allowed', (
    tester,
  ) async {
    final store = await tester.runAsync(
      () => PetLocalStore.open(databasePath: inMemoryDatabasePath),
    );
    addTearDown(() => tester.runAsync(store!.close));
    const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
    final gateway = FakeGateway();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store!),
          currentUserProvider.overrideWithValue(bruno),
          notificationGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(body: NotificationsPrompt(pet: pet())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Um lembrete 7 dias antes de cada vacina do Bowie vencer e do '
        'aniversário.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Ativar avisos'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(gateway.asked, 1);
    expect(find.text('Avisos ativados'), findsOneWidget);
  });

  testWidgets('a refusal explains where to turn them on', (tester) async {
    final gateway = FakeGateway(allow: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          notificationGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: NotificationsPrompt()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ativar avisos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('abra Ajustes'), findsOneWidget);
  });
}
