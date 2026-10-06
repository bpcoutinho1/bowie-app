import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/houses/houses.dart';
import 'package:bowie/features/houses/last_house.dart';

final housesDirectoryProvider = Provider<Houses>(
  (ref) => Houses(ref.watch(petLocalStoreProvider)),
);

final lastHouseProvider = Provider<LastHouse>((ref) => PrefsLastHouse());

final housesProvider = FutureProvider.autoDispose<List<House>>((ref) async {
  final store = ref.watch(petLocalStoreProvider);
  final user = ref.watch(currentUserProvider);
  final changes = store.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  if (user == null) return const [];
  return ref.watch(housesDirectoryProvider).list(user);
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
