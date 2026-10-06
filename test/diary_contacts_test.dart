import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/contacts/data/contacts_repository.dart';
import 'package:bowie/features/contacts/domain/contact.dart';
import 'package:bowie/features/contacts/presentation/contacts_page.dart';
import 'package:bowie/features/contacts/presentation/contacts_providers.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/diary/presentation/diary_page.dart';
import 'package:bowie/features/diary/presentation/diary_providers.dart';
import 'package:bowie/features/houses/last_house.dart';
import 'package:bowie/features/houses/houses_providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';

import 'support/fakes.dart';

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  const ana = AppUser(id: 'ana-1', email: 'ana@example.com');
  const stranger = AppUser(id: 'x-1', email: 'x@example.com');
  final today = DateTime(2026, 10, 10);

  late PetLocalStore store;
  late PetRepository pets;
  late DiaryRepository diary;
  late ContactsRepository contacts;
  late String bowieId;
  late String miaId;

  PetProfile profile(String name) => PetProfile(
    name: name,
    species: PetSpecies.dog,
    sex: PetSex.male,
    birthDate: DateTime(2021, 5, 4),
  );

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => today);
    diary = DiaryRepository(store, now: () => today);
    contacts = ContactsRepository(store, now: () => today);
    bowieId = (await pets.createPet(
      profile: profile('Bowie'),
      owner: bruno,
    )).id;
    miaId = (await pets.createPet(profile: profile('Mia'), owner: ana)).id;
  });

  tearDown(() => store.close());

  EventInput input(
    String title,
    DateTime day, {
    EventKind kind = EventKind.symptom,
    String? time,
    String? contactId,
  }) => EventInput(
    petId: bowieId,
    kind: kind,
    title: title,
    occursOn: day,
    time: time,
    contactId: contactId,
  );

  group('diary', () {
    test(
      'entries list the latest day first, and by time within a day',
      () async {
        await diary.saveEvent(
          input: input('Diarreia', DateTime(2026, 10, 8)),
          byUser: bruno,
        );
        await diary.saveEvent(
          input: input(
            'Retorno',
            DateTime(2026, 10, 9),
            kind: EventKind.vetVisit,
            time: '16:00',
          ),
          byUser: bruno,
        );
        await diary.saveEvent(
          input: input(
            'Consulta de rotina',
            DateTime(2026, 10, 9),
            kind: EventKind.vetVisit,
            time: '09:30',
          ),
          byUser: bruno,
        );
        final titles = (await diary.listEvents(bowieId)).map((e) => e.title);
        expect(titles, ['Consulta de rotina', 'Retorno', 'Diarreia']);
      },
    );

    test('future entries are scheduled; the nearest comes first', () async {
      await diary.saveEvent(
        input: input(
          'Ultrassonografia',
          DateTime(2026, 10, 20),
          kind: EventKind.exam,
        ),
        byUser: bruno,
      );
      await diary.saveEvent(
        input: input(
          'Exame de sangue (hemograma)',
          DateTime(2026, 10, 14),
          kind: EventKind.exam,
          time: '08:00',
        ),
        byUser: bruno,
      );
      await diary.saveEvent(input: input('Vômito', today), byUser: bruno);
      final events = await diary.listEvents(bowieId);
      expect(upcomingEvents(events, today).map((e) => e.title), [
        'Exame de sangue (hemograma)',
        'Ultrassonografia',
      ]);
      expect(
        events.firstWhere((e) => e.title == 'Vômito').isScheduled(today),
        isFalse,
      );
    });

    test('bad input and strangers are refused', () async {
      expect(
        () => diary.saveEvent(input: input('  ', today), byUser: bruno),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => diary.saveEvent(
          input: input('Consulta', today, time: '25:00'),
          byUser: bruno,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => diary.saveEvent(input: input('Tosse', today), byUser: stranger),
        throwsA(isA<AppFailure>()),
      );
    });

    test('a contact must belong to the pet\'s house', () async {
      final vet = await contacts.save(
        houseId: bruno.id,
        input: const ContactInput(
          name: 'Dra. Josiane',
          category: ContactCategory.vet,
        ),
        byUser: bruno,
      );
      final anasVet = await contacts.save(
        houseId: ana.id,
        input: const ContactInput(
          name: 'Clínica da Mia',
          category: ContactCategory.vet,
        ),
        byUser: ana,
      );
      final event = await diary.saveEvent(
        input: input(
          'Consulta',
          today,
          kind: EventKind.vetVisit,
          contactId: vet.id,
        ),
        byUser: bruno,
      );
      expect(event.contactId, vet.id);
      expect(
        () => diary.saveEvent(
          input: input('Consulta', today, contactId: anasVet.id),
          byUser: bruno,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect((await contacts.listForPet(bowieId)).map((c) => c.name), [
        'Dra. Josiane',
      ]);
      expect((await contacts.listForPet(miaId)).map((c) => c.name), [
        'Clínica da Mia',
      ]);
    });

    test('deleting hides the entry and records who', () async {
      final event = await diary.saveEvent(
        input: input('Coceira', today),
        byUser: bruno,
      );
      await diary.deleteEvent(id: event.id, byUser: bruno);
      expect(await diary.listEvents(bowieId), isEmpty);
      final row = (await store.pending())
          .firstWhere((item) => item.entity == 'pet_events')
          .payload;
      expect(row['deleted_at'], isNotNull);
      expect(row['occurs_on'], '2026-10-10');
    });
  });

  group('contacts', () {
    test('phones are kept as digits and shown the Brazilian way', () {
      expect(normalizePhone('(11) 98765-4321'), '11987654321');
      expect(normalizePhone('+55 11 98765-4321'), '11987654321');
      expect(normalizePhone('011 3456-7890'), '1134567890');
      expect(normalizePhone('98765-4321'), isNull);
      expect(formatPhone('11987654321'), '(11) 98765-4321');
      expect(formatPhone('1134567890'), '(11) 3456-7890');
      expect(isMobile('11987654321'), isTrue);
      expect(isMobile('1134567890'), isFalse);
    });

    test('saved by category, then name; bad data is refused', () async {
      Future<void> add(String name, ContactCategory category) => contacts.save(
        houseId: bruno.id,
        input: ContactInput(name: name, category: category),
        byUser: bruno,
      );
      await add('Creche Patinhas', ContactCategory.daycare);
      await add('Zoe Vet', ContactCategory.vet);
      await add('Clínica Vetprado', ContactCategory.vet);
      expect((await contacts.list(bruno.id)).map((c) => c.name), [
        'Clínica Vetprado',
        'Zoe Vet',
        'Creche Patinhas',
      ]);

      expect(
        () => contacts.save(
          houseId: bruno.id,
          input: const ContactInput(
            name: 'X',
            category: ContactCategory.vet,
            phone: '1234',
          ),
          byUser: bruno,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => contacts.save(
          houseId: bruno.id,
          input: const ContactInput(
            name: 'X',
            category: ContactCategory.vet,
            email: 'sem-arroba',
          ),
          byUser: bruno,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(
        () => add('Hotel', ContactCategory.hotel).then(
          (_) => contacts.save(
            houseId: bruno.id,
            input: const ContactInput(
              name: 'Hotel',
              category: ContactCategory.hotel,
            ),
            byUser: ana,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('a deleted contact still names old diary entries', () async {
      final vet = await contacts.save(
        houseId: bruno.id,
        input: const ContactInput(
          name: 'Dra. Josiane',
          category: ContactCategory.vet,
          phone: '11 98765-4321',
          email: ' Josiane@Vet.com ',
        ),
        byUser: bruno,
      );
      expect(vet.phone, '11987654321');
      expect(vet.email, 'josiane@vet.com');
      await contacts.delete(id: vet.id, byUser: bruno);
      expect(await contacts.list(bruno.id), isEmpty);
      expect((await contacts.get(vet.id))?.name, 'Dra. Josiane');
    });

    test('contacts sync before the diary entries that point to them', () async {
      final remote = FakeRemote();
      final sync = PetSyncService(
        store: store,
        remote: remote,
        isSignedIn: () => true,
        network: FakeNetwork(),
      );
      final vet = await contacts.save(
        houseId: bruno.id,
        input: const ContactInput(
          name: 'Dra. Josiane',
          category: ContactCategory.vet,
        ),
        byUser: bruno,
      );
      // The entry is created first, but goes up after the contact.
      await diary.saveEvent(
        input: input('Consulta', today, contactId: vet.id),
        byUser: bruno,
      );
      expect(await sync.sync(), isA<SyncOk>());
      expect(
        remote.calls.indexOf('house_contacts'),
        lessThan(remote.calls.indexOf('pet_events')),
      );
      expect(remote.events.single.contactId, vet.id);
      expect(remote.contacts.single.id, vet.id);
    });
  });

  test(
    'a version 5 database gains the diary and contacts on upgrade',
    () async {
      final path = '${await getDatabasesPath()}/upgrade_v5_test.db';
      await deleteDatabase(path);
      final old = await openDatabase(
        path,
        version: 5,
        onCreate: (db, _) => db.execute(
          'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
          'updated_at TEXT NOT NULL)',
        ),
      );
      await old.close();
      final upgraded = await PetLocalStore.open(databasePath: path);
      expect(await upgraded.listEvents('any'), isEmpty);
      expect(await upgraded.listContacts('any'), isEmpty);
      await upgraded.close();
      await deleteDatabase(path);
    },
  );

  test('day names read naturally', () {
    expect(describeDay(today, today), 'Hoje');
    expect(describeDay(DateTime(2026, 10, 11), today), 'Amanhã');
    expect(describeDay(DateTime(2026, 10, 9), today), 'Ontem');
    expect(
      describeDay(DateTime(2026, 10, 14), today),
      'quarta-feira, 14 de outubro',
    );
    expect(formatMonth(today), 'Outubro de 2026');
  });

  group('screens', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Widget app(Widget home) => ProviderScope(
      overrides: [
        petLocalStoreProvider.overrideWithValue(store),
        currentUserProvider.overrideWithValue(bruno),
        petRepositoryProvider.overrideWithValue(pets),
        diaryRepositoryProvider.overrideWithValue(diary),
        contactsRepositoryProvider.overrideWithValue(contacts),
        lastHouseProvider.overrideWithValue(MemoryLastHouse()),
      ],
      child: MaterialApp(theme: buildTheme(Brightness.light), home: home),
    );

    testWidgets('the diary shows the day, what is scheduled and who', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        final vet = await contacts.save(
          houseId: bruno.id,
          input: const ContactInput(
            name: 'Dra. Josiane',
            category: ContactCategory.vet,
            phone: '11987654321',
          ),
          byUser: bruno,
        );
        await diary.saveEvent(input: input('Diarreia', today), byUser: bruno);
        await diary.saveEvent(
          input: input(
            'Ultrassonografia',
            DateTime(2026, 10, 20),
            kind: EventKind.exam,
            time: '10:00',
            contactId: vet.id,
          ),
          byUser: bruno,
        );
      });

      await tester.pumpWidget(app(const DiaryPage()));
      await settle(tester);

      expect(find.text('Outubro de 2026'), findsOneWidget);
      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Diarreia'), findsOneWidget);
      // Mia is Ana's pet only, so Bruno sees no pet selector.
      expect(find.text('Mia'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Ultrassonografia'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Próximos agendamentos'), findsOneWidget);
      expect(find.textContaining('às 10:00'), findsOneWidget);
      expect(find.text('Dra. Josiane'), findsOneWidget);
      expect(find.byTooltip('Ligar para Dra. Josiane'), findsOneWidget);
    });

    testWidgets('contacts are grouped by kind with a call button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        await contacts.save(
          houseId: bruno.id,
          input: const ContactInput(
            name: 'Creche Patinhas',
            category: ContactCategory.daycare,
          ),
          byUser: bruno,
        );
        await contacts.save(
          houseId: bruno.id,
          input: const ContactInput(
            name: 'Dra. Josiane',
            category: ContactCategory.vet,
            phone: '11987654321',
          ),
          byUser: bruno,
        );
      });

      await tester.pumpWidget(app(const ContactsPage()));
      await settle(tester);

      expect(find.text('Veterinário'), findsOneWidget);
      expect(find.text('Creche'), findsOneWidget);
      expect(find.text('(11) 98765-4321'), findsOneWidget);
      expect(find.byTooltip('Ligar para Dra. Josiane'), findsOneWidget);

      await tester.tap(find.text('Dra. Josiane'));
      await settle(tester);
      expect(find.text('Ligar para (11) 98765-4321'), findsOneWidget);
      expect(find.text('Mandar mensagem no WhatsApp'), findsOneWidget);
      expect(find.text('Editar contato'), findsOneWidget);
    });
  });
}
