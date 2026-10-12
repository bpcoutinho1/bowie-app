import 'package:uuid/uuid.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/domain/health_note.dart';
import 'package:bowie/features/pets/data/pet_access.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';

class HealthNoteRepository {
  HealthNoteRepository(this._store, {Uuid? ids, DateTime Function()? now})
    : _ids = ids ?? const Uuid(),
      _now = now ?? DateTime.now;

  final PetLocalStore _store;
  final Uuid _ids;
  final DateTime Function() _now;

  Stream<ChangeReason> get changes => _store.changes;

  /// Special care first, then allergies, then diet; each by title.
  Future<List<HealthNote>> listNotes(String petId) async {
    return (await _store.listHealthNotes(petId))..sort((a, b) {
      final byKind = a.kind.index.compareTo(b.kind.index);
      if (byKind != 0) return byKind;
      return foldText(a.title).compareTo(foldText(b.title));
    });
  }

  Future<HealthNote?> getNote(String id) => _store.getHealthNote(id);

  Future<HealthNote> saveNote({
    String? id,
    required String petId,
    required HealthNoteKind kind,
    required String title,
    String? details,
    required AppUser byUser,
  }) async {
    await requirePetMember(_store, petId, byUser);
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw AppFailure(switch (kind) {
        HealthNoteKind.allergy => 'Diga a que o pet tem alergia.',
        HealthNoteKind.diet => 'Diga o que o pet come.',
        HealthNoteKind.specialCare => 'Diga qual é o cuidado especial.',
      });
    }
    if (cleanTitle.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no título.');
    }
    final cleanDetails = details?.trim() ?? '';
    if (cleanDetails.length > 500) {
      throw const AppFailure('Use no máximo 500 caracteres nos detalhes.');
    }
    final note = HealthNote(
      id: id ?? _ids.v4(),
      petId: petId,
      kind: kind,
      title: cleanTitle,
      details: cleanDetails.isEmpty ? null : cleanDetails,
      updatedBy: byUser.id,
      updatedAt: _now().toUtc(),
    );
    await _store.saveHealthNote(note);
    return note;
  }

  Future<void> deleteNote({required String id, required AppUser byUser}) async {
    final note = await _store.getHealthNote(id);
    if (note == null) {
      throw const AppFailure('Este registro não está mais disponível.');
    }
    await requirePetMember(_store, note.petId, byUser);
    final now = _now().toUtc();
    await _store.saveHealthNote(
      note.copyWith(deletedAt: now, updatedAt: now, updatedBy: byUser.id),
    );
  }
}
