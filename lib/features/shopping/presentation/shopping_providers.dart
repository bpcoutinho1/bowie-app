import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/shopping/data/shopping_repository.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(ref.watch(petLocalStoreProvider));
});

final shoppingListProvider = FutureProvider.autoDispose
    .family<ShoppingList, String>((ref, houseId) async {
      final repository = ref.watch(shoppingRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.listItems(houseId);
    });
