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
import 'package:bowie/features/contacts/data/contacts_repository.dart';
import 'package:bowie/features/contacts/presentation/contacts_providers.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/diary/presentation/diary_page.dart';
import 'package:bowie/features/diary/presentation/diary_providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_photo_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';

import 'support/fakes.dart';

/// A valid 1×1 PNG, so thumbnails can be drawn.
final png = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84,
  120, 156, 99, 248, 255, 255, 63, 0, 5, 254, 2, 254, 13, 239, 70, 184, 0, 0,
  0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);
final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  final today = DateTime(2026, 10, 7);

  late Directory dir;
  late PetLocalStore store;
  late PetPhotoStore photos;
  late PetRepository pets;
  late DiaryRepository diary;
  late String petId;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diary_photos');
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    photos = PetPhotoStore(dir);
    pets = PetRepository(store, photos: photos, now: () => today);
    diary = DiaryRepository(store, photos: photos, now: () => today);
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

  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  EventInput input({
    List<String> kept = const [],
    List<Uint8List> fresh = const [],
  }) => EventInput(
    petId: petId,
    kind: EventKind.symptom,
    title: 'Diarreia',
    occursOn: today,
    keptPhotos: kept,
    newPhotos: fresh,
  );

  test('photos are kept on the phone and go up after the entry', () async {
    final event = await diary.saveEvent(
      input: input(fresh: [png, jpeg]),
      byUser: bruno,
    );
    expect(event.photoPaths, hasLength(2));
    expect(event.photoPaths.first, startsWith('$petId/'));
    expect(event.photoPaths.first, endsWith('.png'));
    expect(event.photoPaths.last, endsWith('.jpg'));
    expect(await photos.read(event.photoPaths.last), jpeg);
    expect((await diary.getEvent(event.id))!.photoPaths, event.photoPaths);

    final remote = FakeRemote();
    final sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: FakeNetwork(),
      photos: photos,
    );
    expect(await sync.sync(), isA<SyncOk>());
    expect(remote.photos.keys, unorderedEquals(event.photoPaths));
    expect(remote.events.single.photoPaths, event.photoPaths);
  });

  test(
    'editing keeps, adds and removes photos; deleting removes all',
    () async {
      final first = await diary.saveEvent(
        input: input(fresh: [png, jpeg]),
        byUser: bruno,
      );
      final [kept, dropped] = first.photoPaths;
      final edited = await diary.saveEvent(
        id: first.id,
        input: input(kept: [kept], fresh: [jpeg]),
        byUser: bruno,
      );
      expect(edited.photoPaths, hasLength(2));
      expect(edited.photoPaths.first, kept);
      expect(await photos.local(dropped), isNull);
      final queued = (await store.pending())
          .where((item) => item.entity == photoEntity)
          .map((item) => (item.entityId, item.payload['op']));
      expect(queued, contains((dropped, 'remove')));

      await diary.deleteEvent(id: first.id, byUser: bruno);
      for (final path in edited.photoPaths) {
        expect(await photos.local(path), isNull);
      }
      expect(await diary.listEvents(petId), isEmpty);
    },
  );

  test('at most four photos, in formats the app knows', () async {
    expect(
      () => diary.saveEvent(
        input: input(fresh: [png, png, png, png, png]),
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => diary.saveEvent(
        input: input(
          fresh: [
            Uint8List.fromList([0, 0, 0, 0x18]),
          ],
        ),
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('a version 7 database gains photos in diary entries', () async {
    final path = '${await getDatabasesPath()}/upgrade_v7_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 7,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
          'updated_at TEXT NOT NULL, deleted_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE pet_events (id TEXT PRIMARY KEY, pet_id TEXT NOT NULL, '
          'kind TEXT NOT NULL, title TEXT NOT NULL, occurs_on TEXT NOT NULL, '
          'occurs_time TEXT, notes TEXT, contact_id TEXT, updated_by TEXT, '
          'updated_at TEXT NOT NULL, deleted_at TEXT)',
        );
        await db.insert('pet_events', {
          'id': 'e1',
          'pet_id': 'p1',
          'kind': 'symptom',
          'title': 'Tosse',
          'occurs_on': '2026-10-01',
          'updated_at': '2026-10-01T00:00:00.000Z',
        });
      },
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    expect((await upgraded.getEvent('e1'))!.photoPaths, isEmpty);
    await upgraded.close();
    await deleteDatabase(path);
  });

  testWidgets('the diary shows the photo small, and big on a tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => diary.saveEvent(
        input: input(fresh: [png, png]),
        byUser: bruno,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          petPhotoStoreProvider.overrideWithValue(photos),
          currentUserProvider.overrideWithValue(bruno),
          petRepositoryProvider.overrideWithValue(pets),
          diaryRepositoryProvider.overrideWithValue(diary),
          contactsRepositoryProvider.overrideWithValue(
            ContactsRepository(store, now: () => today),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const DiaryPage(),
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
    expect(find.text('Diarreia'), findsOneWidget);
    final thumb = find.bySemanticsLabel('Ver a foto 1 de 2');
    expect(thumb, findsOneWidget);
    expect(find.bySemanticsLabel('Ver a foto 2 de 2'), findsOneWidget);

    await tester.tap(thumb);
    await settle();
    expect(find.text('Foto 1 de 2'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
