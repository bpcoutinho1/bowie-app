import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/health/data/card_reader.dart';
import 'package:bowie/features/health/data/reading_consent.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';

/// The pet shown in Início and Saúde when there is more than one.
final selectedPetIdProvider = NotifierProvider<SelectedPet, String?>(
  SelectedPet.new,
);

class SelectedPet extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String petId) => state = petId;
}

final vaccineGroupsProvider = FutureProvider.autoDispose
    .family<List<VaccineGroup>, String>((ref, petId) async {
      final repository = ref.watch(healthRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.listGroups(petId);
    });

final doseProvider = FutureProvider.autoDispose.family<VaccineDose?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(healthRepositoryProvider);
  final changes = repository.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  return repository.getDose(id);
});

/// Null when the app has no server configured.
final cardReaderProvider = Provider<CardReader?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseCardReader(client);
});

final readingConsentProvider = Provider<ReadingConsent>(
  (ref) => PrefsReadingConsent(),
);
