import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_photo_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';
import 'package:bowie/features/pets/presentation/pet_summary.dart';

import 'support/fakes.dart';

final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
final otherJpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 4, 5, 6]);

void main() {
  const owner = AppUser(id: 'owner-1', email: 'owner@example.com');
  const sam = AppUser(id: 'sam-1', email: 'sam@example.com');
  final today = DateTime(2026, 10, 8);

  late Directory dir;
  late PetLocalStore store;
  late PetPhotoStore photos;
  late PetRepository repo;
  late FakeRemote remote;
  late PetSyncService sync;
  late String petId;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pet_photos');
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    photos = PetPhotoStore(dir);
    repo = PetRepository(store, photos: photos, now: () => today);
    remote = FakeRemote();
    sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: FakeNetwork(),
      photos: photos,
    );
    petId = (await repo.createPet(
      profile: PetProfile(
        name: 'Bowie',
        species: PetSpecies.dog,
        sex: PetSex.male,
        breed: 'Border Collie',
        birthDate: DateTime(2021, 5, 4),
      ),
      owner: owner,
    )).id;
  });

  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test('the summary shows species, sex, breed and age', () async {
    final pet = (await repo.getDetails(petId))!.pet;
    expect(petSummary(pet, today), 'Cão · Macho · Border Collie · 5 anos');
  });

  group('photo', () {
    test('is kept on the phone and goes up after the pet', () async {
      final pet = await repo.setPhoto(petId: petId, photo: jpeg, byUser: owner);
      final path = pet.photoPath!;
      expect(path, startsWith('$petId/'));
      expect(path, endsWith('.jpg'));
      expect(await photos.read(path), jpeg);

      expect(await sync.sync(), isA<SyncOk>());
      expect(remote.calls, ['pets', 'pet_tutors', 'upload $path']);
      expect(remote.photos[path], jpeg);
      expect(remote.pets.single.photoPath, path);
    });

    test('replacing or removing deletes the old one everywhere', () async {
      final first = (await repo.setPhoto(
        petId: petId,
        photo: jpeg,
        byUser: owner,
      )).photoPath!;
      await sync.sync();

      final second = (await repo.setPhoto(
        petId: petId,
        photo: otherJpeg,
        byUser: owner,
      )).photoPath!;
      expect(second, isNot(first));
      expect(await photos.local(first), isNull);
      await sync.sync();
      expect(remote.photos.keys, [second]);

      final removed = await repo.setPhoto(
        petId: petId,
        photo: null,
        byUser: owner,
      );
      expect(removed.photoPath, isNull);
      await sync.sync();
      expect(remote.photos, isEmpty);
      expect(remote.pets.single.photoPath, isNull);
    });

    test('a photo replaced before syncing never goes up', () async {
      final first = (await repo.setPhoto(
        petId: petId,
        photo: jpeg,
        byUser: owner,
      )).photoPath!;
      await repo.setPhoto(petId: petId, photo: otherJpeg, byUser: owner);
      await sync.sync();
      expect(remote.calls, isNot(contains('upload $first')));
      expect(remote.photos.values.single, otherJpeg);
    });

    test('deleting the pet removes its photo', () async {
      final path = (await repo.setPhoto(
        petId: petId,
        photo: jpeg,
        byUser: owner,
      )).photoPath!;
      await sync.sync();
      await repo.deletePet(petId: petId, byUser: owner);
      expect(await photos.local(path), isNull);
      await sync.sync();
      expect(remote.photos, isEmpty);
    });

    test('unknown formats and strangers are refused', () async {
      expect(
        () => repo.setPhoto(
          petId: petId,
          photo: Uint8List.fromList([0, 0, 0, 0x18, 0x66, 0x74]),
          byUser: owner,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => repo.setPhoto(petId: petId, photo: jpeg, byUser: sam),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('transfer', () {
    Future<PetTutor> samAccepted() async {
      await repo.inviteTutor(petId: petId, email: sam.email, byUser: owner);
      final invite = (await repo.listInvites(sam.email)).single;
      await repo.acceptInvite(tutorId: invite.tutor.id, user: sam);
      return (await repo.getDetails(
        petId,
      ))!.tutors.firstWhere((tutor) => tutor.email == sam.email);
    }

    test('only an accepted tutor can become the main tutor', () async {
      await repo.inviteTutor(petId: petId, email: sam.email, byUser: owner);
      final pending = (await repo.getDetails(
        petId,
      ))!.tutors.firstWhere((tutor) => tutor.email == sam.email);
      expect(
        () => repo.checkTransfer(
          petId: petId,
          tutorId: pending.id,
          byUser: owner,
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('only the main tutor can transfer', () async {
      final tutor = await samAccepted();
      expect(
        () => repo.checkTransfer(petId: petId, tutorId: tutor.id, byUser: sam),
        throwsA(isA<AppFailure>()),
      );
    });

    test('the roles swap on the server and come back down', () async {
      final tutor = await samAccepted();
      await repo.checkTransfer(petId: petId, tutorId: tutor.id, byUser: owner);
      await sync.transferPet(petId: petId, tutorId: tutor.id);

      expect(remote.calls, contains('transfer'));
      final roles = {
        for (final t in (await repo.getDetails(petId))!.tutors) t.email: t.role,
      };
      expect(roles, {owner.email: PetRole.tutor, sam.email: PetRole.owner});
      // Now Sam manages the pet, and the former main tutor no longer can.
      expect(
        () => repo.deletePet(petId: petId, byUser: owner),
        throwsA(isA<AppFailure>()),
      );
    });

    test('needs the internet', () async {
      final tutor = await samAccepted();
      final offline = PetSyncService(
        store: store,
        remote: remote,
        isSignedIn: () => true,
        network: FakeNetwork(online: false),
        photos: photos,
      );
      expect(
        () => offline.transferPet(petId: petId, tutorId: tutor.id),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  test('a version 3 database gains sex and photo on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v3_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 3,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'updated_at TEXT NOT NULL, deleted_at TEXT, species TEXT, breed TEXT, '
        'birth_date TEXT, birth_date_estimated INTEGER NOT NULL DEFAULT 0, '
        'weight_kg REAL)',
      ),
    );
    await old.insert('pets', {
      'id': 'p1',
      'name': 'Luna',
      'updated_at': '2026-10-01T00:00:00.000Z',
    });
    await old.close();

    final upgraded = await PetLocalStore.open(databasePath: path);
    final pet = (await upgraded.getPet('p1'))!;
    expect(pet.sex, isNull);
    expect(pet.photoPath, isNull);
    await upgraded.close();
    await deleteDatabase(path);
  });

  testWidgets('the main tutor sees sex, photo and the transfer button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late Directory dir;
    late PetLocalStore store;
    late PetRepository repo;
    late String petId;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('pet_page');
      store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
      repo = PetRepository(store, photos: PetPhotoStore(dir), now: () => today);
      petId = (await repo.createPet(
        profile: PetProfile(
          name: 'Bowie',
          species: PetSpecies.dog,
          sex: PetSex.male,
          birthDate: DateTime(2021, 5, 4),
        ),
        owner: owner,
      )).id;
      await repo.inviteTutor(petId: petId, email: sam.email, byUser: owner);
      final invite = (await repo.listInvites(sam.email)).single;
      await repo.acceptInvite(tutorId: invite.tutor.id, user: sam);
    });
    addTearDown(
      () => tester.runAsync(() async {
        await store.close();
        await dir.delete(recursive: true);
      }),
    );

    Future<void> show(AppUser user) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(user.id),
          overrides: [
            petLocalStoreProvider.overrideWithValue(store),
            petPhotoStoreProvider.overrideWithValue(PetPhotoStore(dir)),
            petRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(user),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: PetPage(petId: petId),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    await show(owner);
    expect(find.text('Adicionar foto'), findsWidgets);
    expect(find.text('Macho'), findsOneWidget);
    expect(find.text('Fêmea'), findsOneWidget);
    final transfer = find.text('Transformar em tutor principal');
    await tester.scrollUntilVisible(
      transfer,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(transfer, findsOneWidget);

    // An invited tutor does not see the button.
    await show(sam);
    await tester.scrollUntilVisible(
      find.text('Tutores'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Transformar em tutor principal'), findsNothing);
  });
}
