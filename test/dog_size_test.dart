import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/presentation/diary_providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/dog_size.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';

void main() {
  final today = DateTime(2026, 10, 29);
  final adult = DateTime(2021, 5, 4);

  test('the weight gives the size, with no gaps between the ranges', () {
    final cases = {
      2.0: DogSize.mini,
      5.0: DogSize.mini,
      5.1: DogSize.small,
      10.0: DogSize.small,
      10.5: DogSize.medium,
      22.0: DogSize.medium,
      25.0: DogSize.medium,
      25.4: DogSize.large,
      45.0: DogSize.large,
      45.1: DogSize.giant,
      70.0: DogSize.giant,
    };
    for (final MapEntry(key: kg, value: size) in cases.entries) {
      expect(dogSizeForWeight(kg), size, reason: '$kg kg');
    }
  });

  test('a puppy waits, a chosen size wins, cats have none', () {
    ({DogSize? size, SizeSource source})? of({
      PetSpecies species = PetSpecies.dog,
      DogSize? chosen,
      double? kg = 22,
      DateTime? born,
    }) => petSize(
      species: species,
      chosen: chosen,
      weightKg: kg,
      birthDate: born ?? adult,
      today: today,
    );

    expect(of()!.size, DogSize.medium);
    expect(of()!.source, SizeSource.weight);
    final puppy = of(kg: 8, born: DateTime(2026, 3, 1))!;
    expect(puppy.size, isNull);
    expect(puppy.source, SizeSource.puppy);
    final chosen = of(chosen: DogSize.large, born: DateTime(2026, 3, 1))!;
    expect(chosen.size, DogSize.large);
    expect(chosen.source, SizeSource.chosen);
    expect(of(kg: null)!.source, SizeSource.unknown);
    expect(of(species: PetSpecies.cat), isNull);
  });

  test('the chosen size goes to the server and back', () {
    final pet = Pet(
      id: 'p1',
      name: 'Bowie',
      species: PetSpecies.dog,
      size: DogSize.large,
      updatedAt: DateTime.utc(2026, 10, 29),
    );
    expect(pet.toRow()['size'], 'large');
    expect(Pet.fromRow(pet.toRow()).size, DogSize.large);
    expect(Pet.fromRow({...pet.toRow(), 'size': null}).size, isNull);
  });

  test('a version 13 database gains the size on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v13_size_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 13,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'updated_at TEXT NOT NULL)',
      ),
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    await upgraded.close();
    final check = await openDatabase(path);
    final columns = await check.rawQuery('PRAGMA table_info(pets)');
    expect(columns.map((c) => c['name']), contains('size'));
    await check.close();
    await deleteDatabase(path);
  });

  group('on the pet page', () {
    const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
    late PetLocalStore store;
    late PetRepository pets;

    Future<String> pump(WidgetTester tester, PetSpecies species) async {
      store = (await tester.runAsync(
        () => PetLocalStore.open(databasePath: inMemoryDatabasePath),
      ))!;
      addTearDown(() => tester.runAsync(store.close));
      pets = PetRepository(store, now: () => today);
      final pet = await tester.runAsync(
        () => pets.createPet(
          profile: PetProfile(
            name: 'Bowie',
            species: species,
            sex: PetSex.male,
            birthDate: adult,
            weightKg: 22,
          ),
          owner: bruno,
        ),
      );
      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petLocalStoreProvider.overrideWithValue(store),
            petRepositoryProvider.overrideWithValue(pets),
            currentUserProvider.overrideWithValue(bruno),
            diaryRepositoryProvider.overrideWithValue(
              DiaryRepository(store, now: () => today),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: PetPage(petId: pet!.id),
          ),
        ),
      );
      await settle(tester);
      return pet.id;
    }

    testWidgets('a dog shows the size by the weight, and it can be chosen', (
      tester,
    ) async {
      final id = await pump(tester, PetSpecies.dog);
      expect(find.text('Porte'), findsOneWidget);
      expect(find.text('Médio, pelo peso'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Peso atual (kg)'),
        '30',
      );
      await tester.pump();
      expect(find.text('Grande, pelo peso'), findsOneWidget);

      await tester.tap(find.text('Grande, pelo peso'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gigante'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await settle(tester);
      final saved = await tester.runAsync(() => store.getPet(id));
      expect(saved!.size, DogSize.giant);
      expect(saved.weightKg, 30);
    });

    testWidgets('a cat has no size', (tester) async {
      await pump(tester, PetSpecies.cat);
      expect(find.text('Porte'), findsNothing);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
