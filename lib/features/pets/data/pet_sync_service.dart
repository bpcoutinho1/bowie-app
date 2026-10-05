import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/sync/network_status.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
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
  });

  final PetLocalStore store;
  final PetRemoteApi? remote;
  final bool Function() isSignedIn;
  final NetworkStatus network;

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

  /// Pushes pets before tutor rows so the server sees the pet first.
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

  Future<void> _pull(PetRemoteApi remote) async {
    final pets = await remote.pullPets();
    final tutors = await remote.pullTutors();
    await store.applyRemote(pets: pets, tutors: tutors);
  }

  int _rank(String entity) {
    return switch (entity) {
      'pets' => 0,
      'pet_tutors' => 1,
      _ => 2,
    };
  }
}
