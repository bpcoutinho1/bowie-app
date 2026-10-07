import 'package:uuid/uuid.dart';

import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/health/domain/medication.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

/// What a person fills in on the medication form.
class MedicationInput {
  const MedicationInput({
    required this.petId,
    required this.name,
    required this.amount,
    required this.unit,
    required this.frequency,
    required this.startOn,
    this.strength,
    this.interval = 1,
    this.times = const [],
    this.endOn,
    this.notes,
  });

  final String petId;
  final String name;
  final String? strength;
  final double? amount;
  final DoseUnit unit;
  final MedFrequency frequency;
  final int interval;
  final List<DoseTime> times;
  final DateTime? startOn;

  /// Null for continuous use.
  final DateTime? endOn;
  final String? notes;
}

class MedicationRepository {
  MedicationRepository(this._store, {Uuid? ids, DateTime Function()? now})
    : _ids = ids ?? const Uuid(),
      _now = now ?? DateTime.now;

  final PetLocalStore _store;
  final Uuid _ids;
  final DateTime Function() _now;

  /// Namespace for the ids of dose marks (see [doseId]).
  static const _doseNamespace = '6f1c2a52-3c0e-4f4e-9a3b-1d2b45a8dc6f';

  Stream<ChangeReason> get changes => _store.changes;

  DateTime get today => dayOf(_now());

  /// Medications in use on [today] first, by name; finished ones after.
  Future<List<Medication>> listMedications(String petId) async {
    final all = await _store.listMedications(petId);
    final now = today;
    return all..sort((a, b) {
      final x = a.isActiveOn(now) || a.startOn.isAfter(now);
      final y = b.isActiveOn(now) || b.startOn.isAfter(now);
      if (x != y) return x ? -1 : 1;
      return foldText(a.name).compareTo(foldText(b.name));
    });
  }

  Future<Medication?> getMedication(String id) => _store.getMedication(id);

  /// The doses to give on [day], with who gave each one.
  Future<List<DoseSlot>> dosesOnDay(String petId, DateTime day) async {
    final meds = await _store.listMedications(petId);
    final marks = await _store.listMedDoses(petId, dayOf(day));
    return dosesOn(day, meds, marks);
  }

  Future<Medication> saveMedication({
    String? id,
    required MedicationInput input,
    required AppUser byUser,
  }) async {
    await _requireMember(input.petId, byUser);
    final name = input.name.trim();
    if (name.isEmpty) throw const AppFailure('Digite o nome do remédio.');
    if (name.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no nome.');
    }
    final strength = input.strength?.trim() ?? '';
    if (strength.length > 40) {
      throw const AppFailure('Use no máximo 40 caracteres na concentração.');
    }
    final amount = input.amount;
    if (amount == null || amount <= 0 || amount > 100) {
      throw const AppFailure('Informe a quantidade de cada dose.');
    }
    final interval = switch (input.frequency) {
      MedFrequency.everyDays || MedFrequency.everyMonths => input.interval,
      _ => 1,
    };
    if (interval < 1 || interval > 365) {
      throw const AppFailure('Confira o intervalo entre as doses.');
    }
    final times = input.frequency == MedFrequency.daily
        ? ([...input.times]..sort((a, b) => a.time.compareTo(b.time)))
        : const <DoseTime>[];
    if (input.frequency == MedFrequency.daily) {
      if (times.isEmpty) {
        throw const AppFailure('Escolha manhã, tarde ou noite.');
      }
      if (times.any((t) => !isValidTime(t.time))) {
        throw const AppFailure('Confira os horários.');
      }
      if ({for (final t in times) t.period}.length != times.length) {
        throw const AppFailure('Cada período pode aparecer uma vez só.');
      }
    }
    final start = input.startOn;
    if (start == null) throw const AppFailure('Informe o início.');
    final end = input.endOn;
    if (end != null && dayOf(end).isBefore(dayOf(start))) {
      throw const AppFailure('O fim precisa ser depois do início.');
    }
    final notes = input.notes?.trim() ?? '';
    if (notes.length > 500) {
      throw const AppFailure('Use no máximo 500 caracteres nas observações.');
    }

    final medication = Medication(
      id: id ?? _ids.v4(),
      petId: input.petId,
      name: name,
      strength: strength.isEmpty ? null : strength,
      amount: amount,
      unit: input.unit,
      frequency: input.frequency,
      interval: interval,
      times: times,
      startOn: dayOf(start),
      endOn: end == null ? null : dayOf(end),
      notes: notes.isEmpty ? null : notes,
      updatedBy: byUser.id,
      updatedAt: _now().toUtc(),
    );
    await _store.saveMedication(medication);
    return medication;
  }

  Future<void> deleteMedication({
    required String id,
    required AppUser byUser,
  }) async {
    final medication = await _store.getMedication(id);
    if (medication == null) {
      throw const AppFailure('Este remédio não está mais disponível.');
    }
    await _requireMember(medication.petId, byUser);
    final now = _now().toUtc();
    await _store.saveMedication(
      medication.copyWith(deletedAt: now, updatedAt: now, updatedBy: byUser.id),
    );
  }

  /// Marks a dose as given, or undoes the mark. Two tutors marking the same
  /// dose write the same record, so it is never counted twice.
  Future<void> markGiven({
    required DoseSlot slot,
    required DateTime day,
    required bool given,
    required AppUser byUser,
  }) async {
    final medication = slot.medication;
    await _requireMember(medication.petId, byUser);
    final now = _now().toUtc();
    final period = slot.time?.period;
    final existing = slot.given;
    final dose = MedDose(
      id: doseId(medication.id, day, period),
      medicationId: medication.id,
      petId: medication.petId,
      dueOn: dayOf(day),
      period: period,
      givenBy: given ? byUser.id : (existing?.givenBy ?? byUser.id),
      givenByEmail: given
          ? normalizeEmail(byUser.email)
          : (existing?.givenByEmail ?? normalizeEmail(byUser.email)),
      givenAt: given ? now : (existing?.givenAt ?? now),
      updatedAt: now,
      deletedAt: given ? null : now,
    );
    await _store.saveMedDose(dose);
  }

  /// One id per medication, day and period.
  String doseId(String medicationId, DateTime day, DosePeriod? period) {
    return _ids.v5(
      _doseNamespace,
      '$medicationId|${formatDay(day)}|${period?.wire ?? ''}',
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
}
