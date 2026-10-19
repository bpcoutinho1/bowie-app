import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/data/account_eraser.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/auth/presentation/delete_account_page.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';

class FakeEraser implements AccountEraser {
  FakeEraser({this.failure});

  final AppFailure? failure;
  final calls = <Map<String, String>>[];

  @override
  Future<void> erase(Map<String, String> transfers) async {
    calls.add(transfers);
    if (failure case final failure?) throw failure;
  }
}

const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
const bia = AppUser(id: 'bia-1', email: 'bia@example.com');
const caio = AppUser(id: 'caio-1', email: 'caio@example.com');

/// Bowie (Bruno's, shared with Bia), Mia (Bruno's alone, with a pending
/// invite to Caio) and Thor (Bia's, with Bruno as a tutor).
Future<({String bowie, String biaOnBowie})> seed(PetLocalStore store) async {
  final pets = PetRepository(store, now: () => DateTime.utc(2026, 10, 20));
  Future<Pet> create(String name, AppUser owner) => pets.createPet(
    profile: PetProfile(
      name: name,
      species: PetSpecies.dog,
      sex: PetSex.male,
      birthDate: DateTime(2021, 5, 4),
    ),
    owner: owner,
  );
  Future<String> join(Pet pet, AppUser owner, AppUser who) async {
    await pets.inviteTutor(petId: pet.id, email: who.email, byUser: owner);
    final invite = (await store.listTutors(
      pet.id,
    )).firstWhere((tutor) => tutor.email == who.email);
    await pets.acceptInvite(tutorId: invite.id, user: who);
    return invite.id;
  }

  final bowie = await create('Bowie', bruno);
  final biaOnBowie = await join(bowie, bruno, bia);
  final mia = await create('Mia', bruno);
  await pets.inviteTutor(petId: mia.id, email: caio.email, byUser: bruno);
  final thor = await create('Thor', bia);
  await join(thor, bia, bruno);
  return (bowie: bowie.id, biaOnBowie: biaOnBowie);
}

void main() {
  test('pets with other tutors need a heir; pets alone go', () async {
    final store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    final ids = await seed(store);

    final pets = await accountPets(store, bruno);
    expect(pets.member, 1);
    final byName = {for (final owned in pets.owned) owned.pet.name: owned};
    expect(byName.keys, unorderedEquals(['Bowie', 'Mia']));
    expect(byName['Bowie']!.heirs.map((t) => t.id), [ids.biaOnBowie]);
    // A pending invite does not keep the pet.
    expect(byName['Mia']!.heirs, isEmpty);
  });

  test('erasing the phone leaves nothing behind', () async {
    final store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    addTearDown(store.close);
    await seed(store);
    await store.eraseAll();
    expect(await store.listPetsFor(bruno.email), isEmpty);
    expect(await store.listPetsFor(bia.email), isEmpty);
  });

  test('names read as a sentence', () {
    expect(joinNames(['Bowie']), 'Bowie');
    expect(joinNames(['Bowie', 'Mia']), 'Bowie e Mia');
    expect(joinNames(['Bowie', 'Mia', 'Thor']), 'Bowie, Mia e Thor');
  });

  test('server errors keep the message of the function', () {
    expect(
      erasingFailure(409, {
        'error': 'choose_main_tutor',
        'message': 'Escolha quem fica com cada pet.',
      }).message,
      'Escolha quem fica com cada pet.',
    );
    expect(
      erasingFailure(404, null).message,
      contains('ainda não foi configurada'),
    );
  });

  group('the page', () {
    late PetLocalStore store;
    late FakeEraser eraser;

    Future<({String bowie, String biaOnBowie})> pump(
      WidgetTester tester, {
      AppFailure? failure,
    }) async {
      store = (await tester.runAsync(
        () => PetLocalStore.open(databasePath: inMemoryDatabasePath),
      ))!;
      addTearDown(() => tester.runAsync(store.close));
      final ids = (await tester.runAsync(() => seed(store)))!;
      eraser = FakeEraser(failure: failure);
      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petLocalStoreProvider.overrideWithValue(store),
            currentUserProvider.overrideWithValue(bruno),
            accountEraserProvider.overrideWithValue(eraser),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const DeleteAccountPage(),
          ),
        ),
      );
      await settle(tester);
      return ids;
    }

    testWidgets('says what goes and suggests who keeps each pet', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Antes de continuar'), findsOneWidget);
      expect(find.textContaining('Mia, com todo o histórico'), findsOneWidget);
      expect(find.textContaining('Sua participação no pet'), findsOneWidget);
      expect(find.text('Tutor principal de Bowie'), findsOneWidget);
      expect(find.text(bia.email), findsOneWidget);
    });

    testWidgets('only deletes after the confirmation', (tester) async {
      final ids = await pump(tester);
      final button = find.text('Excluir minha conta');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settle(tester);
      expect(eraser.calls, isEmpty);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(button);
      await settle(tester);
      expect(eraser.calls, [
        {ids.bowie: ids.biaOnBowie},
      ]);
      expect(
        await tester.runAsync(() => store.listPetsFor(bruno.email)),
        isEmpty,
      );
    });

    testWidgets('a failure keeps everything and says why', (tester) async {
      await pump(
        tester,
        failure: const AppFailure('Sem conexão com a internet.'),
      );
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Excluir minha conta'));
      await settle(tester);
      expect(find.text('Sem conexão com a internet.'), findsOneWidget);
      expect(
        await tester.runAsync(() => store.listPetsFor(bruno.email)),
        hasLength(3),
      );
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}
