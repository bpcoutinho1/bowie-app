import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/shopping/data/last_house.dart';
import 'package:bowie/features/shopping/data/shopping_repository.dart';
import 'package:bowie/features/shopping/domain/shopping_item.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>((ref) {
  return ShoppingRepository(ref.watch(petLocalStoreProvider));
});

final lastHouseProvider = Provider<LastHouse>((ref) => PrefsLastHouse());

final housesProvider = FutureProvider.autoDispose<List<House>>((ref) async {
  final repository = ref.watch(shoppingRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final changes = repository.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  if (user == null) return const [];
  return repository.listHouses(user);
});

/// The house chosen in the selector, while the app is open.
final chosenHouseProvider = NotifierProvider<ChosenHouse, String?>(
  ChosenHouse.new,
);

class ChosenHouse extends Notifier<String?> {
  @override
  String? build() => null;

  void choose(String houseId) {
    state = houseId;
    ref.read(lastHouseProvider).write(houseId);
  }
}

/// The house the screen shows: the one chosen, else the person's own, else
/// the last one used on this phone, else the first.
final currentHouseProvider = FutureProvider.autoDispose<House?>((ref) async {
  final chosen = ref.watch(chosenHouseProvider);
  final houses = await ref.watch(housesProvider.future);
  if (houses.isEmpty) return null;
  House? byId(String? id) => houses.where((h) => h.id == id).firstOrNull;
  return byId(chosen) ??
      houses.where((h) => h.isMine).firstOrNull ??
      byId(await ref.read(lastHouseProvider).read()) ??
      houses.first;
});

final shoppingListProvider = FutureProvider.autoDispose
    .family<ShoppingList, String>((ref, houseId) async {
      final repository = ref.watch(shoppingRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.listItems(houseId);
    });
