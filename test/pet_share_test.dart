import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/share/data/pet_share_repository.dart';
import 'package:bowie/features/share/domain/pet_share.dart';
import 'package:bowie/features/share/presentation/pet_share_page.dart';
import 'package:bowie/features/share/presentation/share_providers.dart';

import 'support/fakes.dart';

/// Keeps links in memory, as the server would, with its 60 days.
class FakeShareApi implements PetShareApi {
  FakeShareApi(this.now);

  final DateTime Function() now;
  final shares = <PetShare>[];
  Object? failWith;

  @override
  Future<List<PetShare>> list(String petId) async {
    if (failWith != null) throw failWith!;
    return shares.where((s) => s.petId == petId).toList();
  }

  @override
  Future<PetShare> create({
    required String id,
    required String petId,
    required String token,
    required SharePreset preset,
    required String? label,
    required String createdBy,
  }) async {
    if (failWith != null) throw failWith!;
    final share = PetShare(
      id: id,
      petId: petId,
      token: token,
      preset: preset,
      label: label,
      createdAt: now(),
      expiresAt: now().add(const Duration(days: shareDays)),
    );
    shares.add(share);
    return share;
  }

  @override
  Future<void> revoke(String id, DateTime at) async {
    final i = shares.indexWhere((s) => s.id == id);
    final s = shares[i];
    shares[i] = PetShare(
      id: s.id,
      petId: s.petId,
      token: s.token,
      preset: s.preset,
      label: s.label,
      createdAt: s.createdAt,
      expiresAt: s.expiresAt,
      revokedAt: at,
    );
  }
}

void main() {
  const bruno = AppUser(
    id: 'bruno-1',
    email: 'bruno@example.com',
    name: 'Bruno',
    phone: '11987654321',
  );
  const stranger = AppUser(id: 'x-1', email: 'x@example.com');
  var now = DateTime.utc(2026, 10, 12, 15);

  late PetLocalStore store;
  late PetRepository pets;
  late FakeShareApi api;
  late PetShareRepository shares;
  late String petId;

  setUp(() async {
    now = DateTime.utc(2026, 10, 12, 15);
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => now);
    api = FakeShareApi(() => now);
    shares = PetShareRepository(store, api, now: () => now);
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

  tearDown(() => store.close());

  test('tokens are long, random and safe in a link', () {
    final a = newShareToken();
    final b = newShareToken();
    expect(a, hasLength(43));
    expect(a, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(a, isNot(b));
    final share = PetShare(
      id: '1',
      petId: petId,
      token: a,
      preset: SharePreset.vet,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 60)),
    );
    // After the "#": the token never reaches the page's server.
    expect(share.url, '$shareBaseUrl#$a');
  });

  test('a tutor creates a link for 60 days, with an optional name', () async {
    final share = await shares.create(
      petId: petId,
      preset: SharePreset.care,
      label: '  Hotel   Pet Feliz ',
      byUser: bruno,
    );
    expect(share.label, 'Hotel Pet Feliz');
    expect(share.expiresAt, now.add(const Duration(days: 60)));
    expect(await shares.activeShares(petId), [share]);

    final plain = await shares.create(
      petId: petId,
      preset: SharePreset.vet,
      label: ' ',
      byUser: bruno,
    );
    expect(plain.label, isNull);
  });

  test('only tutors share, and names stay short', () async {
    expect(
      () => shares.create(
        petId: petId,
        preset: SharePreset.care,
        byUser: stranger,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => shares.create(
        petId: petId,
        preset: SharePreset.care,
        label: 'x' * 61,
        byUser: bruno,
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('canceled and expired links leave the list', () async {
    final old = await shares.create(
      petId: petId,
      preset: SharePreset.care,
      byUser: bruno,
    );
    now = now.add(const Duration(days: 30));
    final canceled = await shares.create(
      petId: petId,
      preset: SharePreset.vet,
      byUser: bruno,
    );
    final kept = await shares.create(
      petId: petId,
      preset: SharePreset.vet,
      label: 'Dra. Ana',
      byUser: bruno,
    );
    await shares.revoke(share: canceled, byUser: bruno);
    expect((await shares.activeShares(petId)).map((s) => s.id), [
      kept.id,
      old.id,
    ]);
    now = now.add(const Duration(days: 31));
    expect((await shares.activeShares(petId)).map((s) => s.id), [kept.id]);
  });

  test('without internet, the message says so', () async {
    api.failWith = const SocketException('offline');
    expect(
      () =>
          shares.create(petId: petId, preset: SharePreset.care, byUser: bruno),
      throwsA(
        isA<AppFailure>().having(
          (f) => f.message,
          'message',
          contains('internet'),
        ),
      ),
    );
    final offline = PetShareRepository(store, null);
    expect(() => offline.activeShares(petId), throwsA(isA<AppFailure>()));
  });

  test('rows from the server become links', () {
    final share = PetShare.fromRow({
      'id': 's1',
      'pet_id': petId,
      'token': 'a' * 43,
      'preset': 'vet',
      'label': null,
      'created_at': '2026-10-12T15:00:00+00:00',
      'expires_at': '2026-12-11T15:00:00+00:00',
      'revoked_at': null,
      'last_viewed_at': '2026-10-13T10:00:00+00:00',
    });
    expect(share.preset, SharePreset.vet);
    expect(share.isActive(now), isTrue);
    expect(share.lastViewedAt, DateTime.utc(2026, 10, 13, 10));
  });

  testWidgets('creates a link and shows its QR code', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final network = FakeNetwork();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          currentUserProvider.overrideWithValue(bruno),
          petRepositoryProvider.overrideWithValue(pets),
          petShareRepositoryProvider.overrideWithValue(shares),
          networkStatusProvider.overrideWithValue(network),
          syncServiceProvider.overrideWithValue(
            PetSyncService(
              store: store,
              remote: FakeRemote(),
              isSignedIn: () => false,
              network: network,
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: PetSharePage(petId: petId),
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
    expect(find.text('Ficha do Bowie'), findsOneWidget);
    expect(find.text('Nenhum link ativo.'), findsOneWidget);

    await tester.tap(find.text('Veterinário'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome do lugar (opcional)'),
      'Dra. Ana',
    );
    await tester.tap(find.text('Criar link'));
    await settle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Enviar o link'), findsOneWidget);
    expect(find.text('Copiar o link'), findsOneWidget);
    expect(api.shares.single.preset, SharePreset.vet);
    expect(api.shares.single.label, 'Dra. Ana');

    Navigator.of(tester.element(find.text('Enviar o link'))).pop();
    await settle();
    expect(find.text('Dra. Ana'), findsOneWidget);
    expect(find.textContaining('Vale até 11/12/2026'), findsOneWidget);
  });
}
