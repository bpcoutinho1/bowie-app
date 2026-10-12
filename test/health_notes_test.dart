import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_note_repository.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/health_note.dart';
import 'package:bowie/features/health/presentation/health_page.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';

import 'support/fakes.dart';

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  const stranger = AppUser(id: 'x-1', email: 'x@example.com');
  final today = DateTime(2026, 10, 12);

  late PetLocalStore store;
  late PetRepository pets;
  late HealthNoteRepository notes;
  late String petId;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => today);
    notes = HealthNoteRepository(store, now: () => today);
    petId = (await pets.createPet(
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

  Future<HealthNote> add(
    HealthNoteKind kind,
    String title, [
    String? details,
  ]) => notes.saveNote(
    petId: petId,
    kind: kind,
    title: title,
    details: details,
    byUser: bruno,
  );

  test('special care first, then allergies, then diet', () async {
    await add(HealthNoteKind.diet, 'Ração Golden light', '150 g, 2 vezes');
    await add(HealthNoteKind.allergy, 'Frango');
    await add(
      HealthNoteKind.specialCare,
      '  Problema na coluna ',
      'Evitar arranques, corridas e pulos',
    );
    final list = await notes.listNotes(petId);
    expect(list.map((n) => (n.kind, n.title)), [
      (HealthNoteKind.specialCare, 'Problema na coluna'),
      (HealthNoteKind.allergy, 'Frango'),
      (HealthNoteKind.diet, 'Ração Golden light'),
    ]);
  });

  test('empty titles and strangers are refused; deleting hides', () async {
    expect(() => add(HealthNoteKind.allergy, '  '), throwsA(isA<AppFailure>()));
    expect(
      () => notes.saveNote(
        petId: petId,
        kind: HealthNoteKind.allergy,
        title: 'Frango',
        byUser: stranger,
      ),
      throwsA(isA<AppFailure>()),
    );
    final note = await add(HealthNoteKind.allergy, 'Frango');
    await notes.deleteNote(id: note.id, byUser: bruno);
    expect(await notes.listNotes(petId), isEmpty);
  });

  test('notes sync after the pet and come back', () async {
    final remote = FakeRemote();
    final sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: FakeNetwork(),
    );
    final note = await add(HealthNoteKind.specialCare, 'Problema na coluna');
    expect(await sync.sync(), isA<SyncOk>());
    expect(remote.calls.first, 'pets');
    expect(remote.healthNotes.single.id, note.id);
  });

  test('a version 8 database gains health notes on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v8_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 8,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'updated_at TEXT NOT NULL)',
      ),
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    expect(await upgraded.listHealthNotes('any'), isEmpty);
    await upgraded.close();
    await deleteDatabase(path);
  });

  testWidgets('Saúde shows what matters about the pet at the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => add(
        HealthNoteKind.specialCare,
        'Problema na coluna',
        'Evitar arranques, corridas e pulos',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          currentUserProvider.overrideWithValue(bruno),
          petRepositoryProvider.overrideWithValue(pets),
          healthRepositoryProvider.overrideWithValue(
            HealthRepository(store, now: () => today),
          ),
          healthNoteRepositoryProvider.overrideWithValue(notes),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const HealthPage(),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Importante sobre Bowie'), findsOneWidget);
    expect(find.text('Problema na coluna'), findsOneWidget);
    expect(
      find.text('Cuidado especial · Evitar arranques, corridas e pulos'),
      findsOneWidget,
    );
  });
}
