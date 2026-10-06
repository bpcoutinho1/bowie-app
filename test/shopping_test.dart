import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/houses/last_house.dart';
import 'package:bowie/features/shopping/data/shopping_repository.dart';
import 'package:bowie/features/shopping/domain/shopping_catalog.dart';
import 'package:bowie/features/shopping/domain/shopping_item.dart';
import 'package:bowie/features/shopping/presentation/shopping_page.dart';
import 'package:bowie/features/houses/houses.dart';
import 'package:bowie/features/houses/houses_providers.dart';
import 'package:bowie/features/shopping/presentation/shopping_providers.dart';

import 'support/fakes.dart';

void main() {
  // Bruno is the main tutor of Bowie; Ana (his mother) of Mia, and Bruno
  // cares for Mia too. A walker only cares for Bowie.
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  const ana = AppUser(id: 'ana-1', email: 'ana@example.com');
  const walker = AppUser(id: 'walker-1', email: 'walker@example.com');
  const stranger = AppUser(id: 'x-1', email: 'x@example.com');
  final today = DateTime(2026, 10, 9);

  late PetLocalStore store;
  late PetRepository pets;
  late ShoppingRepository shopping;

  PetProfile profile(String name) => PetProfile(
    name: name,
    species: PetSpecies.dog,
    sex: PetSex.male,
    birthDate: DateTime(2021, 5, 4),
  );

  Future<void> join(String petId, AppUser owner, AppUser tutor) async {
    await pets.inviteTutor(petId: petId, email: tutor.email, byUser: owner);
    final invite = (await pets.listInvites(
      tutor.email,
    )).firstWhere((i) => i.tutor.petId == petId);
    await pets.acceptInvite(tutorId: invite.tutor.id, user: tutor);
  }

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => today);
    shopping = ShoppingRepository(store, now: () => today);
    final bowie = await pets.createPet(profile: profile('Bowie'), owner: bruno);
    final mia = await pets.createPet(profile: profile('Mia'), owner: ana);
    await join(mia.id, ana, bruno);
    await join(bowie.id, bruno, walker);
  });

  tearDown(() => store.close());

  group('houses', () {
    test(
      'each main tutor has one; tutors see the houses they belong to',
      () async {
        final brunos = await shopping.listHouses(bruno);
        expect(brunos.map((h) => h.label), [
          'Minha casa',
          'Casa de ana@example.com',
        ]);
        expect(brunos.first.id, bruno.id);

        expect((await shopping.listHouses(ana)).map((h) => h.id), [ana.id]);
        expect(
          (await shopping.listHouses(walker)).map((h) => (h.id, h.isMine)),
          [(bruno.id, false)],
        );
        expect(await shopping.listHouses(stranger), isEmpty);
      },
    );

    test('lists never mix: an item of one house is not in the other', () async {
      await shopping.add(houseId: bruno.id, name: 'Ração', byUser: bruno);
      await shopping.add(houseId: ana.id, name: 'Areia', byUser: bruno);

      expect((await shopping.listItems(bruno.id)).toBuy.map((i) => i.name), [
        'Ração',
      ]);
      expect((await shopping.listItems(ana.id)).toBuy.map((i) => i.name), [
        'Areia',
      ]);
    });

    test('only people of the house can change its list', () async {
      expect(
        () => shopping.add(houseId: bruno.id, name: 'Ração', byUser: stranger),
        throwsA(isA<AppFailure>()),
      );
      // Ana cares only for Mia, so Bruno's house is not hers.
      expect(
        () => shopping.add(houseId: bruno.id, name: 'Ração', byUser: ana),
        throwsA(isA<AppFailure>()),
      );
      await shopping.add(houseId: bruno.id, name: 'Petisco', byUser: walker);
    });
  });

  group('list', () {
    test('bought items go to the frequent ones and come back', () async {
      final food = await shopping.add(
        houseId: bruno.id,
        name: ' Ração ',
        details: 'Golden 15 kg',
        byUser: bruno,
      );
      expect(food.name, 'Ração');
      expect(food.catalogKey, 'food');

      await shopping.setStatus(
        id: food.id,
        status: ShoppingStatus.bought,
        byUser: walker,
      );
      var list = await shopping.listItems(bruno.id);
      expect(list.toBuy, isEmpty);
      expect(list.frequent.single.updatedBy, walker.id);

      // Adding the same name again brings the frequent item back.
      final again = await shopping.add(
        houseId: bruno.id,
        name: 'racao',
        byUser: bruno,
      );
      expect(again.id, food.id);
      expect(again.details, 'Golden 15 kg');
      list = await shopping.listItems(bruno.id);
      expect(list.toBuy.single.id, food.id);
      expect(list.frequent, isEmpty);
    });

    test('an item already on the list is not added twice', () async {
      await shopping.add(houseId: bruno.id, name: 'Areia', byUser: bruno);
      expect(
        () => shopping.add(houseId: bruno.id, name: 'areia', byUser: bruno),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            'Areia já está na lista.',
          ),
        ),
      );
    });

    test('editing and removing', () async {
      final item = await shopping.add(
        houseId: bruno.id,
        name: 'Bolinha',
        byUser: bruno,
      );
      expect(item.catalogKey, 'toy');
      await shopping.edit(
        id: item.id,
        name: 'Bolinha de tênis',
        details: '  ',
        byUser: bruno,
      );
      final edited = (await shopping.listItems(bruno.id)).toBuy.single;
      expect(edited.name, 'Bolinha de tênis');
      expect(edited.details, isNull);

      await shopping.delete(id: item.id, byUser: bruno);
      final list = await shopping.listItems(bruno.id);
      expect(list.toBuy, isEmpty);
      expect(list.frequent, isEmpty);
    });

    test('the catalog recognizes typed names', () {
      expect(matchCatalog('Ração Golden 15 kg')?.key, 'food');
      expect(matchCatalog('tapete higienico')?.key, 'pads');
      expect(matchCatalog('Coleira antipulgas')?.key, 'flea');
      expect(matchCatalog('Coleira de couro')?.key, 'collar');
      expect(matchCatalog('Antipulgas')?.key, 'flea');
      expect(matchCatalog('Vitamina'), isNull);
    });

    test('items sync after pets and tutors, and come back', () async {
      final remote = FakeRemote();
      final sync = PetSyncService(
        store: store,
        remote: remote,
        isSignedIn: () => true,
        network: FakeNetwork(),
      );
      final item = await shopping.add(
        houseId: bruno.id,
        name: 'Ração',
        byUser: bruno,
      );
      expect(await sync.sync(), isA<SyncOk>());
      expect(remote.calls.last, 'shopping_items');
      expect(
        remote.calls.indexOf('shopping_items'),
        greaterThan(remote.calls.lastIndexOf('pet_tutors')),
      );
      expect(remote.shopping.single.id, item.id);

      remote.shopping.add(
        ShoppingItem(
          id: 'from-ana',
          houseId: ana.id,
          name: 'Areia',
          status: ShoppingStatus.toBuy,
          updatedAt: DateTime.utc(2026, 10, 9),
        ),
      );
      await sync.sync();
      expect((await shopping.listItems(ana.id)).toBuy.single.id, 'from-ana');
    });
  });

  test('a version 4 database gains the shopping list on upgrade', () async {
    final path = '${await getDatabasesPath()}/upgrade_v4_test.db';
    await deleteDatabase(path);
    final old = await openDatabase(
      path,
      version: 4,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE pets (id TEXT PRIMARY KEY, name TEXT NOT NULL, '
        'updated_at TEXT NOT NULL)',
      ),
    );
    await old.close();
    final upgraded = await PetLocalStore.open(databasePath: path);
    expect(await upgraded.listShoppingItems('any'), isEmpty);
    await upgraded.close();
    await deleteDatabase(path);
  });

  testWidgets('add from the catalog, mark as bought, bring it back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          currentUserProvider.overrideWithValue(bruno),
          shoppingRepositoryProvider.overrideWithValue(shopping),
          lastHouseProvider.overrideWithValue(MemoryLastHouse()),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ShoppingPage(),
        ),
      ),
    );
    // Database calls finish in real time and their callbacks run on pump, so
    // alternate the two until the chain of reads is done.
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await settle();
    // Bruno belongs to two houses and starts in his own.
    expect(find.text('Minha casa'), findsOneWidget);
    expect(find.text('Casa de ana@example.com'), findsOneWidget);
    expect(find.textContaining('Nada para comprar ainda'), findsOneWidget);

    await tester.tap(find.text('Adicionar item'));
    await settle();
    await tester.tap(find.bySemanticsLabel('Ração'));
    await settle();
    expect(find.text('Ração está na lista.'), findsOneWidget);

    // Close the sheet.
    Navigator.of(tester.element(find.text('Adicionar à lista'))).pop();
    await settle();

    expect(find.text('Ração'), findsOneWidget);
    await tester.tap(find.text('Ração'));
    await settle();
    expect(find.text('Itens frequentes'), findsOneWidget);
    expect(find.text('Ração foi para os itens frequentes'), findsOneWidget);
    // The message leaves on its own after 5 seconds.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Ração foi para os itens frequentes'), findsNothing);

    await tester.tap(find.text('Ração'));
    await settle();
    expect(find.text('Itens frequentes'), findsNothing);

    // Ana's house has its own, empty list.
    await tester.ensureVisible(find.text('Casa de ana@example.com'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Casa de ana@example.com'));
    await settle();
    expect(find.textContaining('Nada para comprar ainda'), findsOneWidget);
  });
}
