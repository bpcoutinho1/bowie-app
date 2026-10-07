import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/photo_picker.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_photo_store.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

/// What a person fills in on the diary form.
class EventInput {
  const EventInput({
    required this.petId,
    required this.kind,
    required this.title,
    required this.occursOn,
    this.time,
    this.notes,
    this.contactId,
    this.keptPhotos = const [],
    this.newPhotos = const [],
  });

  final String petId;
  final EventKind kind;
  final String title;
  final DateTime? occursOn;
  final String? time;
  final String? notes;
  final String? contactId;

  /// Photos the entry already had and still keeps.
  final List<String> keptPhotos;

  /// Photos taken or chosen now (JPEG, PNG or WebP).
  final List<Uint8List> newPhotos;
}

class DiaryRepository {
  DiaryRepository(
    this._store, {
    this.photos,
    Uuid? ids,
    DateTime Function()? now,
  }) : _ids = ids ?? const Uuid(),
       _now = now ?? DateTime.now;

  final PetLocalStore _store;

  /// Where photos are kept on the phone. Without it, entries take no photos.
  final PetPhotoStore? photos;
  final Uuid _ids;
  final DateTime Function() _now;

  Stream<ChangeReason> get changes => _store.changes;

  DateTime get today => dayOf(_now());

  /// Every entry of the pet, the most recent day first; within a day, by time.
  Future<List<PetEvent>> listEvents(String petId) async {
    return sortEvents(await _store.listEvents(petId));
  }

  Future<PetEvent?> getEvent(String id) => _store.getEvent(id);

  /// Creates an entry, or edits it when [id] is given. Any accepted tutor can.
  Future<PetEvent> saveEvent({
    String? id,
    required EventInput input,
    required AppUser byUser,
  }) async {
    await _requireMember(input.petId, byUser);
    final title = input.title.trim();
    if (title.isEmpty) throw const AppFailure('Conte o que aconteceu.');
    if (title.length > 80) {
      throw const AppFailure('Use no máximo 80 caracteres no título.');
    }
    final day = input.occursOn;
    if (day == null) throw const AppFailure('Escolha o dia.');
    if (day.year < 2000 || day.isAfter(DateTime(today.year + 5, 12, 31))) {
      throw const AppFailure('Confira a data.');
    }
    final time = input.time?.trim();
    if (time != null && time.isNotEmpty && !isValidTime(time)) {
      throw const AppFailure('Confira o horário.');
    }
    final notes = input.notes?.trim() ?? '';
    if (notes.length > 1000) {
      throw const AppFailure('Use no máximo 1000 caracteres nas observações.');
    }
    final contactId = input.contactId;
    if (contactId != null) {
      final contact = await _store.getContact(contactId);
      final house = await _store.houseOfPet(input.petId);
      if (contact == null || contact.houseId != house) {
        throw const AppFailure('Este contato não é da casa deste pet.');
      }
    }

    final previous = id == null ? null : await _store.getEvent(id);
    final kept = [
      for (final path in input.keptPhotos)
        if (previous?.photoPaths.contains(path) ?? false) path,
    ];
    if (kept.length + input.newPhotos.length > maxEventPhotos) {
      throw const AppFailure('Use no máximo $maxEventPhotos fotos.');
    }
    final store = photos;
    if (input.newPhotos.isNotEmpty && store == null) {
      throw const AppFailure('Não foi possível guardar fotos neste celular.');
    }
    final added = <String>[];
    for (final photo in input.newPhotos) {
      final type = photoMediaType(photo);
      if (type == null) {
        throw const AppFailure(
          'Formato de foto não aceito. Tente tirar a foto pela câmera.',
        );
      }
      if (photo.length > 5 * 1024 * 1024) {
        throw const AppFailure('Uma das fotos é grande demais.');
      }
    }
    for (final photo in input.newPhotos) {
      final path = store!.newPath(input.petId, photoMediaType(photo)!);
      await store.write(path, photo);
      added.add(path);
    }
    final removed = [
      for (final path in previous?.photoPaths ?? const <String>[])
        if (!kept.contains(path)) path,
    ];

    final event = PetEvent(
      id: id ?? _ids.v4(),
      petId: input.petId,
      kind: input.kind,
      title: title,
      occursOn: dayOf(day),
      time: time == null || time.isEmpty ? null : time,
      notes: notes.isEmpty ? null : notes,
      contactId: contactId,
      photoPaths: [...kept, ...added],
      updatedBy: byUser.id,
      updatedAt: _now().toUtc(),
    );
    await _store.saveEvent(event, upload: added, remove: removed);
    for (final path in removed) {
      await photos?.delete(path);
    }
    return event;
  }

  Future<void> deleteEvent({
    required String id,
    required AppUser byUser,
  }) async {
    final event = await _store.getEvent(id);
    if (event == null) {
      throw const AppFailure('Este registro não está mais disponível.');
    }
    await _requireMember(event.petId, byUser);
    final now = _now().toUtc();
    // The photos go too, from the phone and from the server.
    await _store.saveEvent(
      event.copyWith(deletedAt: now, updatedAt: now, updatedBy: byUser.id),
      remove: event.photoPaths,
    );
    for (final path in event.photoPaths) {
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
      throw const AppFailure('Você não pode alterar o diário deste pet.');
    }
  }
}

/// "09:30": hours 00–23 and minutes 00–59.
bool isValidTime(String value) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(value);
  return match != null;
}

/// The most recent day first; within a day, timed entries in time order and
/// then the rest.
List<PetEvent> sortEvents(Iterable<PetEvent> events) {
  return events.where((e) => e.deletedAt == null).toList()..sort((a, b) {
    final byDay = b.occursOn.compareTo(a.occursOn);
    if (byDay != 0) return byDay;
    final x = a.time, y = b.time;
    if (x != null && y != null) return x.compareTo(y);
    if (x != null || y != null) return x != null ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
}

/// Scheduled entries after [today], the nearest first.
List<PetEvent> upcomingEvents(Iterable<PetEvent> events, DateTime today) {
  return events.where((e) => e.isScheduled(today)).toList()..sort((a, b) {
    final byDay = a.occursOn.compareTo(b.occursOn);
    if (byDay != 0) return byDay;
    return (a.time ?? '99').compareTo(b.time ?? '99');
  });
}
