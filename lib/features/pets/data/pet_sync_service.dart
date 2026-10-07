import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/sync/network_status.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_photo_store.dart';
import 'package:bowie/features/pets/data/pet_remote_api.dart';

sealed class SyncResult {
  const SyncResult();
}

class SyncOk extends SyncResult {
  const SyncOk();
}

class SyncSkipped extends SyncResult {
  const SyncSkipped();
}

class SyncWaiting extends SyncResult {
  const SyncWaiting(this.message);

  final String message;
}

class SyncFailed extends SyncResult {
  const SyncFailed(this.message);

  final String message;
}

class PetSyncService {
  PetSyncService({
    required this.store,
    required this.remote,
    required this.isSignedIn,
    required this.network,
    this.photos,
  });

  final PetLocalStore store;
  final PetRemoteApi? remote;
  final bool Function() isSignedIn;
  final NetworkStatus network;
  final PetPhotoStore? photos;

  Future<SyncResult>? _flight;
  var _rerun = false;

  Future<SyncResult> sync() {
    final existing = _flight;
    if (existing != null) {
      _rerun = true;
      return existing;
    }
    final flight = _execute();
    _flight = flight;
    return flight;
  }

  Future<SyncResult> _execute() async {
    try {
      SyncResult result = const SyncSkipped();
      do {
        _rerun = false;
        result = await _once();
        if (result is! SyncOk) break;
      } while (_rerun);
      return result;
    } finally {
      _flight = null;
    }
  }

  Future<SyncResult> _once() async {
    final api = remote;
    if (api == null || !isSignedIn()) return const SyncSkipped();
    if (!await network.isOnline) {
      final pending = await store.pending();
      if (pending.isEmpty) {
        return const SyncWaiting(
          'Você está sem internet. Mostrando o que está salvo no celular.',
        );
      }
      return const SyncWaiting(
        'Salvo no celular. Sincroniza quando a internet voltar.',
      );
    }

    try {
      final pushed = await _push(api);
      if (pushed != null) return pushed;
      await _pull(api);
      return const SyncOk();
    } on AppFailure catch (error) {
      if (error.retryable) return SyncWaiting(error.message);
      return SyncFailed(error.message);
    }
  }

  /// Makes [tutorId] the main tutor of [petId]. Needs the internet: pending
  /// changes go up first, the server swaps the roles, and the result comes
  /// back down.
  Future<void> transferPet({
    required String petId,
    required String tutorId,
  }) async {
    final api = remote;
    if (api == null || !isSignedIn()) {
      throw const AppFailure('Este app ainda não está conectado ao servidor.');
    }
    if (!await network.isOnline) {
      throw const AppFailure('Para transferir o pet, conecte-se à internet.');
    }
    final before = await sync();
    if (before is SyncWaiting) throw AppFailure(before.message);
    if (before is SyncFailed) throw AppFailure(before.message);
    await api.transferPet(petId: petId, tutorId: tutorId);
    await sync();
  }

  /// Pushes pets, then tutor rows, then photos, doses, shopping items,
  /// contacts and diary entries, so the server always knows what a row
  /// depends on (the pet, the person's membership, the contact) first.
  Future<SyncResult?> _push(PetRemoteApi remote) async {
    final pending = await store.pending();
    pending.sort((a, b) {
      final rank = _rank(a.entity).compareTo(_rank(b.entity));
      if (rank != 0) return rank;
      final created = a.createdAt.compareTo(b.createdAt);
      if (created != 0) return created;
      return a.id.compareTo(b.id);
    });

    for (final item in pending) {
      try {
        switch (item.entity) {
          case 'pets':
            await remote.upsertPet(item.payload);
          case 'pet_tutors':
            await remote.upsertTutor(item.payload);
          case 'pet_vaccines':
            await remote.upsertDose(item.payload);
          case 'shopping_items':
            await remote.upsertShoppingItem(item.payload);
          case 'house_contacts':
            await remote.upsertContact(item.payload);
          case 'pet_events':
            await remote.upsertEvent(item.payload);
          case 'pet_medications':
            await remote.upsertMedication(item.payload);
          case 'pet_medication_doses':
            await remote.upsertMedDose(item.payload);
          case photoEntity:
            await _pushPhoto(remote, item);
          default:
            return SyncFailed('Alteração desconhecida: ${item.entity}.');
        }
        await store.removePendingIfUnchanged(item.id, item.payloadJson);
      } on AppFailure catch (error) {
        if (error.retryable) return SyncWaiting(error.message);
        return SyncFailed(error.message);
      }
    }
    return null;
  }

  Future<void> _pushPhoto(PetRemoteApi remote, OutboxItem item) async {
    if (item.payload['op'] == 'remove') {
      await remote.removePhoto(item.entityId);
      return;
    }
    // A photo replaced before it went up is no longer on the phone: skip it.
    final photo = await photos?.read(item.entityId);
    if (photo != null) await remote.uploadPhoto(item.entityId, photo);
  }

  Future<void> _pull(PetRemoteApi remote) async {
    final pets = await remote.pullPets();
    final tutors = await remote.pullTutors();
    final doses = await remote.pullDoses();
    final shopping = await remote.pullShoppingItems();
    final contacts = await remote.pullContacts();
    final events = await remote.pullEvents();
    final medications = await remote.pullMedications();
    final medDoses = await remote.pullMedDoses();
    await store.applyRemote(
      medications: medications,
      medDoses: medDoses,
      pets: pets,
      tutors: tutors,
      doses: doses,
      shopping: shopping,
      contacts: contacts,
      events: events,
    );
  }

  int _rank(String entity) {
    return switch (entity) {
      'pets' => 0,
      'pet_tutors' => 1,
      photoEntity => 2,
      'pet_vaccines' => 3,
      'shopping_items' => 4,
      // Contacts before the diary entries that point to them.
      'house_contacts' => 5,
      'pet_events' => 6,
      // Medications before the dose marks that point to them.
      'pet_medications' => 7,
      'pet_medication_doses' => 8,
      _ => 9,
    };
  }
}
