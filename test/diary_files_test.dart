import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/documents.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/photo_picker.dart';
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

final pdf = Uint8List.fromList([...ascii.encode('%PDF-1.7\n'), 1, 2, 3]);

class FakeOpener implements DocumentOpener {
  final opened = <String>[];

  @override
  Future<bool> open(File file, {required String name}) async {
    opened.add(name);
    return true;
  }
}

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  final today = DateTime(2026, 10, 12);

  late Directory dir;
  late PetLocalStore store;
  late PetPhotoStore files;
  late PetRepository pets;
  late DiaryRepository diary;
  late String petId;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diary_files');
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    files = PetPhotoStore(dir);
    pets = PetRepository(store, photos: files, now: () => today);
    diary = DiaryRepository(store, photos: files, now: () => today);
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
    List<EventFile> kept = const [],
    List<NewEventFile> fresh = const [],
  }) => EventInput(
    petId: petId,
    kind: EventKind.exam,
    title: 'Hemograma',
    occursOn: today,
    keptFiles: kept,
    newFiles: fresh,
  );

  NewEventFile named(String name, [Uint8List? bytes]) =>
      NewEventFile(name: name, bytes: bytes ?? pdf);

  test('file names are kept readable and safe', () {
    expect(cleanFileName('Hemograma.pdf'), 'Hemograma.pdf');
    expect(cleanFileName('Laudo'), 'Laudo.pdf');
    expect(cleanFileName('../../a/b:c?.PDF'), 'bc.pdf');
    expect(cleanFileName('   .pdf'), 'Arquivo.pdf');
    expect(cleanFileName('x' * 200), hasLength(80));
  });

  test('PDFs are kept on the phone and go up after the entry', () async {
    expect(fileMediaType(pdf), 'application/pdf');
    final event = await diary.saveEvent(
      input: input(fresh: [named('Hemograma.pdf')]),
      byUser: bruno,
    );
    final file = event.files.single;
    expect(file.name, 'Hemograma.pdf');
    expect(file.path, startsWith('$petId/'));
    expect(file.path, endsWith('.pdf'));
    expect(await files.read(file.path), pdf);
    expect((await diary.getEvent(event.id))!.files, event.files);

    final remote = FakeRemote();
    final sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: FakeNetwork(),
      photos: files,
    );
    expect(await sync.sync(), isA<SyncOk>());
    expect(remote.photos.keys, [file.path]);
    expect(remote.events.single.files, event.files);
  });

  test('only PDFs, at most five, up to 10 MB each', () async {
    expect(
      () => diary.saveEvent(
        input: input(
          fresh: [
            named('foto.pdf', Uint8List.fromList([1, 2])),
          ],
        ),
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => diary.saveEvent(
        input: input(fresh: [for (var i = 0; i < 6; i++) named('$i.pdf')]),
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
    final big = Uint8List(maxEventFileBytes + 1)..setAll(0, pdf);
    expect(
      () => diary.saveEvent(
        input: input(fresh: [named('grande.pdf', big)]),
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(await diary.listEvents(petId), isEmpty);
  });

  test('editing keeps and removes files; deleting removes all', () async {
    final first = await diary.saveEvent(
      input: input(fresh: [named('Hemograma.pdf'), named('Receita.pdf')]),
      byUser: bruno,
    );
    final [kept, dropped] = first.files;
    final edited = await diary.saveEvent(
      id: first.id,
      input: input(kept: [kept]),
      byUser: bruno,
    );
    expect(edited.files, [kept]);
    expect(await files.local(dropped.path), isNull);
    final queued = (await store.pending())
        .where((item) => item.entity == photoEntity)
        .map((item) => (item.entityId, item.payload['op']));
    expect(queued, contains((dropped.path, 'remove')));

    await diary.deleteEvent(id: first.id, byUser: bruno);
    expect(await files.local(kept.path), isNull);
  });

  test('a version 10 database gains files in diary entries', () async {
    final path = '${await getDatabasesPath()}/upgrade_v10_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 10,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
          'updated_at TEXT NOT NULL, deleted_at TEXT)',
        );
        await db.execute(
          'CREATE TABLE pet_events (id TEXT PRIMARY KEY, pet_id TEXT NOT NULL, '
          'kind TEXT NOT NULL, title TEXT NOT NULL, occurs_on TEXT NOT NULL, '
          'occurs_time TEXT, notes TEXT, contact_id TEXT, '
          "photo_paths TEXT NOT NULL DEFAULT '[]', updated_by TEXT, "
          'updated_at TEXT NOT NULL, deleted_at TEXT)',
        );
        await db.insert('pet_events', {
          'id': 'e1',
          'pet_id': 'p1',
          'kind': 'exam',
          'title': 'Raio X',
          'occurs_on': '2026-10-01',
          'updated_at': '2026-10-01T00:00:00.000Z',
        });
      },
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    expect((await upgraded.getEvent('e1'))!.files, isEmpty);
    await upgraded.close();
    await deleteDatabase(path);
  });

  testWidgets('the diary shows the PDF, and a tap opens it', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(
      () => diary.saveEvent(
        input: input(fresh: [named('Hemograma.pdf')]),
        byUser: bruno,
      ),
    );
    final opener = FakeOpener();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          petPhotoStoreProvider.overrideWithValue(files),
          documentOpenerProvider.overrideWithValue(opener),
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
    expect(find.text('Hemograma'), findsOneWidget);
    await tester.tap(find.text('Hemograma.pdf'));
    await settle();
    expect(opener.opened, ['Hemograma.pdf']);
  });
}
