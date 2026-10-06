import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/card_reader.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/data/photo_picker.dart';
import 'package:bowie/features/health/data/reading_consent.dart';
import 'package:bowie/features/health/domain/card_reading.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/presentation/card_reading_page.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';

/// What the Edge Function returns for the V10 page of Bowie's card
/// (test/fixtures/carteirinha-bowie), with one doubtful date.
Map<String, dynamic> v10PageJson() => <String, dynamic>{
  'is_vaccine_card': true,
  'doses': <Object>[
    {
      'kind': 'vaccine',
      'name': 'V10',
      'applied_on': '2024-05-05',
      'next_due_on': '2025-05-05',
      'product': 'Vanguard Plus (Zoetis)',
      'lot': '004/23',
      'veterinarian': '',
      'uncertain_fields': <String>[],
    },
    {
      'kind': 'vaccine',
      'name': 'V10',
      'applied_on': '2025-05-08',
      'next_due_on': '2026-05-08',
      'product': 'Vanguard Plus (Zoetis)',
      'lot': '002/24',
      'veterinarian': '',
      'uncertain_fields': ['lot'],
    },
    {
      'kind': 'vaccine',
      'name': 'V10',
      'applied_on': '2026-05-04',
      'next_due_on': '',
      'product': 'Vanguard Plus (Zoetis)',
      'lot': '003/25',
      'veterinarian': 'Josiane Borges Viana · CRMV-SP 43507',
      'uncertain_fields': ['next_due_on'],
    },
  ],
  'weights': [
    {'measured_on': '2026-05-04', 'weight_kg': 21.4},
    {'measured_on': '2025-05-08', 'weight_kg': 20.1},
  ],
  'issues': '',
};

final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);
// A valid 1×1 PNG, so the thumbnails can be drawn.
final png = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, //
  0, 0, 0, 1, 8, 2, 0, 0, 0, 144, 119, 83, 222, 0, 0, 0, 12, 73, 68, 65, 84,
  120, 156, 99, 248, 255, 255, 63, 0, 5, 254, 2, 254, 13, 239, 70, 184, 0, 0,
  0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

class FakeReader implements CardReader {
  FakeReader(this.reply);

  final Future<CardReading> Function() reply;
  var sent = <Uint8List>[];

  @override
  Future<CardReading> read(List<Uint8List> photos) {
    sent = photos;
    return reply();
  }
}

class FakePicker implements PhotoPicker {
  @override
  Future<List<Uint8List>> pick(PhotoSource source, {required int max}) async {
    return [png];
  }
}

