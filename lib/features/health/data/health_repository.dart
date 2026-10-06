import 'package:uuid/uuid.dart';

import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

/// What a person fills in on the dose form.
class DoseInput {
  const DoseInput({
    required this.petId,
    required this.kind,
    required this.name,
    required this.appliedOn,
    required this.nextDueOn,
    this.product,
    this.lot,
    this.veterinarian,
    this.notes,
  });

  final String petId;
  final DoseKind kind;
  final String name;
  final DateTime? appliedOn;
  final DateTime? nextDueOn;
  final String? product;
  final String? lot;
  final String? veterinarian;
  final String? notes;
}

class HealthRepository {
  HealthRepository(this._store, {Uuid? ids, DateTime Function()? now})
    : _ids = ids ?? const Uuid(),
      _now = now ?? DateTime.now;

  final PetLocalStore _store;
  final Uuid _ids;
  final DateTime Function() _now;

  Stream<ChangeReason> get changes => _store.changes;

  DateTime get today => dayOf(_now());

  /// Every dose of the pet, including older ones.
  Future<List<VaccineDose>> listDoses(String petId) => _store.listDoses(petId);

  Future<List<VaccineGroup>> listGroups(String petId) async {
    return groupDoses(await _store.listDoses(petId), today);
  }

  Future<VaccineDose?> getDose(String id) => _store.getDose(id);

  /// Creates a dose, or edits it when [id] is given. Any accepted tutor can.
  Future<VaccineDose> saveDose({
    String? id,
    required DoseInput input,
    required AppUser byUser,
  }) async {
    await _requireMember(input.petId, byUser);
    final dose = _build(id, input, byUser);
    await _store.saveDose(dose);
    return dose;
  }

  /// Creates several doses at once, as from a card reading. Nothing is saved
  /// unless every dose is valid.
  Future<List<VaccineDose>> saveDoses({
    required List<DoseInput> inputs,
    required AppUser byUser,
  }) async {
    for (final petId in {for (final input in inputs) input.petId}) {
      await _requireMember(petId, byUser);
    }
    final doses = [for (final input in inputs) _build(null, input, byUser)];
    for (final dose in doses) {
      await _store.saveDose(dose);
    }
    return doses;
  }

  VaccineDose _build(String? id, DoseInput input, AppUser byUser) {
    final name = input.name.trim();
    if (name.isEmpty) throw const AppFailure('Digite o nome da vacina.');
    if (name.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no nome.');
    }
    final applied = input.appliedOn;
    final due = input.nextDueOn;
    if (applied == null) {
      throw const AppFailure('Informe a data da aplicação.');
    }
    if (due == null) {
      throw const AppFailure('Informe quando é a próxima dose.');
    }
    if (dayOf(applied).isAfter(today)) {
      throw const AppFailure('A data da aplicação não pode estar no futuro.');
    }
    if (!dayOf(due).isAfter(dayOf(applied))) {
      throw const AppFailure(
        'A próxima dose precisa ser depois da data da aplicação.',
      );
    }

    return VaccineDose(
      id: id ?? _ids.v4(),
      petId: input.petId,
      kind: input.kind,
      name: name,
      appliedOn: dayOf(applied),
      nextDueOn: dayOf(due),
      product: _optional(input.product, 'o produto'),
      lot: _optional(input.lot, 'o lote'),
      veterinarian: _optional(input.veterinarian, 'o veterinário'),
      notes: _optional(input.notes, 'as observações', max: 500),
      updatedBy: byUser.id,
      updatedAt: _now().toUtc(),
    );
  }

  /// Any accepted tutor can delete a record. The row keeps who did it.
  Future<void> deleteDose({required String id, required AppUser byUser}) async {
    final dose = await _store.getDose(id);
    if (dose == null) {
      throw const AppFailure('Este registro não está mais disponível.');
    }
    await _requireMember(dose.petId, byUser);
    final now = _now().toUtc();
    await _store.saveDose(
      dose.copyWith(deletedAt: now, updatedAt: now, updatedBy: byUser.id),
    );
  }

  Future<void> _requireMember(String petId, AppUser user) async {
    final pet = await _store.getPet(petId);
    final email = normalizeEmail(user.email);
    final tutors = pet == null
        ? const <PetTutor>[]
        : await _store.listTutors(petId);
    final member = tutors.any(
      (tutor) =>
          tutor.email == email &&
          tutor.status == TutorStatus.accepted &&
          tutor.deletedAt == null,
    );
    if (!member) {
      throw const AppFailure('Você não pode alterar a saúde deste pet.');
    }
  }

  String? _optional(String? value, String what, {int max = 120}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > max) {
      throw AppFailure('Use no máximo $max caracteres para $what.');
    }
    return text;
  }
}
