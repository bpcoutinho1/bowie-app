import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/notifications/domain/vaccine_notice.dart';
import 'package:bowie/features/pets/presentation/pets_page.dart';

/// Kept on the phone when the person taps "Não lembrar mais" for a pet.
String vaccineNoticeOffKey(String petId) => 'vaccine_notice_off_$petId';

/// The pets that still miss essential vaccines, 7 days after they were
/// registered. Shown in the bell, newest pet last.
final vaccineNoticesProvider = FutureProvider.autoDispose<List<VaccineNotice>>((
  ref,
) async {
  final health = ref.watch(healthRepositoryProvider);
  final flags = ref.watch(flagsProvider);
  final changes = health.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  final pets = (await ref.watch(petsHomeProvider.future)).pets;
  return [
    for (final pet in pets)
      if (!await flags.isSet(vaccineNoticeOffKey(pet.id)))
        ?vaccineNotice(pet, await health.listDoses(pet.id), health.today),
  ];
});
