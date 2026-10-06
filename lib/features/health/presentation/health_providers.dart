import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/health/data/card_reader.dart';
import 'package:bowie/features/health/data/medication_repository.dart';
import 'package:bowie/features/health/domain/medication.dart';
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

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  return MedicationRepository(ref.watch(petLocalStoreProvider));
});

final medicationsProvider = FutureProvider.autoDispose
    .family<List<Medication>, String>((ref, petId) async {
      final repository = ref.watch(medicationRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.listMedications(petId);
    });

final medicationProvider = FutureProvider.autoDispose
    .family<Medication?, String>((ref, id) async {
      final repository = ref.watch(medicationRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.getMedication(id);
    });

/// Today's doses of a pet, with who gave each one.
final todayDosesProvider = FutureProvider.autoDispose
    .family<List<DoseSlot>, String>((ref, petId) async {
      final repository = ref.watch(medicationRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.dosesOnDay(petId, repository.today);
    });
