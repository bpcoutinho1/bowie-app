import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/breeds.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_age.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';

void main() {
  const owner = AppUser(id: 'owner-1', email: 'owner@example.com');
  const sam = AppUser(id: 'sam-1', email: 'sam@example.com');
  final today = DateTime(2026, 10, 6);

  late PetLocalStore store;
  late PetRepository repo;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    repo = PetRepository(store, now: () => today);
  });

  tearDown(() => store.close());

  PetProfile bowie({
    PetSpecies? species = PetSpecies.dog,
    PetSex? sex = PetSex.male,
    DateTime? birthDate,
    double? weight = 23.46,
    String breed = ' Border Collie ',
  }) {
    return PetProfile(
      name: 'Bowie',
      species: species,
      sex: sex,
      breed: breed,
      birthDate: birthDate ?? DateTime(2021, 5, 4),
      weightKg: weight,
    );
  }

  test('the full profile is saved and read back', () async {
    final pet = await repo.createPet(profile: bowie(), owner: owner);
    final saved = (await repo.getDetails(pet.id))!.pet;

    expect(saved.species, PetSpecies.dog);
    expect(saved.sex, PetSex.male);
    expect(saved.breed, 'Border Collie');
    expect(saved.birthDate, DateTime(2021, 5, 4));
    expect(saved.birthDateEstimated, isFalse);
    expect(saved.weightKg, 23.5);
  });

  test('the pushed row carries the profile in server format', () async {
    await repo.createPet(profile: bowie(), owner: owner);
    final row = (await store.pending())
        .firstWhere((item) => item.entity == 'pets')
        .payload;

    expect(row['species'], 'dog');
    expect(row['sex'], 'male');
    expect(row['birth_date'], '2021-05-04');
    expect(row['birth_date_estimated'], false);
    expect(row['weight_kg'], 23.5);
  });

  test('species, sex and birth date are required', () async {
    expect(
      () => repo.createPet(profile: bowie(species: null), owner: owner),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => repo.createPet(profile: bowie(sex: null), owner: owner),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => repo.createPet(
        profile: const PetProfile(
          name: 'Bowie',
          species: PetSpecies.dog,
          sex: PetSex.male,
          birthDate: null,
        ),
        owner: owner,
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('a birth date in the future or an odd weight is rejected', () async {
    expect(
      () => repo.createPet(
        profile: bowie(birthDate: DateTime(2026, 10, 7)),
        owner: owner,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => repo.createPet(profile: bowie(weight: 0), owner: owner),
      throwsA(isA<AppFailure>()),
    );
  });

  test('an empty breed and weight are stored as missing', () async {
    final pet = await repo.createPet(
      profile: bowie(breed: '  ', weight: null),
      owner: owner,
    );
    final saved = (await repo.getDetails(pet.id))!.pet;
    expect(saved.breed, isNull);
    expect(saved.weightKg, isNull);
  });

  test(
    'only the main tutor can delete, and the pet leaves the lists',
    () async {
      final pet = await repo.createPet(profile: bowie(), owner: owner);
      await repo.inviteTutor(petId: pet.id, email: sam.email, byUser: owner);
      final invite = (await repo.listInvites(sam.email)).single;
      await repo.acceptInvite(tutorId: invite.tutor.id, user: sam);

      expect(
        () => repo.deletePet(petId: pet.id, byUser: sam),
        throwsA(isA<AppFailure>()),
      );

      await repo.deletePet(petId: pet.id, byUser: owner);
      expect(await repo.listPetsFor(owner.email), isEmpty);
      expect(await repo.listPetsFor(sam.email), isEmpty);
      expect(await repo.getDetails(pet.id), isNull);

      final row = (await store.pending())
          .firstWhere((item) => item.entity == 'pets')
          .payload;
      expect(row['deleted_at'], isNotNull);
    },
  );

  test('a version 1 database on the phone is upgraded in place', () async {
    final path = '${await getDatabasesPath()}/upgrade_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'updated_at TEXT NOT NULL, deleted_at TEXT)',
      ),
    );
    await old.insert('pets', {
      'id': 'p1',
      'name': 'Teste',
      'updated_at': '2026-10-05T12:00:00.000Z',
    });
    await old.close();

    final upgraded = await PetLocalStore.open(databasePath: path);
    final pet = (await upgraded.getPet('p1'))!;
    expect(pet.name, 'Teste');
    expect(pet.species, isNull);
    expect(pet.birthDateEstimated, isFalse);
    await upgraded.close();
    await deleteDatabase(path);
  });

  group('age', () {
    test('years, months and estimates read naturally', () {
      expect(describeAge(DateTime(2021, 5, 4), today), '5 anos');
      expect(describeAge(DateTime(2025, 10, 6), today), '1 ano');
      expect(describeAge(DateTime(2026, 2, 10), today), '7 meses');
      expect(describeAge(DateTime(2026, 9, 6), today), '1 mês');
      expect(describeAge(DateTime(2026, 9, 20), today), 'Menos de 1 mês');
      expect(
        describeAge(DateTime(2023, 10, 6), today, estimated: true),
        'Cerca de 3 anos',
      );
    });

    test('an approximate age becomes a birth date that many years back', () {
      final birth = estimatedBirthDate(3, today);
      expect(birth, DateTime(2023, 10, 6));
      expect(ageInYears(birth, today), 3);
      expect(
        estimatedBirthDate(1, DateTime(2028, 2, 29)),
        DateTime(2027, 2, 28),
      );
    });
  });

  group('breeds', () {
    test('SRD comes first and search ignores case and accents', () {
      expect(breedsFor(PetSpecies.dog).first, noBreed);
      expect(breedsFor(PetSpecies.cat).first, noBreed);
      expect(searchBreeds(PetSpecies.dog, 'border'), ['Border Collie']);
      expect(searchBreeds(PetSpecies.cat, 'siames'), ['Siamês']);
      expect(searchBreeds(PetSpecies.dog, ''), dogBreeds);
    });
  });

  group('weight', () {
    test('comma or dot, and empty means no weight', () {
      expect(parseWeight('23,5'), 23.5);
      expect(parseWeight('23.5'), 23.5);
      expect(parseWeight(' '), isNull);
      expect(() => parseWeight('abc'), throwsA(isA<AppFailure>()));
      expect(formatWeight(23), '23');
      expect(formatWeight(23.46), '23,5');
    });
  });
}
