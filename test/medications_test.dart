import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/data/medication_repository.dart';
import 'package:bowie/features/health/domain/medication.dart';
import 'package:bowie/features/health/presentation/health_page.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/birthday.dart';
import 'package:bowie/features/pets/domain/pet.dart';

import 'support/fakes.dart';

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  const ana = AppUser(id: 'ana-1', email: 'ana@example.com');
  const stranger = AppUser(id: 'x-1', email: 'x@example.com');
  final today = DateTime(2026, 10, 12);

  late PetLocalStore store;
  late PetRepository pets;
  late MedicationRepository meds;
  late String bowieId;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => today);
    meds = MedicationRepository(store, now: () => today);
    bowieId = (await pets.createPet(
      profile: PetProfile(
        name: 'Bowie',
        species: PetSpecies.dog,
        sex: PetSex.male,
        birthDate: DateTime(2021, 5, 4),
      ),
      owner: bruno,
    )).id;
    await pets.inviteTutor(petId: bowieId, email: ana.email, byUser: bruno);
    final invite = (await pets.listInvites(ana.email)).single;
    await pets.acceptInvite(tutorId: invite.tutor.id, user: ana);
  });

  tearDown(() => store.close());

  MedicationInput daily(
    String name,
    double amount,
    DoseUnit unit,
    List<DoseTime> times, {
    String? strength,
  }) => MedicationInput(
    petId: bowieId,
    name: name,
    strength: strength,
    amount: amount,
    unit: unit,
    frequency: MedFrequency.daily,
    times: times,
    startOn: DateTime(2026, 9, 1),
  );

  const morning = DoseTime(DosePeriod.morning, '07:00');
  const night = DoseTime(DosePeriod.night, '19:00');

  /// Bowie's routine, as Bruno described it.
  Future<void> bowiesRoutine() async {
    for (final input in [
      daily('Omega 3', 2, DoseUnit.tablet, [morning]),
      daily('Calmante de camomila', 2, DoseUnit.chew, [morning]),
      daily('Pregabalina', 1, DoseUnit.tablet, [
        night,
        morning,
      ], strength: '75 mg'),
      daily('Colágeno', 1, DoseUnit.tablet, [night]),
    ]) {
      await meds.saveMedication(input: input, byUser: bruno);
    }
  }

  group('schedule', () {
    test("Bowie's day: four doses in the morning, two at night", () async {
      await bowiesRoutine();
      final slots = await meds.dosesOnDay(bowieId, today);
      expect(slots.map((s) => '${s.time!.time} ${s.medication.name}'), [
        '07:00 Calmante de camomila',
        '07:00 Omega 3',
        '07:00 Pregabalina',
        '19:00 Colágeno',
        '19:00 Pregabalina',
      ]);
      final pregabalina = slots
          .firstWhere((s) => s.medication.name == 'Pregabalina')
          .medication;
      expect(pregabalina.doseText, '1 comprimido · 75 mg');
      expect(pregabalina.scheduleText, 'Manhã e noite');
      expect(slots[1].medication.doseText, '2 comprimidos');
      expect(slots[0].medication.doseText, '2 tabletes');
    });

    test('weekly, monthly and every 8 months fall on the right days', () {
      Medication med(MedFrequency frequency, {int interval = 1}) => Medication(
        id: 'm',
        petId: 'p',
        name: 'X',
        amount: 1,
        unit: DoseUnit.collar,
        frequency: frequency,
        interval: interval,
        startOn: DateTime(2026, 1, 31),
        updatedAt: DateTime.utc(2026),
      );
      final weekly = med(MedFrequency.weekly);
      expect(weekly.isDueOn(DateTime(2026, 2, 7)), isTrue);
      expect(weekly.isDueOn(DateTime(2026, 2, 8)), isFalse);

      // The 31st falls on the last day of shorter months.
      final monthly = med(MedFrequency.monthly);
      expect(monthly.isDueOn(DateTime(2026, 2, 28)), isTrue);
      expect(monthly.isDueOn(DateTime(2026, 3, 31)), isTrue);
      expect(monthly.isDueOn(DateTime(2026, 3, 28)), isFalse);

      final collar = med(MedFrequency.everyMonths, interval: 8);
      expect(collar.scheduleText, 'A cada 8 meses');
      expect(collar.nextDueOn(DateTime(2026, 2, 1)), DateTime(2026, 9, 30));
      expect(collar.isDueOn(DateTime(2026, 1, 30)), isFalse);

      final everyThree = med(MedFrequency.everyDays, interval: 3);
      expect(everyThree.isDueOn(DateTime(2026, 2, 3)), isTrue);
      expect(everyThree.isDueOn(DateTime(2026, 2, 4)), isFalse);
    });

    test('a treatment with an end leaves the day after', () async {
      final input = MedicationInput(
        petId: bowieId,
        name: 'Antibiótico',
        amount: 1,
        unit: DoseUnit.tablet,
        frequency: MedFrequency.daily,
        times: const [morning],
        startOn: DateTime(2026, 10, 5),
        endOn: DateTime(2026, 10, 11),
      );
      await meds.saveMedication(input: input, byUser: bruno);
      expect(await meds.dosesOnDay(bowieId, today), isEmpty);
      expect(
        await meds.dosesOnDay(bowieId, DateTime(2026, 10, 11)),
        hasLength(1),
      );
      // Finished treatments go after the ones in use.
      await meds.saveMedication(
        input: daily('Omega 3', 2, DoseUnit.tablet, [morning]),
        byUser: bruno,
      );
      expect((await meds.listMedications(bowieId)).map((m) => m.name), [
        'Omega 3',
        'Antibiótico',
      ]);
    });

    test('bad input and strangers are refused', () async {
      expect(
        () => meds.saveMedication(
          input: daily('Omega 3', 0, DoseUnit.tablet, [morning]),
          byUser: bruno,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => meds.saveMedication(
          input: daily('Omega 3', 1, DoseUnit.tablet, []),
          byUser: bruno,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => meds.saveMedication(
          input: daily('Omega 3', 1, DoseUnit.tablet, [
            const DoseTime(DosePeriod.morning, '25:00'),
          ]),
          byUser: bruno,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => meds.saveMedication(
          input: daily('Omega 3', 1, DoseUnit.tablet, [morning]),
          byUser: stranger,
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('doses given', () {
    test(
      'marking records who gave it; two tutors write the same record',
      () async {
        await bowiesRoutine();
        var slots = await meds.dosesOnDay(bowieId, today);
        final omega = slots.firstWhere((s) => s.medication.name == 'Omega 3');

        await meds.markGiven(slot: omega, day: today, given: true, byUser: ana);
        slots = await meds.dosesOnDay(bowieId, today);
        final marked = slots.firstWhere((s) => s.medication.name == 'Omega 3');
        expect(marked.given?.givenBy, ana.id);
        expect(marked.given?.givenByEmail, ana.email);
        expect(slots.where((s) => s.given != null), hasLength(1));

        // Bruno marks the same dose on his phone: same id, so one record.
        expect(
          meds.doseId(omega.medication.id, today, DosePeriod.morning),
          marked.given!.id,
        );

        await meds.markGiven(
          slot: marked,
          day: today,
          given: false,
          byUser: bruno,
        );
        slots = await meds.dosesOnDay(bowieId, today);
        expect(slots.every((s) => s.given == null), isTrue);
      },
    );

    test('medications sync before the doses that point to them', () async {
      final remote = FakeRemote();
      final sync = PetSyncService(
        store: store,
        remote: remote,
        isSignedIn: () => true,
        network: FakeNetwork(),
      );
      await bowiesRoutine();
      final slot = (await meds.dosesOnDay(bowieId, today)).first;
      await meds.markGiven(slot: slot, day: today, given: true, byUser: bruno);

      expect(await sync.sync(), isA<SyncOk>());
      expect(
        remote.calls.lastIndexOf('pet_medications'),
        lessThan(remote.calls.indexOf('pet_medication_doses')),
      );
      expect(remote.medications, hasLength(4));
      expect(remote.medDoses.single.givenBy, bruno.id);
    });
  });

  group('birthday', () {
    Pet pet(PetSex? sex, DateTime birth, {bool estimated = false}) => Pet(
      id: 'p',
      name: sex == PetSex.female ? 'Mia' : 'Bowie',
      sex: sex,
      birthDate: birth,
      birthDateEstimated: estimated,
      updatedAt: DateTime.utc(2026),
    );

    test('from 30 days before, with do or da by sex', () {
      final bowie = pet(PetSex.male, DateTime(2021, 5, 4));
      expect(birthdayNotice(bowie, DateTime(2026, 4, 3)), isNull);
      expect(
        birthdayNotice(bowie, DateTime(2026, 4, 4)),
        'Faltam 30 dias para o aniversário do Bowie',
      );
      expect(
        birthdayNotice(bowie, DateTime(2026, 4, 27)),
        'Faltam 7 dias para o aniversário do Bowie',
      );
      expect(
        birthdayNotice(bowie, DateTime(2026, 5, 3)),
        'Amanhã é o aniversário do Bowie',
      );
      expect(
        birthdayNotice(bowie, DateTime(2026, 5, 4)),
        'Hoje é o aniversário do Bowie: 5 anos',
      );
      expect(birthdayNotice(bowie, DateTime(2026, 5, 5)), isNull);

      final mia = pet(PetSex.female, DateTime(2020, 11, 11));
      expect(
        birthdayNotice(mia, today),
        'Faltam 30 dias para o aniversário da Mia',
      );
      expect(
        birthdayNotice(pet(null, DateTime(2020, 11, 11)), today),
        'Faltam 30 dias para o aniversário de Bowie',
      );
    });

    test(
      'estimated birth dates get no notice; 29 February moves to the 28th',
      () {
        expect(
          birthdayNotice(
            pet(PetSex.male, DateTime(2021, 10, 20), estimated: true),
            today,
          ),
          isNull,
        );
        expect(
          birthdayNotice(
            pet(PetSex.male, DateTime(2024, 2, 29)),
            DateTime(2027, 2, 28),
          ),
          'Hoje é o aniversário do Bowie: 3 anos',
        );
      },
    );
  });

  testWidgets('Saúde offers both buttons and marks a dose as given', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(bowiesRoutine);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          currentUserProvider.overrideWithValue(bruno),
          petRepositoryProvider.overrideWithValue(pets),
          healthRepositoryProvider.overrideWithValue(
            HealthRepository(store, now: () => today),
          ),
          medicationRepositoryProvider.overrideWithValue(meds),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const HealthPage(),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    expect(find.text('Registrar medicação'), findsOneWidget);
    expect(find.text('Registrar vacina'), findsOneWidget);
    expect(find.text('Remédios de hoje'), findsOneWidget);
    expect(find.text('0 de 5 doses dadas'), findsOneWidget);

    await tester.tap(find.byTooltip('Marcar Omega 3 como dado'));
    await settle();
    expect(find.text('1 de 5 doses dadas'), findsOneWidget);
    expect(find.textContaining('Dada por você às'), findsOneWidget);
    expect(find.byTooltip('Desfazer: Omega 3 não foi dado'), findsOneWidget);
  });

  test('a version 6 database gains medications on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v6_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 6,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        );
        // Version 6 already had the diary.
        await db.execute('CREATE TABLE pet_events (id TEXT PRIMARY KEY)');
      },
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    expect(await upgraded.listMedications('any'), isEmpty);
    expect(await upgraded.listMedDoses('any', DateTime(2026)), isEmpty);
    await upgraded.close();
    await deleteDatabase(path);
  });
}
