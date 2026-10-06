import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/core/config/app_config.dart';
import 'package:bowie/core/sync/network_status.dart';
import 'package:bowie/features/auth/data/auth_repository.dart';
import 'package:bowie/features/auth/data/device_lock.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_remote_api.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/data/pet_sync_service.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

final petLocalStoreProvider = Provider<PetLocalStore>((ref) {
  throw StateError('PetLocalStore is opened in main.');
});

final networkStatusProvider = Provider<NetworkStatus>(
  (ref) => PluginNetworkStatus(),
);

final deviceLockProvider = Provider<DeviceLock>((ref) => DeviceLock());

final unlockedProvider = NotifierProvider<UnlockedController, bool>(
  UnlockedController.new,
);

class UnlockedController extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;

  void lock() => state = false;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authSessionProvider = StreamProvider<AppUser?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    yield null;
    return;
  }
  yield userFromSession(client.auth.currentSession);
  await for (final change in client.auth.onAuthStateChange) {
    yield userFromSession(change.session);
  }
});

AppUser? userFromSession(Session? session) {
  final user = session?.user;
  final email = user?.email;
  if (user == null || email == null || email.isEmpty) return null;
  return AppUser(id: user.id, email: normalizeEmail(email));
}

final deviceSupportedProvider = FutureProvider<bool>((ref) {
  return ref.watch(deviceLockProvider).isSupported();
});

enum AuthGate { loading, signedOut, locked, ready }

final authGateProvider = Provider<AuthGate>((ref) {
  final session = ref.watch(authSessionProvider);
  final supported = ref.watch(deviceSupportedProvider);
  final unlocked = ref.watch(unlockedProvider);
  if (session.isLoading || supported.isLoading) return AuthGate.loading;
  final user = session.asData?.value;
  if (user == null) return AuthGate.signedOut;
  final deviceReady = supported.asData?.value ?? false;
  if (deviceReady && !unlocked) return AuthGate.locked;
  return AuthGate.ready;
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authSessionProvider).asData?.value;
});

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository(ref.watch(petLocalStoreProvider));
});

final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository(ref.watch(petLocalStoreProvider));
});

final petRemoteApiProvider = Provider<PetRemoteApi?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabasePetApi(client);
});

final syncServiceProvider = Provider<PetSyncService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PetSyncService(
    store: ref.watch(petLocalStoreProvider),
    remote: ref.watch(petRemoteApiProvider),
    isSignedIn: () => client?.auth.currentSession != null,
    network: ref.watch(networkStatusProvider),
  );
});
