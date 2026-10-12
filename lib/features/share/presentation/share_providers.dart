import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/share/data/pet_share_repository.dart';
import 'package:bowie/features/share/domain/pet_share.dart';

final petShareRepositoryProvider = Provider<PetShareRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PetShareRepository(
    ref.watch(petLocalStoreProvider),
    client == null ? null : SupabasePetShareApi(client),
  );
});

/// The links of a pet that still work. Read from the server each time.
final activeSharesProvider = FutureProvider.autoDispose
    .family<List<PetShare>, String>((ref, petId) {
      return ref.watch(petShareRepositoryProvider).activeShares(petId);
    });
