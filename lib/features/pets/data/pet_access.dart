import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

/// Throws [message] unless [user] is an accepted tutor of [petId].
Future<void> requirePetMember(
  PetLocalStore store,
  String petId,
  AppUser user, {
  String message = 'Você não pode alterar a saúde deste pet.',
}) async {
  final pet = await store.getPet(petId);
  final email = normalizeEmail(user.email);
  final tutors = pet == null
      ? const <PetTutor>[]
      : await store.listTutors(petId);
  final member = tutors.any(
    (tutor) =>
        tutor.email == email &&
        tutor.status == TutorStatus.accepted &&
        tutor.deletedAt == null,
  );
  if (!member) throw AppFailure(message);
}