void main() {
  const owner = AppUser(id: 'owner-1', email: 'owner@example.com');
  final today = DateTime(2026, 10, 2);

  group('reading', () {
    test('parses the function answer and keeps doubts', () {
      final reading = CardReading.fromJson(v10PageJson());
      expect(reading.isVaccineCard, isTrue);
      expect(reading.doses, hasLength(3));
      expect(reading.doses[1].uncertain, {ReadField.lot});
      expect(reading.doses[2].nextDueOn, isNull);
      expect(reading.doses[0].veterinarian, isNull);
      expect(reading.issues, isNull);
      expect(reading.latestWeight?.weightKg, 21.4);
    });

    test('review skips repeats, unselects saved and incomplete doses', () {
      final json = v10PageJson();
      // The same page photographed twice.
      (json['doses'] as List).add(Map.of((json['doses'] as List).first));
      final reading = CardReading.fromJson(json);
      final saved = VaccineDose(
        id: 'old',
        petId: 'p',
        kind: DoseKind.vaccine,
        name: 'v10',
        appliedOn: DateTime(2024, 5, 5),
        nextDueOn: DateTime(2025, 5, 5),
        updatedAt: DateTime.utc(2026),
      );

      final items = buildReview(reading, [saved], today);

      expect(items.map((i) => i.dose.appliedOn), [
        DateTime(2024, 5, 5),
        DateTime(2025, 5, 8),
        DateTime(2026, 5, 4),
      ]);
      expect(items.map((i) => i.alreadySaved), [true, false, false]);
      expect(items.map((i) => i.selected), [false, true, false]);
      expect(items.last.dose.problemOn(today), 'Falta a data da próxima dose');
    });

    test('photo formats are recognized by their first bytes', () {
      expect(photoMediaType(jpeg), 'image/jpeg');
      expect(
        photoMediaType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D])),
        'image/png',
      );
      expect(
        photoMediaType(
          Uint8List.fromList([
            ...ascii.encode('RIFF'),
            0,
            0,
            0,
            0,
            ...ascii.encode('WEBP'),
          ]),
        ),
        'image/webp',
      );
      // HEIC from an iPhone gallery is not accepted as is.
      expect(
        photoMediaType(
          Uint8List.fromList([0, 0, 0, 0x18, ...ascii.encode('ftypheic')]),
        ),
        isNull,
      );
    });

    test('function errors become Portuguese messages', () {
      expect(
        readingFailure(503, {
          'error': 'busy',
          'message': 'Muitas leituras agora.',
        }).message,
        'Muitas leituras agora.',
      );
      expect(readingFailure(404, 'Not found').message, contains('configurada'));
      expect(readingFailure(500, null).retryable, isTrue);
    });
  });

  group('saving', () {
    late PetLocalStore store;
    late PetRepository pets;
    late HealthRepository health;
    late String petId;

    setUp(() async {
      store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
      pets = PetRepository(store, now: () => today);
      health = HealthRepository(store, now: () => today);
      petId = (await pets.createPet(
        profile: PetProfile(
          name: 'Bowie',
          species: PetSpecies.dog,
          birthDate: DateTime(2021, 5, 4),
        ),
        owner: owner,
      )).id;
    });

    tearDown(() => store.close());

    DoseInput input(DateTime applied, DateTime? due) => DoseInput(
      petId: petId,
      kind: DoseKind.vaccine,
      name: 'V10',
      appliedOn: applied,
      nextDueOn: due,
    );

    test('several doses save together, or none do', () async {
      await expectLater(
        health.saveDoses(
          inputs: [
            input(DateTime(2025, 5, 8), DateTime(2026, 5, 8)),
            input(DateTime(2026, 5, 4), null),
          ],
          byUser: owner,
        ),
        throwsA(isA<AppFailure>()),
      );
      expect(await health.listDoses(petId), isEmpty);

      await health.saveDoses(
        inputs: [
          input(DateTime(2025, 5, 8), DateTime(2026, 5, 8)),
          input(DateTime(2026, 5, 4), DateTime(2027, 5, 4)),
        ],
        byUser: owner,
      );
      expect(await health.listDoses(petId), hasLength(2));
    });

    test('a tutor can update the weight from the card', () async {
      await pets.updateWeight(petId: petId, weightKg: 21.43, byUser: owner);
      expect((await pets.getDetails(petId))!.pet.weightKg, 21.4);
      expect(
        () => pets.updateWeight(petId: petId, weightKg: 0, byUser: owner),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  testWidgets('reads a photo, asks consent once and saves what was chosen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    late PetLocalStore store;
    late String petId;
    await tester.runAsync(() async {
      store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
      petId = (await PetRepository(store, now: () => today).createPet(
        profile: PetProfile(
          name: 'Bowie',
          species: PetSpecies.dog,
          birthDate: DateTime(2021, 5, 4),
        ),
        owner: owner,
      )).id;
    });
    addTearDown(() => tester.runAsync(store.close));

    final reader = FakeReader(() async => CardReading.fromJson(v10PageJson()));
    final consent = MemoryReadingConsent();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          healthRepositoryProvider.overrideWithValue(
            HealthRepository(store, now: () => today),
          ),
          petRepositoryProvider.overrideWithValue(
            PetRepository(store, now: () => today),
          ),
          currentUserProvider.overrideWithValue(owner),
          cardReaderProvider.overrideWithValue(reader),
          readingConsentProvider.overrideWithValue(consent),
          photoPickerProvider.overrideWithValue(FakePicker()),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Saúde')),
            ),
            onGenerateInitialRoutes: (navigator, _) => [
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Saúde')),
              ),
              MaterialPageRoute<void>(
                builder: (_) => CardReadingPage(petId: petId),
              ),
            ],
          ),
        ),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
    }

    await settle();
    expect(find.text('Fotografe a carteirinha de Bowie'), findsOneWidget);

    await tester.tap(find.text('Tirar foto'));
    await settle();
    expect(find.byTooltip('Remover foto 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ler a foto'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ler a foto'));
    await settle();

    // Nothing leaves the phone before consent.
    expect(find.text('Enviar as fotos para leitura?'), findsOneWidget);
    expect(reader.sent, isEmpty);
    await tester.tap(find.text('Concordo'));
    await settle();

    expect(consent.value, isTrue);
    expect(reader.sent, [png]);
    expect(find.text('Confira o que foi lido'), findsOneWidget);
    Future<void> scrollTo(Finder finder) => tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await scrollTo(find.text('Confira: lote'));
    await scrollTo(find.text('Falta a data da próxima dose'));
    await scrollTo(
      find.textContaining('Atualizar o peso de Bowie para 21,4 kg'),
    );
    // Two complete doses plus the weight.
    final save = find.text('Salvar 3 registros');
    await tester.tap(save);
    await settle();

    expect(find.text('Saúde'), findsOneWidget);
    await tester.runAsync(() async {
      final doses = await store.listDoses(petId);
      expect(doses, hasLength(2));
      expect((await store.getPet(petId))!.weightKg, 21.4);
    });
  });
}
