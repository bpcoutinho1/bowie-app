import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/contacts/data/contacts_repository.dart';
import 'package:bowie/features/contacts/domain/contact.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.watch(petLocalStoreProvider));
});

final contactsProvider = FutureProvider.autoDispose
    .family<List<Contact>, String>((ref, houseId) async {
      final repository = ref.watch(contactsRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.list(houseId);
    });

/// The contacts of the house a pet belongs to, for the diary form.
final petContactsProvider = FutureProvider.autoDispose
    .family<List<Contact>, String>((ref, petId) async {
      final repository = ref.watch(contactsRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.listForPet(petId);
    });

final contactProvider = FutureProvider.autoDispose.family<Contact?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(contactsRepositoryProvider);
  final changes = repository.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  return repository.get(id);
});
