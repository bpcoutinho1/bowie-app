import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';

class SyncStatus {
  const SyncStatus({
    this.syncing = false,
    this.lastSyncedAt,
    this.message,
    this.failed = false,
    this.checkedFor,
  });

  final bool syncing;

  /// The account a sync last finished for, in any way. Until it is the one
  /// signed in, an empty phone may just not have its pets from the server
  /// yet.
  final String? checkedFor;
  final DateTime? lastSyncedAt;
  final String? message;
  final bool failed;
}

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

class SyncController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() {
    final store = ref.watch(petLocalStoreProvider);
    final changes = store.changes.listen((reason) {
      if (reason == ChangeReason.local) {
        unawaited(sync());
      }
    });
    ref.onDispose(changes.cancel);

    final network = ref.watch(networkStatusProvider);
    final connectivity = network.onStatusChanged.listen((_) {
      unawaited(sync());
    });
    ref.onDispose(connectivity.cancel);

    return const SyncStatus();
  }

  Future<void> sync() async {
    final previous = state;
    if (!previous.syncing) {
      state = SyncStatus(
        syncing: true,
        lastSyncedAt: previous.lastSyncedAt,
        checkedFor: previous.checkedFor,
      );
    }
    final userId = ref.read(currentUserProvider)?.id;
    final result = await ref.read(syncServiceProvider).sync();
    if (!ref.mounted || previous.syncing) return;
    state = switch (result) {
      SyncOk() => SyncStatus(
        lastSyncedAt: DateTime.now().toUtc(),
        checkedFor: userId,
      ),
      SyncSkipped() => SyncStatus(
        lastSyncedAt: previous.lastSyncedAt,
        checkedFor: userId,
      ),
      SyncWaiting(:final message) => SyncStatus(
        lastSyncedAt: previous.lastSyncedAt,
        message: message,
        checkedFor: userId,
      ),
      SyncFailed(:final message) => SyncStatus(
        lastSyncedAt: previous.lastSyncedAt,
        message: message,
        failed: true,
        checkedFor: userId,
      ),
    };
  }
}
