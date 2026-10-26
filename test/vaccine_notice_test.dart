import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/flags.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/notifications/domain/vaccine_notice.dart';
import 'package:bowie/features/notifications/presentation/notifications_page.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';

void main() {
  final created = DateTime(2026, 10, 1, 15);
  final today = DateTime(2026, 10, 8);

  Pet pet({
    PetSpecies? species = PetSpecies.dog,
    PetSex? sex = PetSex.male,
    DateTime? createdAt,
  }) => Pet(
    id: 'p1',
    name: sex == PetSex.female ? 'Mia' : 'Bowie',
    species: species,
    sex: sex,
    createdAt: createdAt ?? created,
    updatedAt: created,
  );

  VaccineDose dose(String name, {DoseKind kind = DoseKind.vaccine}) =>
      VaccineDose(
        id: name,
        petId: 'p1',
        kind: kind,
        name: name,
        appliedOn: DateTime(2026, 9, 1),
        nextDueOn: DateTime(2027, 9, 1),
        updatedAt: created,
      );

  test('7 days after the pet is registered, the notice lists what is missing, '
      'in order of importance', () {
    expect(
      vaccineNotice(pet(), const [], DateTime(2026, 10, 7)),
      isNull,
      reason: '6 days is too soon',
    );
    final notice = vaccineNotice(pet(), const [], today)!;
    expect(notice.title, 'O Bowie ainda não tem todas as vacinas cadastradas.');
    expect(notice.body, 'Faltam: Raiva, V8 ou V10, Tosse dos canis e Giárdia.');
    expect(notice.missing.first.suggestion, 'Raiva');
  });

  test('the names on the card count, with or without accents', () {
    final notice = vaccineNotice(pet(), [
      dose('Antirrábica'),
      dose('V10 (déctupla)'),
      dose('Giardíase'),
      dose('Drontal', kind: DoseKind.dewormer),
    ], today)!;
    expect(notice.body, 'Falta: Tosse dos canis.');
    expect(
      vaccineNotice(pet(), [
        dose('Raiva'),
        dose('V8'),
        dose('Tosse dos canis'),
        dose('Giárdia'),
      ], today),
      isNull,
    );
  });

  test('cats need Raiva and V3, V4 or V5', () {
    final cat = pet(species: PetSpecies.cat, sex: PetSex.female);
    final notice = vaccineNotice(cat, [dose('V5 (quíntupla felina)')], today)!;
    expect(notice.title, 'A Mia ainda não tem todas as vacinas cadastradas.');
    expect(notice.body, 'Falta: Raiva.');
  });

  test('no notice without the species or the registration date', () {
    expect(vaccineNotice(pet(species: null), const [], today), isNull);
    final unknown = Pet(
      id: 'p1',
      name: 'Bowie',
      species: PetSpecies.dog,
      updatedAt: created,
    );
    expect(vaccineNotice(unknown, const [], today), isNull);
  });

  testWidgets('the bell counts the notices and the page offers to register', (
    tester,
  ) async {
    const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
    final store = (await tester.runAsync(
      () => PetLocalStore.open(databasePath: inMemoryDatabasePath),
    ))!;
    addTearDown(() => tester.runAsync(store.close));
    final pets = PetRepository(store, now: () => created);
    final bowie = await tester.runAsync(
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
    final flags = MemoryFlags();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          petRepositoryProvider.overrideWithValue(pets),
          healthRepositoryProvider.overrideWithValue(
            HealthRepository(store, now: () => today),
          ),
          currentUserProvider.overrideWithValue(bruno),
          flagsProvider.overrideWithValue(flags),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Scaffold(
            appBar: AppBar(actions: const [NotificationsButton()]),
            body: const NotificationsPage(),
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    expect(find.byTooltip('Notificações: 1 aviso'), findsOneWidget);
    expect(
      find.text('O Bowie ainda não tem todas as vacinas cadastradas.'),
      findsOneWidget,
    );
    expect(find.text('Registrar vacina: Raiva'), findsOneWidget);

    await tester.tap(find.text('Não lembrar mais'));
    await settle();
    expect(await flags.isSet('vaccine_notice_off_${bowie!.id}'), isTrue);
    expect(find.text('Nenhuma notificação por enquanto'), findsOneWidget);
    expect(find.byTooltip('Notificações'), findsOneWidget);
  });
}
