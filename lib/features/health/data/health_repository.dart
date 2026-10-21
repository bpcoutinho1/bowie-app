import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/photo_picker.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_photo_store.dart';
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
    this.keptProofs = const [],
    this.newProofs = const [],
    this.remindDays = defaultReminderDays,
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

  /// Proof photos already on the phone: the dose's own, or card pages saved
  /// by the card reading.
  final List<String> keptProofs;

  /// Proof photos taken or chosen now.
  final List<Uint8List> newProofs;

  /// 7, 14 or 30 days before the due date.
  final int remindDays;
}

/// Proof photos per dose: the vial sticker and the stamp.
const maxProofPhotos = 2;

class HealthRepository {
  HealthRepository(
    this._store, {
    this.photos,
    Uuid? ids,
    DateTime Function()? now,
  }) : _ids = ids ?? const Uuid(),
       _now = now ?? DateTime.now;

  final PetLocalStore _store;

  /// Where proof photos are kept on the phone.
  final PetPhotoStore? photos;
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
    final previous = id == null ? null : await _store.getDose(id);
    final draft = _build(id, input, byUser);
    final proofs = await _proofs(input, previous);
    final dose = draft.copyWithProofs(proofs.paths);
    final removed = <String>[];
    for (final path in previous?.proofPaths ?? const <String>[]) {
      if (proofs.paths.contains(path)) continue;
      if (await _store.isProofInUse(path, exceptDoseId: dose.id)) continue;
      removed.add(path);
    }
    await _store.saveDose(dose, upload: proofs.added, remove: removed);
    for (final path in removed) {
      await photos?.delete(path);
    }
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
    final drafts = [for (final input in inputs) _build(null, input, byUser)];
    final saved = <VaccineDose>[];
    for (var i = 0; i < drafts.length; i++) {
      final proofs = await _proofs(inputs[i], null);
      final dose = drafts[i].copyWithProofs(proofs.paths);
      await _store.saveDose(dose, upload: proofs.added);
      saved.add(dose);
    }
    return saved;
  }

  /// Checks the proof photos, writes the new ones to the phone and returns
  /// all the paths, plus the ones to upload.
  Future<({List<String> paths, List<String> added})> _proofs(
    DoseInput input,
    VaccineDose? previous,
  ) async {
    final kept = <String>[];
    for (final path in input.keptProofs) {
      final own = previous?.proofPaths.contains(path) ?? false;
      final onPhone =
          path.startsWith('${input.petId}/') &&
          await photos?.local(path) != null;
      if ((own || onPhone) && !kept.contains(path)) kept.add(path);
    }
    if (kept.length + input.newProofs.length > maxProofPhotos) {
      throw const AppFailure('Use no máximo $maxProofPhotos fotos.');
    }
    final store = photos;
    if (input.newProofs.isNotEmpty && store == null) {
      throw const AppFailure('Não foi possível guardar fotos neste celular.');
    }
    for (final photo in input.newProofs) {
      if (photoMediaType(photo) == null) {
        throw const AppFailure(
          'Formato de foto não aceito. Tente tirar a foto pela câmera.',
        );
      }
    }
    final added = [
      for (final path in kept)
        if (!(previous?.proofPaths.contains(path) ?? false)) path,
    ];
    final paths = [...kept];
    for (final photo in input.newProofs) {
      final path = store!.newPath(input.petId, photoMediaType(photo)!);
      await store.write(path, photo);
      paths.add(path);
      added.add(path);
    }
    return (paths: paths, added: added);
  }

  VaccineDose _build(String? id, DoseInput input, AppUser byUser) {
    final name = input.name.trim();
    if (name.isEmpty) {
      throw AppFailure(switch (input.kind) {
        DoseKind.vaccine => 'Digite o nome da vacina.',
        DoseKind.dewormer => 'Digite o nome do vermífugo.',
        DoseKind.fleaTick => 'Digite o nome do produto.',
      });
    }
    if (!reminderDayOptions.contains(input.remindDays)) {
      throw const AppFailure('Escolha o lembrete: 7, 14 ou 30 dias antes.');
    }
    if (name.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no nome.');
    }
    final applied = input.appliedOn;
    final due = input.nextDueOn;
    if (applied == null) {
      throw const AppFailure('Informe a data da aplicação.');
    }
    if (due == null) {
      throw AppFailure(
        input.kind == DoseKind.fleaTick
            ? 'Informe quando trocar.'
            : 'Informe quando é a próxima dose.',
      );
    }
    if (dayOf(applied).isAfter(today)) {
      throw const AppFailure('A data da aplicação não pode estar no futuro.');
    }
    if (!dayOf(due).isAfter(dayOf(applied))) {
      throw AppFailure(
        input.kind == DoseKind.fleaTick
            ? 'A troca precisa ser depois da data da aplicação.'
            : 'A próxima dose precisa ser depois da data da aplicação.',
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
      remindDays: input.remindDays,
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
    // Proof photos go too, unless another dose shows the same card page.
    final removed = <String>[];
    for (final path in dose.proofPaths) {
      if (!await _store.isProofInUse(path, exceptDoseId: dose.id)) {
        removed.add(path);
      }
    }
    await _store.saveDose(
      dose.copyWith(deletedAt: now, updatedAt: now, updatedBy: byUser.id),
      remove: removed,
    );
    for (final path in removed) {
      await photos?.delete(path);
    }
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
