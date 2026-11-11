import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text_sharer.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/invite_message.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';

import 'support/fakes.dart';

class FakeSharer implements TextSharer {
  final shared = <String>[];

  @override
  Future<void> share(String text, {Rect? origin}) async => shared.add(text);
}

void main() {
  const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
  const ana = AppUser(id: 'ana-1', email: 'ana@example.com');

  late PetLocalStore store;
  late PetRepository pets;
  late Pet bowie;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    pets = PetRepository(store, now: () => DateTime.utc(2026, 10, 23));
    bowie = await pets.createPet(
      profile: PetProfile(
        name: 'Bowie',
        species: PetSpecies.dog,
        sex: PetSex.male,
        birthDate: DateTime(2021, 5, 4),
      ),
      owner: bruno,
    );
  });

  tearDown(() => store.close());

  test('the invitation goes up before its email is sent', () async {
    final remote = FakeRemote();
    final sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: FakeNetwork(),
    );
    final invite = await pets.inviteTutor(
      petId: bowie.id,
      email: 'Ana@Example.com',
      byUser: bruno,
    );
    expect(invite.email, 'ana@example.com');
    expect(invite.status, TutorStatus.pending);

    await sync.sendInvite(invite.id);
    expect(remote.invitesSent, [invite.id]);
    expect(remote.calls.last, 'invite');
    expect(
      remote.tutors.any((tutor) => tutor.id == invite.id),
      isTrue,
      reason: 'the row is on the server before the email',
    );
  });

  test('offline, the email waits and says why', () async {
    final sync = PetSyncService(
      store: store,
      remote: FakeRemote(),
      isSignedIn: () => true,
      network: FakeNetwork(online: false),
    );
    final invite = await pets.inviteTutor(
      petId: bowie.id,
      email: ana.email,
      byUser: bruno,
    );
    expect(
      () => sync.sendInvite(invite.id),
      throwsA(
        isA<AppFailure>().having(
          (f) => f.message,
          'message',
          contains('conecte-se à internet'),
        ),
      ),
    );
  });

  test('a pending invitation can be canceled', () async {
    final invite = await pets.inviteTutor(
      petId: bowie.id,
      email: ana.email,
      byUser: bruno,
    );
    expect(await pets.listInvites(ana.email), hasLength(1));

    await pets.removeTutor(petId: bowie.id, tutorId: invite.id, byUser: bruno);
    expect(await pets.listInvites(ana.email), isEmpty);
    final tutors = (await pets.getDetails(bowie.id))!.tutors;
    expect(tutors.map((t) => t.email), [bruno.email]);

    // The same email can be invited again.
    await pets.inviteTutor(petId: bowie.id, email: ana.email, byUser: bruno);
    expect(await pets.listInvites(ana.email), hasLength(1));
  });

  test(
    'a tutor who accepted can be removed, and stops seeing the pet',
    () async {
      final invite = await pets.inviteTutor(
        petId: bowie.id,
        email: ana.email,
        byUser: bruno,
      );
      await pets.acceptInvite(tutorId: invite.id, user: ana);
      expect(await pets.listPetsFor(ana.email), hasLength(1));

      await pets.removeTutor(
        petId: bowie.id,
        tutorId: invite.id,
        byUser: bruno,
      );
      expect(await pets.listPetsFor(ana.email), isEmpty);
      // The removal is queued for the server, so other phones follow.
      final pending = await store.pending();
      expect(
        pending.any(
          (item) =>
              item.entity == 'pet_tutors' &&
              item.entityId == invite.id &&
              item.payloadJson.contains('"deleted_at":"2026'),
        ),
        isTrue,
      );
    },
  );

  test('only the main tutor removes, and never themselves', () async {
    final invite = await pets.inviteTutor(
      petId: bowie.id,
      email: ana.email,
      byUser: bruno,
    );
    await pets.acceptInvite(tutorId: invite.id, user: ana);
    expect(
      () => pets.removeTutor(petId: bowie.id, tutorId: invite.id, byUser: ana),
      throwsA(isA<AppFailure>()),
    );
    final owner = (await pets.getDetails(
      bowie.id,
    ))!.tutors.firstWhere((t) => t.role == PetRole.owner);
    expect(
      () => pets.removeTutor(petId: bowie.id, tutorId: owner.id, byUser: bruno),
      throwsA(isA<AppFailure>()),
    );
  });

  test('the WhatsApp message says who, which pet, and which email', () {
    final text = inviteMessage(
      pet: bowie,
      email: 'ana@example.com',
      inviterName: 'Bruno',
    );
    expect(
      text,
      startsWith('Bruno convidou você para cuidar do Bowie no app Bowie 🐾'),
    );
    expect(text, contains('1. Baixe o app: https://bowieapp.pet'));
    expect(text, contains('com o email ana@example.com'));
    expect(text, contains('toque em "Aceitar" no convite do Bowie'));
    expect(
      inviteMessage(pet: bowie, email: 'ana@example.com'),
      startsWith('Você recebeu um convite para cuidar do Bowie'),
      reason: 'without a name, no gender for who reads it',
    );
  });

  testWidgets('after inviting, the invitation can go by WhatsApp', (
    tester,
  ) async {
    const brunoNamed = AppUser(
      id: 'bruno-1',
      email: 'bruno@example.com',
      name: 'Bruno',
    );
    final remote = FakeRemote();
    final sharer = FakeSharer();
    tester.view.physicalSize = const Size(1170, 4200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          petLocalStoreProvider.overrideWithValue(store),
          petRepositoryProvider.overrideWithValue(pets),
          currentUserProvider.overrideWithValue(brunoNamed),
          textSharerProvider.overrideWithValue(sharer),
          syncServiceProvider.overrideWithValue(
            PetSyncService(
              store: store,
              remote: remote,
              isSignedIn: () => true,
              network: FakeNetwork(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: PetPage(petId: bowie.id),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Convidar por email'),
      'ana@example.com',
    );
    await tester.tap(find.text('Convidar'));
    await settle();
    expect(find.text('Convite enviado'), findsOneWidget);
    expect(remote.invitesSent, hasLength(1));

    await tester.tap(find.text('Enviar pelo WhatsApp'));
    await settle();
    expect(sharer.shared, hasLength(1));
    expect(sharer.shared.single, contains('Bruno convidou você'));
    expect(sharer.shared.single, contains('ana@example.com'));

    // Later, from the pending invitation's menu.
    await tester.tap(find.byTooltip('Opções para ana@example.com'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar pelo WhatsApp'));
    await settle();
    expect(sharer.shared, hasLength(2));
  });
}
