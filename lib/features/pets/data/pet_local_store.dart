import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

enum ChangeReason { local, remote }

class OutboxItem {
  const OutboxItem({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.payloadJson,
    required this.createdAt,
  });

  final int id;
  final String entity;
  final String entityId;
  final String payloadJson;
  final String createdAt;

  Map<String, dynamic> get payload {
    final decoded = jsonDecode(payloadJson);
    return Map<String, dynamic>.from(decoded as Map);
  }

  static OutboxItem fromRow(Map<String, Object?> row) {
    return OutboxItem(
      id: row['id']! as int,
      entity: row['entity']! as String,
      entityId: row['entity_id']! as String,
      payloadJson: row['payload']! as String,
      createdAt: row['created_at']! as String,
    );
  }
}

class PetLocalStore {
  PetLocalStore(this._db);

  final Database _db;
  final _changes = StreamController<ChangeReason>.broadcast();

  Stream<ChangeReason> get changes => _changes.stream;

  static Future<PetLocalStore> open({String? databasePath}) async {
    final db = await openDatabase(
      databasePath ?? path.join(await getDatabasesPath(), 'bowie.db'),
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pets (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE pet_tutors (
            id TEXT PRIMARY KEY,
            pet_id TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
            user_id TEXT,
            email TEXT NOT NULL,
            role TEXT NOT NULL,
            status TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
        ''');
        await db.execute(
          'CREATE INDEX pet_tutors_pet_idx ON pet_tutors(pet_id)',
        );
        await db.execute(
          'CREATE INDEX pet_tutors_email_idx ON pet_tutors(email)',
        );
        await db.execute('''
          CREATE TABLE sync_outbox (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            entity TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE UNIQUE INDEX sync_outbox_entity_idx
          ON sync_outbox(entity, entity_id)
        ''');
      },
    );
    return PetLocalStore(db);
  }

  Future<List<Pet>> listPetsFor(String email) async {
    final rows = await _db.rawQuery(
      '''
      SELECT p.*
      FROM pets p
      JOIN pet_tutors t ON t.pet_id = p.id
      WHERE p.deleted_at IS NULL
        AND t.deleted_at IS NULL
        AND t.email = ?
        AND t.status = ?
      ORDER BY p.name COLLATE NOCASE
      ''',
      [email, TutorStatus.accepted.name],
    );
    return rows.map(Pet.fromRow).toList();
  }

  Future<Pet?> getPet(String id) async {
    final rows = await _db.query(
      'pets',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Pet.fromRow(rows.single);
  }

  Future<List<PetTutor>> listTutors(String petId) async {
    final rows = await _db.query(
      'pet_tutors',
      where: 'pet_id = ? AND deleted_at IS NULL',
      whereArgs: [petId],
      orderBy: "CASE role WHEN 'owner' THEN 0 ELSE 1 END, email",
    );
    return rows.map(PetTutor.fromRow).toList();
  }

  Future<PetTutor?> getTutor(String id) async {
    final rows = await _db.query(
      'pet_tutors',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return PetTutor.fromRow(rows.single);
  }

  Future<List<TutorInvite>> listInvites(String email) async {
    final rows = await _db.rawQuery(
      '''
      SELECT t.*, p.name AS pet_name
      FROM pet_tutors t
      JOIN pets p ON p.id = t.pet_id
      WHERE t.email = ?
        AND t.status = ?
        AND t.deleted_at IS NULL
        AND p.deleted_at IS NULL
      ORDER BY t.updated_at DESC
      ''',
      [email, TutorStatus.pending.name],
    );
    return [
      for (final row in rows)
        TutorInvite(
          tutor: PetTutor.fromRow(row),
          petName: row['pet_name']! as String,
        ),
    ];
  }

  Future<void> saveNewPet(Pet pet, PetTutor owner) async {
    await _db.transaction((txn) async {
      await _upsertPet(txn, pet);
      await _upsertTutor(txn, owner);
      await _enqueue(txn, 'pets', pet.id, pet.toRow());
      await _enqueue(txn, 'pet_tutors', owner.id, owner.toRow());
    });
    _emit(ChangeReason.local);
  }

  Future<void> savePet(Pet pet) async {
    await _db.transaction((txn) async {
      await _upsertPet(txn, pet);
      await _enqueue(txn, 'pets', pet.id, pet.toRow());
    });
    _emit(ChangeReason.local);
  }

  Future<void> saveTutor(PetTutor tutor) async {
    await _db.transaction((txn) async {
      await _upsertTutor(txn, tutor);
      await _enqueue(txn, 'pet_tutors', tutor.id, tutor.toRow());
    });
    _emit(ChangeReason.local);
  }

  Future<List<OutboxItem>> pending() async {
    final rows = await _db.query(
      'sync_outbox',
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(OutboxItem.fromRow).toList();
  }

  /// Drops a pushed item only when the queued payload is still the one sent.
  Future<void> removePendingIfUnchanged(int id, String payloadJson) {
    return _db.delete(
      'sync_outbox',
      where: 'id = ? AND payload = ?',
      whereArgs: [id, payloadJson],
    );
  }

  Future<void> applyRemote({
    required List<Pet> pets,
    required List<PetTutor> tutors,
  }) async {
    await _db.transaction((txn) async {
      final pendingKeys = await _pendingKeys(txn);
      final knownPets = await _petIds(txn);
      for (final pet in pets) {
        if (pendingKeys.contains('pets:${pet.id}')) continue;
        await _upsertPet(txn, pet);
        knownPets.add(pet.id);
      }
      for (final tutor in tutors) {
        if (pendingKeys.contains('pet_tutors:${tutor.id}')) continue;
        if (!knownPets.contains(tutor.petId)) continue;
        await _upsertTutor(txn, tutor);
      }
    });
    _emit(ChangeReason.remote);
  }

  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }

  void _emit(ChangeReason reason) {
    if (!_changes.isClosed) _changes.add(reason);
  }

  Future<void> _upsertPet(DatabaseExecutor db, Pet pet) {
    return db.rawInsert(
      '''
      INSERT INTO pets (id, name, updated_at, deleted_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at
      ''',
      [pet.id, pet.name, _iso(pet.updatedAt), _isoOrNull(pet.deletedAt)],
    );
  }

  Future<void> _upsertTutor(DatabaseExecutor db, PetTutor tutor) {
    return db.rawInsert(
      '''
      INSERT INTO pet_tutors (
        id, pet_id, user_id, email, role, status, updated_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        pet_id = excluded.pet_id,
        user_id = excluded.user_id,
        email = excluded.email,
        role = excluded.role,
        status = excluded.status,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at
      ''',
      [
        tutor.id,
        tutor.petId,
        tutor.userId,
        tutor.email,
        tutor.role.name,
        tutor.status.name,
        _iso(tutor.updatedAt),
        _isoOrNull(tutor.deletedAt),
      ],
    );
  }

  Future<void> _enqueue(
    DatabaseExecutor db,
    String entity,
    String entityId,
    Map<String, Object?> payload,
  ) {
    final now = DateTime.now().toUtc().toIso8601String();
    return db.rawInsert(
      '''
      INSERT INTO sync_outbox (entity, entity_id, payload, created_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(entity, entity_id) DO UPDATE SET
        payload = excluded.payload,
        created_at = excluded.created_at
      ''',
      [entity, entityId, jsonEncode(payload), now],
    );
  }

  Future<Set<String>> _pendingKeys(DatabaseExecutor db) async {
    final rows = await db.query(
      'sync_outbox',
      columns: ['entity', 'entity_id'],
    );
    return {for (final row in rows) '${row['entity']}:${row['entity_id']}'};
  }

  Future<Set<String>> _petIds(DatabaseExecutor db) async {
    final rows = await db.query('pets', columns: ['id']);
    return {for (final row in rows) row['id']! as String};
  }

  String _iso(DateTime value) => value.toUtc().toIso8601String();

  String? _isoOrNull(DateTime? value) => value == null ? null : _iso(value);
}
