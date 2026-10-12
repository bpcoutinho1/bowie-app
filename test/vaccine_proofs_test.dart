import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/presentation/status_badge.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_photo_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';

import 'support/fakes.dart';

final png = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
]);
final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  final today = DateTime(2026, 10, 12);

  late Directory dir;
  late PetLocalStore store;
  late PetPhotoStore photos;
  late HealthRepository health;
  late String petId;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vaccine_proofs');
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    photos = PetPhotoStore(dir);
    health = HealthRepository(store, photos: photos, now: () => today);
    petId = (await PetRepository(store, now: () => today).createPet(
      profile: PetProfile(
        name: 'Bowie',
        species: PetSpecies.dog,
        sex: PetSex.male,
        birthDate: DateTime(2021, 5, 4),
      ),
      owner: bruno,
    )).id;
  });

  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  DoseInput input({
    List<String> kept = const [],
    List<Uint8List> fresh = const [],
  }) => DoseInput(
    petId: petId,
    kind: DoseKind.vaccine,
    name: 'V10',
    appliedOn: DateTime(2026, 5, 4),
    nextDueOn: DateTime(2027, 5, 4),
    keptProofs: kept,
    newProofs: fresh,
  );

  test('a dose without proof is still saved, and shows it', () async {
    final dose = await health.saveDose(input: input(), byUser: bruno);
    expect(dose.hasProof, isFalse);
    expect(dose.proofPaths, isEmpty);
  });

  test('proofs stay on the phone and go up after the dose', () async {
    final dose = await health.saveDose(
      input: input(fresh: [png, jpeg]),
      byUser: bruno,
    );
    expect(dose.hasProof, isTrue);
    expect(dose.proofPaths, hasLength(2));
    expect(dose.proofPaths.first, startsWith('$petId/'));
    expect(await photos.read(dose.proofPaths.last), jpeg);
    expect((await store.getDose(dose.id))!.proofPaths, dose.proofPaths);

    final remote = FakeRemote();
    final sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: FakeNetwork(),
      photos: photos,
    );
    expect(await sync.sync(), isA<SyncOk>());
    expect(remote.photos.keys, unorderedEquals(dose.proofPaths));
  });

  test('editing keeps and removes proofs; at most two', () async {
    final first = await health.saveDose(
      input: input(fresh: [png, jpeg]),
      byUser: bruno,
    );
    final [kept, dropped] = first.proofPaths;
    final edited = await health.saveDose(
      id: first.id,
      input: input(kept: [kept]),
      byUser: bruno,
    );
    expect(edited.proofPaths, [kept]);
    expect(await photos.local(dropped), isNull);
    final queued = (await store.pending())
        .where((item) => item.entity == photoEntity)
        .map((item) => (item.entityId, item.payload['op']));
    expect(queued, contains((dropped, 'remove')));

    expect(
      () => health.saveDose(
        id: first.id,
        input: input(kept: [kept], fresh: [png, png]),
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test(
    'a card page shared by two doses stays until the last one goes',
    () async {
      final page = photos.newPath(petId, 'image/png');
      await photos.write(page, png);
      final [a, b] = await health.saveDoses(
        inputs: [
          input(kept: [page]),
          input(kept: [page]),
        ],
        byUser: bruno,
      );
      expect(a.proofPaths, [page]);
      expect(b.proofPaths, [page]);

      await health.deleteDose(id: a.id, byUser: bruno);
      expect(await photos.local(page), isNotNull);
      await health.deleteDose(id: b.id, byUser: bruno);
      expect(await photos.local(page), isNull);
    },
  );

  test("photos of another pet aren't taken as proof", () async {
    final dose = await health.saveDose(
      input: input(kept: ['other-pet/x.png']),
      byUser: bruno,
    );
    expect(dose.hasProof, isFalse);
  });

  test('a version 9 database gains proofs in doses', () async {
    final path = '${await getDatabasesPath()}/upgrade_v9_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 9,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
          'updated_at TEXT NOT NULL, deleted_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE pet_vaccines (id TEXT PRIMARY KEY, '
          'pet_id TEXT NOT NULL, kind TEXT NOT NULL, name TEXT NOT NULL, '
          'applied_on TEXT NOT NULL, next_due_on TEXT NOT NULL, product TEXT, '
          'lot TEXT, veterinarian TEXT, notes TEXT, updated_by TEXT, '
          'updated_at TEXT NOT NULL, deleted_at TEXT)',
        );
        await db.insert('pet_vaccines', {
          'id': 'd1',
          'pet_id': 'p1',
          'kind': 'vaccine',
          'name': 'V10',
          'applied_on': '2026-05-04',
          'next_due_on': '2027-05-04',
          'updated_at': '2026-05-04T00:00:00.000Z',
        });
      },
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    expect((await upgraded.getDose('d1'))!.hasProof, isFalse);
    await upgraded.close();
    await deleteDatabase(path);
  });

  testWidgets('the badge says it in words, not only in color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: Column(
            children: [ProofBadge(hasProof: true), ProofBadge(hasProof: false)],
          ),
        ),
      ),
    );
    expect(find.text('Com comprovante'), findsOneWidget);
    expect(find.text('Sem comprovante'), findsOneWidget);
  });
}
