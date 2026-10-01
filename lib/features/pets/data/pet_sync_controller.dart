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
  });

  final bool syncing;
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
      state = SyncStatus(syncing: true, lastSyncedAt: previous.lastSyncedAt);
    }
    final result = await ref.read(syncServiceProvider).sync();
    if (!ref.mounted || previous.syncing) return;
    state = switch (result) {
      SyncOk() => SyncStatus(lastSyncedAt: DateTime.now().toUtc()),
      SyncSkipped() => SyncStatus(lastSyncedAt: previous.lastSyncedAt),
      SyncWaiting(:final message) => SyncStatus(
        lastSyncedAt: previous.lastSyncedAt,
        message: message,
      ),
      SyncFailed(:final message) => SyncStatus(
        lastSyncedAt: previous.lastSyncedAt,
        message: message,
        failed: true,
      ),
    };
  }
}
