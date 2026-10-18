import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/flags.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/home/presentation/home_page.dart';
import 'package:bowie/features/onboarding/domain/pet_checklist.dart';
import 'package:bowie/features/onboarding/presentation/onboarding_pages.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_photo_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/reminders/presentation/reminder_providers.dart';

import 'reminders_test.dart' show FakeGateway;

void main() {
  const bruno = AppUser(
    id: 'bruno-1',
    email: 'bruno@example.com',
    name: 'Bruno',
    phone: '11987654321',
  );
  final today = DateTime(2026, 10, 17);

  test('the essentials: vaccines first, then photo, birth and weight', () {
    final pet = Pet(
      id: 'p1',
      name: 'Bowie',
      birthDate: DateTime(2021, 5, 4),
      updatedAt: DateTime.utc(2026),
    );
    final items = petChecklist(pet, hasVaccines: false);
    expect(items.map((i) => (i.label, i.done)), [
      ('Vacinas', false),
      ('Foto', false),
      ('Nascimento', true),
      ('Peso', false),
    ]);
    expect(items.first.route, '/saude/carteirinha?pet=p1');
  });

  group('screens', () {
    late Directory dir;
    late PetLocalStore store;
    late PetRepository pets;
    late HealthRepository health;
    late FakeGateway gateway;

    Future<void> setUpData(WidgetTester tester) async {
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('onboarding');
        store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
      });
      pets = PetRepository(store, now: () => today);
      health = HealthRepository(store, now: () => today);
      gateway = FakeGateway();
      addTearDown(
        () => tester.runAsync(() async {
          await store.close();
          await dir.delete(recursive: true);
        }),
      );
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Widget app({required Widget home, GoRouter? router}) {
      final overrides = [
        petLocalStoreProvider.overrideWithValue(store),
        petPhotoStoreProvider.overrideWithValue(PetPhotoStore(dir)),
        currentUserProvider.overrideWithValue(bruno),
        petRepositoryProvider.overrideWithValue(pets),
        healthRepositoryProvider.overrideWithValue(health),
        notificationGatewayProvider.overrideWithValue(gateway),
        flagsProvider.overrideWithValue(MemoryFlags()),
      ];
      return ProviderScope(
        overrides: overrides,
        child: router == null
            ? MaterialApp(theme: buildTheme(Brightness.light), home: home)
            : MaterialApp.router(
                theme: buildTheme(Brightness.light),
                routerConfig: router,
              ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('a new account lands on the welcome', (tester) async {
      await setUpData(tester);
      await tester.pumpWidget(app(home: const HomePage()));
      await settle(tester);
      expect(find.text('Boas-vindas ao Bowie'), findsOneWidget);
      expect(find.text('Cadastrar meu pet'), findsOneWidget);
    });

    testWidgets('the path goes from the pet to the vaccines to the end', (
      tester,
    ) async {
      await setUpData(tester);
      final router = GoRouter(
        initialLocation: '/boas-vindas/pet',
        routes: [
          ...onboardingRoutes(),
          GoRoute(
            path: '/inicio',
            builder: (context, state) => const Text('Início'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(app(home: const SizedBox(), router: router));
      await settle(tester);

      expect(find.text('Passo 1 de 3'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Bowie');
      await tester.tap(find.text('Cão'));
      await tester.tap(find.text('Macho'));
      await tester.pump();
      await tester.ensureVisible(find.text('Não sei a data exata'));
      await tester.tap(find.text('Não sei a data exata'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Idade aproximada (anos)'),
        '5',
      );
      await tester.scrollUntilVisible(
        find.text('Cadastrar pet'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Cadastrar pet'));
      await settle(tester);

      // Step 2: nothing registered yet.
      expect(find.text('Passo 2 de 3'), findsOneWidget);
      expect(find.text('Fotografar a carteirinha'), findsOneWidget);
      expect(find.text('Registrar à mão'), findsOneWidget);

      final petId = (await tester.runAsync(
        () => store.listPetsFor(bruno.email),
      ))!.single.id;
      await tester.runAsync(
        () => health.saveDose(
          input: DoseInput(
            petId: petId,
            kind: DoseKind.vaccine,
            name: 'V10',
            appliedOn: DateTime(2026, 5, 4),
            nextDueOn: DateTime(2027, 5, 4),
          ),
          byUser: bruno,
        ),
      );
      await settle(tester);
      expect(find.text('V10'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await settle(tester);

      // Step 3: the reminders, then the extras.
      expect(find.text('Passo 3 de 3'), findsOneWidget);
      expect(find.text('Receber avisos'), findsOneWidget);
      expect(find.text('Remédios em uso'), findsOneWidget);
      expect(find.text('Alergias e cuidados especiais'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ir para o início'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ir para o início'));
      await settle(tester);
      expect(find.text('Início'), findsOneWidget);
    });

    testWidgets('Início shows what the sheet still misses', (tester) async {
      await setUpData(tester);
      await tester.runAsync(
        () => pets.createPet(
          profile: PetProfile(
            name: 'Bowie',
            species: PetSpecies.dog,
            sex: PetSex.male,
            birthDate: DateTime(2021, 5, 4),
          ),
          owner: bruno,
        ),
      );
      await tester.pumpWidget(app(home: const HomePage()));
      await settle(tester);
      expect(find.text('Ficha do Bowie: 1 de 4'), findsOneWidget);
      expect(find.text('Vacinas'), findsOneWidget);
      expect(find.text('Peso'), findsOneWidget);
      expect(find.text('Nascimento'), findsNothing);
      // Reminders still off: asked once, with a way to say no.
      await tester.ensureVisible(find.text('Agora não'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agora não'));
      await settle(tester);
      expect(find.text('Receber avisos'), findsNothing);
    });
  });
}
