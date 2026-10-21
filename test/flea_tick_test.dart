import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/presentation/dose_form_page.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/reminders/domain/reminder_plan.dart';

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  final today = DateTime(2026, 10, 21);

  Future<(PetLocalStore, HealthRepository, String)> open() async {
    final store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    final pet = await PetRepository(store, now: () => today).createPet(
      profile: PetProfile(
        name: 'Bowie',
        species: PetSpecies.dog,
        sex: PetSex.male,
        birthDate: DateTime(2021, 5, 4),
      ),
      owner: bruno,
    );
    return (store, HealthRepository(store, now: () => today), pet.id);
  }

  test(
    'a flea collar is kept with its reminder, here and on the server',
    () async {
      final (store, health, petId) = await open();
      addTearDown(store.close);
      final saved = await health.saveDose(
        input: DoseInput(
          petId: petId,
          kind: DoseKind.fleaTick,
          name: 'Coleira Seresto',
          appliedOn: DateTime(2026, 10, 1),
          nextDueOn: DateTime(2027, 6, 1),
          remindDays: 30,
        ),
        byUser: bruno,
      );
      final row = saved.toRow();
      expect(row['kind'], 'flea_tick');
      expect(row['remind_days'], 30);
      final back = (await store.listDoses(petId)).single;
      expect(back.kind, DoseKind.fleaTick);
      expect(back.remindDays, 30);
      expect(back.kind.dueLabel, 'Trocar em');

      // Rows from before the reminder choice remind 7 days before.
      final old = VaccineDose.fromRow({...row, 'remind_days': null});
      expect(old.remindDays, 7);
    },
  );

  test('only 7, 14 or 30 days are accepted', () async {
    final (store, health, petId) = await open();
    addTearDown(store.close);
    expect(
      () => health.saveDose(
        input: DoseInput(
          petId: petId,
          kind: DoseKind.vaccine,
          name: 'V10',
          appliedOn: today,
          nextDueOn: DateTime(2027, 10, 21),
          remindDays: 10,
        ),
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('each dose reminds as many days before as it asks', () {
    final pet = Pet(
      id: 'p1',
      name: 'Bowie',
      sex: PetSex.male,
      updatedAt: DateTime.utc(2026),
    );
    VaccineDose dose(String name, DoseKind kind, DateTime due, int days) =>
        VaccineDose(
          id: name,
          petId: 'p1',
          kind: kind,
          name: name,
          appliedOn: DateTime(2026, 10, 1),
          nextDueOn: due,
          remindDays: days,
          updatedAt: DateTime.utc(2026),
        );
    final plan = planReminders(
      pets: [pet],
      dosesByPet: {
        'p1': [
          dose('Coleira Seresto', DoseKind.fleaTick, DateTime(2027, 6, 1), 30),
          dose('V10', DoseKind.vaccine, DateTime(2027, 10, 1), 14),
        ],
      },
      now: DateTime(2026, 10, 21, 12),
    );
    expect(plan, [
      Reminder(
        at: DateTime(2027, 5, 2, 9),
        title: 'Antipulgas perto de vencer',
        body:
            'A proteção contra pulgas e carrapatos do Bowie (Coleira Seresto) '
            'vence em 30 dias.',
        route: '/saude',
      ),
      Reminder(
        at: DateTime(2027, 9, 17, 9),
        title: 'Vacina perto de vencer',
        body: 'A vacina V10 do Bowie vence em 14 dias.',
        route: '/saude',
      ),
    ]);
  });

  testWidgets('the form speaks of the product and when to change it', (
    tester,
  ) async {
    final (store, health, petId) = (await tester.runAsync(open))!;
    addTearDown(() => tester.runAsync(store.close));
    tester.view.physicalSize = const Size(1170, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Saúde')),
          routes: [
            GoRoute(
              path: 'nova',
              builder: (context, state) =>
                  DoseFormPage(petId: petId, kind: DoseKind.fleaTick),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          currentUserProvider.overrideWithValue(bruno),
          healthRepositoryProvider.overrideWithValue(health),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/nova');
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    expect(find.text('Pulgas e carrapatos'), findsWidgets);
    expect(find.text('Nome do produto'), findsOneWidget);
    expect(find.text('Trocar em'), findsOneWidget);
    for (final chip in ['+1 ano', '+6 meses', '+3 meses']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('Lembrete no celular'), findsOneWidget);
    expect(find.text('7 dias antes'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Coleira Seresto');
    await tester.tap(find.text('7 dias antes'));
    await settle();
    await tester.tap(find.text('30 dias antes').last);
    await settle();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await settle();

    final saved = (await tester.runAsync(() => store.listDoses(petId)))!;
    expect(saved.single.name, 'Coleira Seresto');
    expect(saved.single.kind, DoseKind.fleaTick);
    expect(saved.single.remindDays, 30);
  });
}
