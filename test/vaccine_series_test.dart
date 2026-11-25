import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/card_reading.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/dose_history_page.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';

void main() {
  const tutor = AppUser(id: 'tutor-1', email: 'tutor@example.com');
  // The Tequila's card: V10 in 2025, then DHPPi+L in 2026, and an older
  // Nobivac Canine that only the tutor knows is the same vaccine.
  final today = DateTime(2026, 11, 25);

  late PetLocalStore store;
  late HealthRepository health;
  late String petId;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    health = HealthRepository(store, now: () => today);
    final pet = await PetRepository(store, now: () => today).createPet(
      profile: PetProfile(
        name: 'Tequila',
        species: PetSpecies.dog,
        sex: PetSex.female,
        birthDate: DateTime(2020, 3, 1),
      ),
      owner: tutor,
    );
    petId = pet.id;
  });

  tearDown(() => store.close());

  Future<VaccineDose> add(String name, DateTime applied, {String? id}) {
    return health.saveDose(
      id: id,
      input: DoseInput(
        petId: petId,
        kind: DoseKind.vaccine,
        name: name,
        appliedOn: applied,
        nextDueOn: DateTime(applied.year + 1, applied.month, applied.day),
      ),
      byUser: tutor,
    );
  }

  test('V8, V10 and DHPPi+L are one vaccine, each in its own words', () {
    for (final name in [
      'V10',
      'V8',
      'v 10 (déctupla)',
      'DHPPi+L',
      'Polivalente (DHPPi+L)',
      'Nobivac DHPPi',
      'Óctupla',
    ]) {
      expect(vaccineFamily(name), 'polivalente', reason: name);
    }
    expect(vaccineFamily('V5 (quíntupla felina)'), 'polivalente');
    expect(vaccineFamily('Antirrábica'), 'raiva');
    expect(vaccineFamily('Giardíase'), 'giardia');
    expect(vaccineFamily('Nobivac KC'), 'tosse dos canis');
    expect(vaccineFamily('FeLV (leucemia felina)'), 'felv');
    expect(vaccineFamily('Nobivac Canine'), isNull);
    expect(vaccineFamily('Gripe canina'), isNull);
    // Dewormers and flea protections follow only their names.
    expect(
      groupKey(DoseKind.dewormer, 'V10'),
      isNot(groupKey(DoseKind.vaccine, 'V10')),
    );
  });

  test('the newest dose of the family sets the status; older ones are '
      'replaced, not overdue', () async {
    await add('Nobivac Canine', DateTime(2022, 5, 29));
    await add('V10', DateTime(2025, 7, 28));
    await add('DHPPi+L', DateTime(2026, 8, 18));
    final groups = await health.listGroups(petId);
    expect(groups.map((g) => g.name), ['Nobivac Canine', 'DHPPi+L']);
    final polivalente = groups.last;
    expect(polivalente.statusOn(today), VaccineStatus.upToDate);
    expect(polivalente.otherNames, ['V10']);
    expect(
      polivalente.doseStatus(polivalente.doses.last, today),
      VaccineStatus.replaced,
    );
  });

  test('a reading keeps one dose when the card writes it two ways', () async {
    await add('V10', DateTime(2025, 7, 28));
    final reading = CardReading.fromJson({
      'is_vaccine_card': true,
      'doses': [
        {
          'kind': 'vaccine',
          'name': 'DHPPi+L',
          'applied_on': '2026-08-18',
          'next_due_on': '2027-08-18',
        },
        {
          'kind': 'vaccine',
          'name': 'Polivalente (DHPPi+L)',
          'applied_on': '2026-08-18',
          'next_due_on': '2027-08-18',
        },
        {
          'kind': 'vaccine',
          'name': 'Giardíase',
          'applied_on': '2026-08-18',
          'next_due_on': '2027-08-18',
        },
        {
          'kind': 'vaccine',
          'name': 'Déctupla',
          'applied_on': '2025-07-28',
          'next_due_on': '2026-07-28',
        },
      ],
    });
    final review = buildReview(reading, await health.listDoses(petId), today);
    expect(review.map((i) => i.dose.name), [
      'Déctupla',
      'DHPPi+L',
      'Giardíase',
    ]);
    final saved = review.firstWhere((i) => i.dose.name == 'Déctupla');
    expect(saved.alreadySaved, isTrue, reason: 'the V10 of the same day');
    expect(saved.selected, isFalse);
  });

  test('a tutor joins a vaccine to another, and can undo it', () async {
    final nobivac = await add('Nobivac Canine', DateTime(2022, 5, 29));
    await add('V10', DateTime(2025, 7, 28));
    await add('DHPPi+L', DateTime(2026, 8, 18));
    var groups = await health.listGroups(petId);
    await health.joinGroups(
      from: groups.firstWhere((g) => g.name == 'Nobivac Canine'),
      into: groups.firstWhere((g) => g.name == 'DHPPi+L'),
      byUser: tutor,
    );
    groups = await health.listGroups(petId);
    expect(groups, hasLength(1));
    expect(groups.single.name, 'DHPPi+L');
    expect(groups.single.doses, hasLength(3));
    expect(groups.single.hasJoined, isTrue);
    expect((await store.getDose(nobivac.id))!.series, 'polivalente');

    // Editing the dose keeps it joined, and so does a new dose with the
    // same name.
    await add('Nobivac Canine', DateTime(2022, 5, 30), id: nobivac.id);
    await add('Nobivac Canine', DateTime(2021, 5, 29));
    groups = await health.listGroups(petId);
    expect(groups, hasLength(1));
    expect(groups.single.doses, hasLength(4));

    await health.separateGroup(group: groups.single, byUser: tutor);
    groups = await health.listGroups(petId);
    expect(groups.map((g) => g.name), ['Nobivac Canine', 'DHPPi+L']);
  });

  test('only tutors of the pet join its vaccines', () async {
    await add('Nobivac Canine', DateTime(2022, 5, 29));
    await add('V10', DateTime(2025, 7, 28));
    final groups = await health.listGroups(petId);
    await expectLater(
      health.joinGroups(
        from: groups.first,
        into: groups.last,
        byUser: const AppUser(id: 'x', email: 'x@example.com'),
      ),
      throwsA(anything),
    );
  });

  test('the joined vaccine travels with the dose', () {
    final dose = VaccineDose(
      id: 'd1',
      petId: 'p1',
      kind: DoseKind.vaccine,
      name: 'Nobivac Canine',
      appliedOn: DateTime(2022, 5, 29),
      nextDueOn: DateTime(2023, 5, 29),
      series: 'polivalente',
      updatedAt: DateTime.utc(2026, 11, 25),
    );
    final row = dose.toRow();
    expect(row['series'], 'polivalente');
    expect(VaccineDose.fromRow(row).series, 'polivalente');
    expect(VaccineDose.fromRow({...row, 'series': ' '}).series, isNull);
    expect(VaccineDose.fromRow({...row}..remove('series')).series, isNull);
  });

  test('a version 14 database gains the joined vaccine on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v14_series_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 14,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE pet_vaccines (id TEXT PRIMARY KEY, pet_id TEXT NOT NULL, '
          'name TEXT NOT NULL, updated_at TEXT NOT NULL)',
        );
      },
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    await upgraded.close();
    final check = await openDatabase(path);
    final columns = await check.rawQuery('PRAGMA table_info(pet_vaccines)');
    expect(columns.map((c) => c['name']), contains('series'));
    await check.close();
    await deleteDatabase(path);
  });

  testWidgets('the vaccine page joins another record with one tap', (
    tester,
  ) async {
    late VaccineDose nobivac;
    await tester.runAsync(() async {
      nobivac = await add('Nobivac Canine', DateTime(2022, 5, 29));
      await add('DHPPi+L', DateTime(2026, 8, 18));
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          healthRepositoryProvider.overrideWithValue(health),
          currentUserProvider.overrideWithValue(tutor),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: DoseHistoryPage(doseId: nobivac.id),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.text('Venceu há 1276 dias'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Juntar com outra vacina'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Juntar com outra vacina'));
    await tester.pumpAndSettle();
    expect(find.text('Nobivac Canine é a mesma vacina que:'), findsOneWidget);
    await tester.tap(find.text('DHPPi+L'));
    await settle();

    expect(
      find.text('Nobivac Canine e DHPPi+L agora são uma vacina só.'),
      findsOneWidget,
    );
    expect(find.text('Também registrada como Nobivac Canine'), findsOneWidget);
    expect(find.text('Em dia até 18/08/2027'), findsWidgets);
    expect(find.text('Substituída por uma dose mais nova'), findsOneWidget);
    expect(find.text('Desfazer junção'), findsOneWidget);
  });
}
