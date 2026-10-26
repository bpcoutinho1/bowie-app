import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/data/weight_sync.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/diary/presentation/diary_providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';
import 'package:bowie/features/pets/presentation/weight_chart.dart';

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  final today = DateTime(2026, 10, 26);

  late PetLocalStore store;
  late PetRepository pets;
  late DiaryRepository diary;
  late String bowieId;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => today);
    diary = DiaryRepository(store, now: () => today);
    bowieId = (await pets.createPet(
      profile: PetProfile(
        name: 'Bowie',
        species: PetSpecies.dog,
        sex: PetSex.male,
        birthDate: DateTime(2021, 5, 4),
      ),
      owner: bruno,
    )).id;
  });

  tearDown(() => store.close());

  Future<PetEvent> weigh(double? kg, DateTime day, {String? id}) {
    return diary.saveEvent(
      id: id,
      input: EventInput(
        petId: bowieId,
        kind: EventKind.weight,
        title: '',
        occursOn: day,
        weightKg: kg,
        notes: 'Na clínica',
      ),
      byUser: bruno,
    );
  }

  test('a weighing keeps the weight and says it in the title', () async {
    final event = await weigh(23.46, DateTime(2026, 10, 20));
    expect(event.kind, EventKind.weight);
    expect(event.weightKg, 23.5);
    expect(event.title, 'Peso: 23,5 kg');
    expect(event.notes, 'Na clínica');
    final saved = await store.getEvent(event.id);
    expect(saved!.weightKg, 23.5);
    expect(saved.kind, EventKind.weight);
  });

  test('a weighing needs a weight, in range, today or before', () async {
    await expectLater(
      weigh(null, today),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'Informe o peso em kg.',
        ),
      ),
    );
    await expectLater(weigh(0, today), throwsA(isA<AppFailure>()));
    await expectLater(weigh(151, today), throwsA(isA<AppFailure>()));
    await expectLater(
      weigh(20, today.add(const Duration(days: 1))),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          'O peso é de hoje ou de um dia que já passou.',
        ),
      ),
    );
  });

  test('the history is the oldest first, one weighing per day', () async {
    await weigh(21, DateTime(2026, 6, 1));
    await weigh(22.5, DateTime(2026, 9, 1));
    await diary.saveEvent(
      input: EventInput(
        petId: bowieId,
        kind: EventKind.symptom,
        title: 'Tosse',
        occursOn: DateTime(2026, 8, 1),
      ),
      byUser: bruno,
    );
    final history = weightHistory(await diary.listEvents(bowieId));
    expect([for (final p in history) p.kg], [21, 22.5]);
    expect(history.first.day, DateTime(2026, 6, 1));
    expect((await diary.latestWeight(bowieId))!.kg, 22.5);
  });

  test('recording a day that has a weighing replaces it', () async {
    await diary.recordWeight(
      petId: bowieId,
      weightKg: 20,
      day: today,
      byUser: bruno,
    );
    await diary.recordWeight(
      petId: bowieId,
      weightKg: 20.4,
      day: today,
      byUser: bruno,
    );
    final weighings = (await diary.listEvents(
      bowieId,
    )).where((e) => e.kind == EventKind.weight).toList();
    expect(weighings, hasLength(1));
    expect(weighings.single.weightKg, 20.4);
  });

  test('"Peso atual" follows the most recent weighing', () async {
    await weigh(24, DateTime(2026, 10, 1));
    await weigh(19, DateTime(2026, 3, 1));
    await applyLatestWeight(
      diary: diary,
      pets: pets,
      petId: bowieId,
      byUser: bruno,
    );
    expect((await store.getPet(bowieId))!.weightKg, 24);
  });

  test('the vertical axis holds every weighing, with room', () {
    final ticks = weightTicks([21, 22.5, 24]);
    expect(ticks.first, lessThanOrEqualTo(21));
    expect(ticks.last, greaterThanOrEqualTo(24));
    expect(ticks.length, greaterThanOrEqualTo(3));
    final flat = weightTicks([8]);
    expect(flat.first, lessThan(8));
    expect(flat.last, greaterThan(8));
  });

  test('a version 12 database gains the weight on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v12_weight_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 12,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE pet_events (id TEXT PRIMARY KEY, pet_id TEXT NOT NULL, '
          'kind TEXT NOT NULL, title TEXT NOT NULL, occurs_on TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        );
      },
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    await upgraded.close();
    final check = await openDatabase(path);
    final columns = await check.rawQuery('PRAGMA table_info(pet_events)');
    expect(columns.map((c) => c['name']), contains('weight_kg'));
    await check.close();
    await deleteDatabase(path);
  });

  testWidgets('the pet page draws the weighings under "Peso atual"', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await weigh(21, DateTime(2026, 6, 1));
      await weigh(23.5, DateTime(2026, 10, 1));
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          petRepositoryProvider.overrideWithValue(pets),
          diaryRepositoryProvider.overrideWithValue(diary),
          currentUserProvider.overrideWithValue(bruno),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: PetPage(petId: bowieId),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.scrollUntilVisible(
      find.text('Evolução do peso'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Evolução do peso'), findsOneWidget);
    expect(find.byType(WeightChart), findsOneWidget);
    expect(find.text('+2,5 kg desde 01/06/2026.'), findsOneWidget);
    expect(find.text('Registrar peso'), findsOneWidget);
  });
}
