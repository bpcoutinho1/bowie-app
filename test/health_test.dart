import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';

import 'support/fakes.dart';

void main() {
  const owner = AppUser(id: 'owner-1', email: 'owner@example.com');
  const stranger = AppUser(id: 'x-1', email: 'x@example.com');
  // The day the reference card photos were taken (docs/produto/carteirinha-de-vacinacao.md).
  final today = DateTime(2026, 10, 2);

  late PetLocalStore store;
  late PetRepository pets;
  late HealthRepository health;
  late String petId;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => today);
    health = HealthRepository(store, now: () => today);
    final pet = await pets.createPet(
      profile: PetProfile(
        name: 'Bowie',
        species: PetSpecies.dog,
        birthDate: DateTime(2021, 5, 4),
      ),
      owner: owner,
    );
    petId = pet.id;
  });

  tearDown(() => store.close());

  Future<VaccineDose> add(
    String name,
    DateTime applied,
    DateTime due, {
    DoseKind kind = DoseKind.vaccine,
    String? lot,
  }) {
    return health.saveDose(
      input: DoseInput(
        petId: petId,
        kind: kind,
        name: name,
        appliedOn: applied,
        nextDueOn: due,
        lot: lot,
      ),
      byUser: owner,
    );
  }

  group('status', () {
    test('thresholds follow the product rules', () {
      expect(statusOf(DateTime(2026, 11, 2), today), VaccineStatus.upToDate);
      expect(statusOf(DateTime(2026, 11, 1), today), VaccineStatus.dueSoon);
      expect(statusOf(today, today), VaccineStatus.dueSoon);
      expect(statusOf(DateTime(2026, 10, 1), today), VaccineStatus.overdue);
    });

    test('texts say how long is left or how late it is', () {
      expect(describeDue(DateTime(2026, 10, 14), today), 'Vence em 12 dias');
      expect(describeDue(today, today), 'Vence hoje');
      expect(describeDue(DateTime(2026, 10, 3), today), 'Vence amanhã');
      expect(describeDue(DateTime(2026, 10, 1), today), 'Venceu ontem');
      expect(describeDue(DateTime(2026, 9, 29), today), 'Venceu há 3 dias');
      expect(describeDue(DateTime(2027, 5, 4), today), 'Em dia até 04/05/2027');
    });

    test('adding months clamps to the end of shorter months', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 10, 6), 12), DateTime(2027, 10, 6));
      expect(addMonths(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });
  });

  test("Bowie's vaccine card gives the statuses in the docs", () async {
    await add('V10', DateTime(2024, 5, 5), DateTime(2025, 5, 5), lot: '004/23');
    await add('V10', DateTime(2025, 5, 8), DateTime(2026, 5, 8), lot: '002/24');
    final latestV10 = await add(
      'V10',
      DateTime(2026, 5, 4),
      DateTime(2027, 5, 4),
      lot: '003/25',
    );
    await add('Giardíase', DateTime(2026, 8, 6), DateTime(2027, 8, 6));
    await add('Tosse dos canis', DateTime(2026, 8, 6), DateTime(2027, 8, 6));
    await add('Raiva', DateTime(2026, 8, 6), DateTime(2027, 8, 6));

    final groups = await health.listGroups(petId);
    expect(groups.map((g) => g.name), [
      'V10',
      'Giardíase',
      'Tosse dos canis',
      'Raiva',
    ]);
    final v10 = groups.first;
    expect(v10.doses, hasLength(3));
    expect(identical(v10.latest, v10.doses.first), isTrue);
    expect(v10.latest.id, latestV10.id);
    expect(v10.statusOn(today), VaccineStatus.upToDate);
    expect(
      v10.doses.skip(1).map((dose) => v10.doseStatus(dose, today)),
      everyElement(VaccineStatus.replaced),
    );
    expect(
      groups.map((g) => g.statusOn(today)),
      everyElement(VaccineStatus.upToDate),
    );
  });

  test('names group ignoring case and accents; overdue comes first', () async {
    await add('raiva', DateTime(2025, 8, 6), DateTime(2026, 8, 6));
    await add('Raíva', DateTime(2025, 9, 1), DateTime(2026, 9, 1));
    await add('V10', DateTime(2026, 5, 4), DateTime(2027, 5, 4));
    await add(
      'Drontal',
      DateTime(2026, 7, 10),
      DateTime(2026, 10, 10),
      kind: DoseKind.dewormer,
    );

    final groups = await health.listGroups(petId);
    expect(groups.map((g) => (g.name, g.statusOn(today))), [
      ('Raíva', VaccineStatus.overdue),
      ('Drontal', VaccineStatus.dueSoon),
      ('V10', VaccineStatus.upToDate),
    ]);
  });

  test('bad dates and empty names are rejected', () async {
    expect(
      () => add('', DateTime(2026, 5, 4), DateTime(2027, 5, 4)),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => add('V10', DateTime(2026, 10, 3), DateTime(2027, 10, 3)),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => add('V10', DateTime(2026, 5, 4), DateTime(2026, 5, 4)),
      throwsA(isA<AppFailure>()),
    );
  });

  test('someone who is not a tutor cannot add doses', () async {
    expect(
      () => health.saveDose(
        input: DoseInput(
          petId: petId,
          kind: DoseKind.vaccine,
          name: 'V10',
          appliedOn: DateTime(2026, 5, 4),
          nextDueOn: DateTime(2027, 5, 4),
        ),
        byUser: stranger,
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test(
    'editing keeps the id; deleting hides the dose and records who',
    () async {
      final dose = await add('V10', DateTime(2026, 5, 4), DateTime(2027, 5, 4));
      await health.saveDose(
        id: dose.id,
        input: DoseInput(
          petId: petId,
          kind: DoseKind.vaccine,
          name: 'V10',
          appliedOn: DateTime(2026, 5, 4),
          nextDueOn: DateTime(2027, 5, 10),
          veterinarian: ' Dra. Ana ',
        ),
        byUser: owner,
      );
      final edited = (await health.getDose(dose.id))!;
      expect(edited.nextDueOn, DateTime(2027, 5, 10));
      expect(edited.veterinarian, 'Dra. Ana');

      await health.deleteDose(id: dose.id, byUser: owner);
      expect(await health.getDose(dose.id), isNull);
      expect(await health.listGroups(petId), isEmpty);

      final row = (await store.pending())
          .firstWhere((item) => item.entity == 'pet_vaccines')
          .payload;
      expect(row['deleted_at'], isNotNull);
      expect(row['updated_by'], owner.id);
      expect(row['applied_on'], '2026-05-04');
    },
  );

  test('doses sync after the pet and come back from the server', () async {
    final remote = FakeRemote();
    final sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: FakeNetwork(),
    );
    final dose = await add('V10', DateTime(2026, 5, 4), DateTime(2027, 5, 4));

    expect(await sync.sync(), isA<SyncOk>());
    expect(remote.calls, ['pets', 'pet_tutors', 'pet_vaccines']);
    expect(remote.doses.single.id, dose.id);

    remote.doses.add(
      VaccineDose(
        id: 'from-wife',
        petId: petId,
        kind: DoseKind.vaccine,
        name: 'Raiva',
        appliedOn: DateTime(2026, 8, 6),
        nextDueOn: DateTime(2027, 8, 6),
        updatedAt: DateTime.utc(2026, 10, 2),
      ),
    );
    expect(await sync.sync(), isA<SyncOk>());
    expect(
      (await health.listGroups(petId)).map((g) => g.name),
      containsAll(['V10', 'Raiva']),
    );
  });

  test('a version 2 database gains the doses table on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v2_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 2,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'updated_at TEXT NOT NULL, deleted_at TEXT, species TEXT, breed TEXT, '
        'birth_date TEXT, birth_date_estimated INTEGER NOT NULL DEFAULT 0, '
        'weight_kg REAL)',
      ),
    );
    await old.close();

    final upgraded = await PetLocalStore.open(databasePath: path);
    expect(await upgraded.listDoses('any'), isEmpty);
    await upgraded.close();
    await deleteDatabase(path);
  });
}
