import 'package:uuid/uuid.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

class PetDetails {
  const PetDetails({required this.pet, required this.tutors});

  final Pet pet;
  final List<PetTutor> tutors;
}

class PetRepository {
  PetRepository(this._store, {Uuid? ids, DateTime Function()? now})
    : _ids = ids ?? const Uuid(),
      _now = now ?? DateTime.now;

  final PetLocalStore _store;
  final Uuid _ids;
  final DateTime Function() _now;

  Stream<ChangeReason> get changes => _store.changes;

  Future<List<Pet>> listPetsFor(String email) {
    return _store.listPetsFor(normalizeEmail(email));
  }

  Future<List<TutorInvite>> listInvites(String email) {
    return _store.listInvites(normalizeEmail(email));
  }

  Future<PetDetails?> getDetails(String petId) async {
    final pet = await _store.getPet(petId);
    if (pet == null) return null;
    final tutors = await _store.listTutors(petId);
    return PetDetails(pet: pet, tutors: tutors);
  }

  Future<Pet> createPet({required String name, required AppUser owner}) async {
    final timestamp = _timestamp;
    final pet = Pet(
      id: _ids.v4(),
      name: _validatedName(name),
      updatedAt: timestamp,
    );
    final membership = PetTutor(
      id: _ids.v4(),
      petId: pet.id,
      userId: owner.id,
      email: normalizeEmail(owner.email),
      role: PetRole.owner,
      status: TutorStatus.accepted,
      updatedAt: timestamp,
    );
    await _store.saveNewPet(pet, membership);
    return pet;
  }

  Future<void> renamePet({
    required String petId,
    required String name,
    required AppUser byUser,
  }) async {
    final details = await _requireMember(petId, byUser);
    final renamed = details.pet.copyWith(
      name: _validatedName(name),
      updatedAt: _timestamp,
    );
    await _store.savePet(renamed);
  }

  Future<void> inviteTutor({
    required String petId,
    required String email,
    required AppUser byUser,
  }) async {
    final normalized = normalizeEmail(email);
    if (!emailLooksValid(normalized)) {
      throw const AppFailure('Enter a valid email.');
    }
    if (normalized == normalizeEmail(byUser.email)) {
      throw const AppFailure('You already care for this pet.');
    }
    final details = await _requireOwner(petId, byUser);
    final alreadyThere = details.tutors.any(
      (tutor) => tutor.email == normalized && tutor.deletedAt == null,
    );
    if (alreadyThere) {
      throw const AppFailure('That person is already on this pet.');
    }
    final tutor = PetTutor(
      id: _ids.v4(),
      petId: petId,
      userId: null,
      email: normalized,
      role: PetRole.tutor,
      status: TutorStatus.pending,
      updatedAt: _timestamp,
    );
    await _store.saveTutor(tutor);
  }

  Future<void> acceptInvite({
    required String tutorId,
    required AppUser user,
  }) async {
    final tutor = await _store.getTutor(tutorId);
    if (tutor == null || tutor.deletedAt != null) {
      throw const AppFailure('This invitation is no longer on this device.');
    }
    if (tutor.email != normalizeEmail(user.email)) {
      throw const AppFailure('This invitation was sent to a different email.');
    }
    if (tutor.status == TutorStatus.accepted) return;
    await _store.saveTutor(
      tutor.copyWith(
        userId: user.id,
        status: TutorStatus.accepted,
        updatedAt: _timestamp,
      ),
    );
  }

  Future<PetDetails> _requireMember(String petId, AppUser user) async {
    final details = await getDetails(petId);
    if (details == null || !_isAccepted(details, user)) {
      throw const AppFailure('You cannot change this pet.');
    }
    return details;
  }

  Future<PetDetails> _requireOwner(String petId, AppUser user) async {
    final details = await _requireMember(petId, user);
    final owner = details.tutors.any(
      (tutor) =>
          tutor.role == PetRole.owner &&
          tutor.status == TutorStatus.accepted &&
          tutor.email == normalizeEmail(user.email) &&
          tutor.deletedAt == null,
    );
    if (!owner) {
      throw const AppFailure('Only the owner can invite someone.');
    }
    return details;
  }

  bool _isAccepted(PetDetails details, AppUser user) {
    final email = normalizeEmail(user.email);
    return details.tutors.any(
      (tutor) =>
          tutor.email == email &&
          tutor.status == TutorStatus.accepted &&
          tutor.deletedAt == null,
    );
  }

  String _validatedName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AppFailure('Enter a name.');
    }
    if (trimmed.length > 80) {
      throw const AppFailure('Keep the name under 80 characters.');
    }
    return trimmed;
  }

  DateTime get _timestamp => _now().toUtc();
}
