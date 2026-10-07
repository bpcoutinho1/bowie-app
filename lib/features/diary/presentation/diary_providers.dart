import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository(
    ref.watch(petLocalStoreProvider),
    photos: ref.watch(petPhotoStoreProvider),
  );
});

final petEventsProvider = FutureProvider.autoDispose
    .family<List<PetEvent>, String>((ref, petId) async {
      final repository = ref.watch(diaryRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.listEvents(petId);
    });

final petEventProvider = FutureProvider.autoDispose.family<PetEvent?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(diaryRepositoryProvider);
  final changes = repository.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  return repository.getEvent(id);
});

/// The day picked on the diary calendar, while the app is open.
final diaryDayProvider = NotifierProvider<DiaryDay, DateTime?>(DiaryDay.new);

class DiaryDay extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime day) => state = day;
}
