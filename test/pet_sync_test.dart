import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

import 'support/fakes.dart';

void main() {
  const owner = AppUser(id: 'owner-1', email: 'owner@example.com');
  const sam = AppUser(id: 'sam-1', email: 'sam@example.com');

  late PetLocalStore store;
  late PetRepository repo;

  setUp(() async {
    store = await PetLocalStore.open(databasePath: inMemoryDatabasePath);
    repo = PetRepository(store, now: () => DateTime.utc(2026, 9, 30));
  });

  tearDown(() => store.close());

  test('creating a pet keeps the owner attached after a rename', () async {
    final pet = await repo.createPet(name: '  Luna  ', owner: owner);
    expect(pet.name, 'Luna');
    expect((await repo.listPetsFor(owner.email)).single.name, 'Luna');

    await repo.renamePet(petId: pet.id, name: 'Luna 2', byUser: owner);
    final details = await repo.getDetails(pet.id);
    expect(details!.pet.name, 'Luna 2');
    expect(details.tutors.single.role, PetRole.owner);
  });

  test('blank names are rejected', () async {
    expect(
      () => repo.createPet(name: '   ', owner: owner),
      throwsA(isA<AppFailure>()),
    );
  });

  test('the owner can invite a tutor who can then accept', () async {
    final pet = await repo.createPet(name: 'Luna', owner: owner);
    await repo.inviteTutor(
      petId: pet.id,
      email: 'Sam@Example.com',
      byUser: owner,
    );

    final invites = await repo.listInvites('sam@example.com');
    expect(invites.single.petName, 'Luna');
    expect(invites.single.tutor.status, TutorStatus.pending);

    await repo.acceptInvite(tutorId: invites.single.tutor.id, user: sam);
    expect((await repo.listPetsFor(sam.email)).single.id, pet.id);
    expect((await repo.listInvites(sam.email)), isEmpty);
  });

  test('only the owner can invite', () async {
    final pet = await repo.createPet(name: 'Luna', owner: owner);
    expect(
      () => repo.inviteTutor(
        petId: pet.id,
        email: 'new@example.com',
        byUser: sam,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => repo.inviteTutor(petId: pet.id, email: owner.email, byUser: owner),
      throwsA(isA<AppFailure>()),
    );
  });

  test('a pending local edit is not replaced by a remote copy', () async {
    final pet = await repo.createPet(name: 'Luna', owner: owner);
    await store.applyRemote(
      pets: [
        pet.copyWith(name: 'Remote', updatedAt: DateTime.utc(2026, 10, 1)),
      ],
      tutors: const [],
    );
    expect((await repo.getDetails(pet.id))!.pet.name, 'Luna');

    final queued = await store.pending();
    for (final item in queued) {
      await store.removePendingIfUnchanged(item.id, item.payloadJson);
    }
    await store.applyRemote(
      pets: [
        pet.copyWith(name: 'Remote', updatedAt: DateTime.utc(2026, 10, 1)),
      ],
      tutors: const [],
    );
    expect((await repo.getDetails(pet.id))!.pet.name, 'Remote');
  });

  test('offline creates sync pets before tutors once online', () async {
    final network = FakeNetwork(online: false);
    final remote = FakeRemote();
    final sync = PetSyncService(
      store: store,
      remote: remote,
      isSignedIn: () => true,
      network: network,
    );

    final pet = await repo.createPet(name: 'Luna', owner: owner);
    expect(await sync.sync(), isA<SyncWaiting>());
    expect(remote.calls, isEmpty);
    expect(await store.pending(), hasLength(2));

    network.online = true;
    expect(await sync.sync(), isA<SyncOk>());
    expect(remote.calls, ['pets', 'pet_tutors']);
    expect(remote.pets.single.id, pet.id);
    expect(remote.tutors.single.role, PetRole.owner);
    expect(await store.pending(), isEmpty);

    remote.pets[0] = remote.pets.single.copyWith(
      name: 'From server',
      updatedAt: DateTime.utc(2026, 10, 2),
    );
    expect(await sync.sync(), isA<SyncOk>());
    expect((await repo.getDetails(pet.id))!.pet.name, 'From server');
  });
}
