import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';

/// The profile's "Peso atual" follows the most recent weighing in the diary
/// (docs/produto/diario.md#peso). Nothing changes while there is none.
Future<void> applyLatestWeight({
  required DiaryRepository diary,
  required PetRepository pets,
  required String petId,
  required AppUser byUser,
}) async {
  final latest = await diary.latestWeight(petId);
  if (latest == null) return;
  final pet = (await pets.getDetails(petId))?.pet;
  if (pet == null || pet.weightKg == latest.kg) return;
  await pets.updateWeight(petId: petId, weightKg: latest.kg, byUser: byUser);
}
