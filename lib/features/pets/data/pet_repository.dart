import 'package:uuid/uuid.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

/// What a person fills in on the pet form.
class PetProfile {
  const PetProfile({
    required this.name,
    required this.species,
    required this.birthDate,
    this.breed,
    this.birthDateEstimated = false,
    this.weightKg,
  });

  final String name;
  final PetSpecies? species;
  final String? breed;
  final DateTime? birthDate;
  final bool birthDateEstimated;
  final double? weightKg;
}

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

  Future<Pet> createPet({
    required PetProfile profile,
    required AppUser owner,
  }) async {
    final timestamp = _timestamp;
    final pet = _apply(
      Pet(id: _ids.v4(), name: '', updatedAt: timestamp),
      profile,
      timestamp,
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

  /// Any accepted tutor can edit the pet's profile.
  Future<void> updatePet({
    required String petId,
    required PetProfile profile,
    required AppUser byUser,
  }) async {
    final details = await _requireMember(petId, byUser);
    await _store.savePet(_apply(details.pet, profile, _timestamp));
  }

  /// Any accepted tutor can update the weight, as from a vaccine card.
  Future<void> updateWeight({
    required String petId,
    required double weightKg,
    required AppUser byUser,
  }) async {
    if (weightKg <= 0 || weightKg > 150) {
      throw const AppFailure('Informe um peso entre 0,1 e 150 kg.');
    }
    final details = await _requireMember(petId, byUser);
    await _store.savePet(
      details.pet.copyWith(
        weightKg: (weightKg * 10).round() / 10,
        updatedAt: _timestamp,
      ),
    );
  }

  /// Only the main tutor can delete a pet. The row is kept with [Pet.deletedAt]
  /// set, so the deletion syncs to the other tutors.
  Future<void> deletePet({
    required String petId,
    required AppUser byUser,
  }) async {
    final details = await _requireOwner(
      petId,
      byUser,
      message: 'Só o tutor principal pode excluir o pet.',
    );
    final timestamp = _timestamp;
    await _store.savePet(
      details.pet.copyWith(deletedAt: timestamp, updatedAt: timestamp),
    );
  }

  Pet _apply(Pet pet, PetProfile profile, DateTime timestamp) {
    final species = profile.species;
    if (species == null) {
      throw const AppFailure('Escolha se é cão ou gato.');
    }
    final birthDate = profile.birthDate;
    if (birthDate == null) {
      throw const AppFailure(
        'Informe a data de nascimento ou a idade aproximada.',
      );
    }
    final today = _now();
    final day = DateTime(birthDate.year, birthDate.month, birthDate.day);
    if (day.isAfter(DateTime(today.year, today.month, today.day))) {
      throw const AppFailure('A data de nascimento não pode estar no futuro.');
    }
    if (today.year - day.year > 40) {
      throw const AppFailure('Confira a data de nascimento.');
    }
    final breed = profile.breed?.trim() ?? '';
    if (breed.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres na raça.');
    }
    final weight = profile.weightKg;
    if (weight != null && (weight <= 0 || weight > 150)) {
      throw const AppFailure('Informe um peso entre 0,1 e 150 kg.');
    }
    return pet.copyWith(
      name: _validatedName(profile.name),
      species: species,
      breed: breed.isEmpty ? null : breed,
      clearBreed: breed.isEmpty,
      birthDate: day,
      birthDateEstimated: profile.birthDateEstimated,
      weightKg: weight == null ? null : (weight * 10).round() / 10,
      clearWeight: weight == null,
      updatedAt: timestamp,
    );
  }

  Future<void> inviteTutor({
    required String petId,
    required String email,
    required AppUser byUser,
  }) async {
    final normalized = normalizeEmail(email);
    if (!emailLooksValid(normalized)) {
      throw const AppFailure('Digite um email válido.');
    }
    if (normalized == normalizeEmail(byUser.email)) {
      throw const AppFailure('Você já cuida deste pet.');
    }
    final details = await _requireOwner(petId, byUser);
    final alreadyThere = details.tutors.any(
      (tutor) => tutor.email == normalized && tutor.deletedAt == null,
    );
    if (alreadyThere) {
      throw const AppFailure('Essa pessoa já faz parte deste pet.');
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
      throw const AppFailure('Este convite não está mais disponível.');
    }
    if (tutor.email != normalizeEmail(user.email)) {
      throw const AppFailure('Este convite foi enviado para outro email.');
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
      throw const AppFailure('Você não pode alterar este pet.');
    }
    return details;
  }

  Future<PetDetails> _requireOwner(
    String petId,
    AppUser user, {
    String message = 'Só o tutor principal pode convidar pessoas.',
  }) async {
    final details = await _requireMember(petId, user);
    final owner = details.tutors.any(
      (tutor) =>
          tutor.role == PetRole.owner &&
          tutor.status == TutorStatus.accepted &&
          tutor.email == normalizeEmail(user.email) &&
          tutor.deletedAt == null,
    );
    if (!owner) {
      throw AppFailure(message);
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
      throw const AppFailure('Digite um nome.');
    }
    if (trimmed.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no nome.');
    }
    return trimmed;
  }

  DateTime get _timestamp => _now().toUtc();
}
