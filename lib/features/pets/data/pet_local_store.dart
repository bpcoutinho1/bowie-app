import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';
import 'package:bowie/features/shopping/domain/shopping_item.dart';

enum ChangeReason { local, remote }

/// Outbox entity for photo files; the entity id is the photo path.
const photoEntity = 'pet_photos';

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
      version: 5,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, from, to) async {
        if (from < 2) await _addPetProfile(db);
        if (from < 3) await _addVaccines(db);
        if (from < 4) await _addSexAndPhoto(db);
        if (from < 5) await _addShopping(db);
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
        await _addPetProfile(db);
        await _addVaccines(db);
        await _addSexAndPhoto(db);
        await _addShopping(db);
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

  /// Version 5: the shopping list of each house.
  static Future<void> _addShopping(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE shopping_items (
        id TEXT PRIMARY KEY,
        house_id TEXT NOT NULL,
        name TEXT NOT NULL,
        details TEXT,
        catalog_key TEXT,
        status TEXT NOT NULL,
        updated_by TEXT,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX shopping_items_house_idx ON shopping_items(house_id)',
    );
  }

  /// Version 4: sex and profile photo.
  static Future<void> _addSexAndPhoto(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE pets ADD COLUMN sex TEXT');
    await db.execute('ALTER TABLE pets ADD COLUMN photo_path TEXT');
  }

  /// Version 3: vaccine and dewormer doses.
  static Future<void> _addVaccines(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE pet_vaccines (
        id TEXT PRIMARY KEY,
        pet_id TEXT NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        name TEXT NOT NULL,
        applied_on TEXT NOT NULL,
        next_due_on TEXT NOT NULL,
        product TEXT,
        lot TEXT,
        veterinarian TEXT,
        notes TEXT,
        updated_by TEXT,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX pet_vaccines_pet_idx ON pet_vaccines(pet_id)',
    );
  }

  /// Version 2: species, breed, birth date and weight.
  static Future<void> _addPetProfile(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE pets ADD COLUMN species TEXT');
    await db.execute('ALTER TABLE pets ADD COLUMN breed TEXT');
    await db.execute('ALTER TABLE pets ADD COLUMN birth_date TEXT');
    await db.execute(
      'ALTER TABLE pets ADD COLUMN birth_date_estimated INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE pets ADD COLUMN weight_kg REAL');
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

  /// Saves the pet and queues the photo files to send to or remove from the
  /// server, all at once.
  Future<void> savePetWithPhotos(
    Pet pet, {
    List<String> upload = const [],
    List<String> remove = const [],
  }) async {
    await _db.transaction((txn) async {
      await _upsertPet(txn, pet);
      await _enqueue(txn, 'pets', pet.id, pet.toRow());
      for (final photo in upload) {
        await _enqueue(txn, photoEntity, photo, {'op': 'upload'});
      }
      for (final photo in remove) {
        await _enqueue(txn, photoEntity, photo, {'op': 'remove'});
      }
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

  /// Doses of a pet that were not deleted, any order.
  Future<List<VaccineDose>> listDoses(String petId) async {
    final rows = await _db.query(
      'pet_vaccines',
      where: 'pet_id = ? AND deleted_at IS NULL',
      whereArgs: [petId],
    );
    return rows.map(VaccineDose.fromRow).toList();
  }

  Future<VaccineDose?> getDose(String id) async {
    final rows = await _db.query(
      'pet_vaccines',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VaccineDose.fromRow(rows.single);
  }

  Future<void> saveDose(VaccineDose dose) async {
    await _db.transaction((txn) async {
      await _upsertDose(txn, dose);
      await _enqueue(txn, 'pet_vaccines', dose.id, dose.toRow());
    });
    _emit(ChangeReason.local);
  }

  /// The houses a person belongs to: one per main tutor of the pets they
  /// accepted, their own included.
  Future<List<({String id, String ownerEmail})>> listHouses(
    String email,
  ) async {
    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT owner.user_id AS id, owner.email AS owner_email
      FROM pet_tutors me
      JOIN pets p ON p.id = me.pet_id AND p.deleted_at IS NULL
      JOIN pet_tutors owner
        ON owner.pet_id = me.pet_id
       AND owner.role = ?
       AND owner.status = ?
       AND owner.deleted_at IS NULL
       AND owner.user_id IS NOT NULL
      WHERE me.email = ?
        AND me.status = ?
        AND me.deleted_at IS NULL
      ORDER BY owner.email
      ''',
      [
        PetRole.owner.name,
        TutorStatus.accepted.name,
        email,
        TutorStatus.accepted.name,
      ],
    );
    return [
      for (final row in rows)
        (id: row['id']! as String, ownerEmail: row['owner_email']! as String),
    ];
  }

  /// Items of a house that were not deleted, any order.
  Future<List<ShoppingItem>> listShoppingItems(String houseId) async {
    final rows = await _db.query(
      'shopping_items',
      where: 'house_id = ? AND deleted_at IS NULL',
      whereArgs: [houseId],
    );
    return rows.map(ShoppingItem.fromRow).toList();
  }

  Future<ShoppingItem?> getShoppingItem(String id) async {
    final rows = await _db.query(
      'shopping_items',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ShoppingItem.fromRow(rows.single);
  }

  Future<void> saveShoppingItem(ShoppingItem item) async {
    await _db.transaction((txn) async {
      await _upsert(txn, 'shopping_items', item.toRow());
      await _enqueue(txn, 'shopping_items', item.id, item.toRow());
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
    List<VaccineDose> doses = const [],
    List<ShoppingItem> shopping = const [],
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
      for (final dose in doses) {
        if (pendingKeys.contains('pet_vaccines:${dose.id}')) continue;
        if (!knownPets.contains(dose.petId)) continue;
        await _upsertDose(txn, dose);
      }
      for (final item in shopping) {
        if (pendingKeys.contains('shopping_items:${item.id}')) continue;
        await _upsert(txn, 'shopping_items', item.toRow());
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
    final row = pet.toRow()
      ..['birth_date_estimated'] = pet.birthDateEstimated ? 1 : 0;
    return _upsert(db, 'pets', row);
  }

  Future<void> _upsert(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> row,
  ) {
    final columns = row.keys.toList();
    return db.rawInsert('''
      INSERT INTO $table (${columns.join(', ')})
      VALUES (${List.filled(columns.length, '?').join(', ')})
      ON CONFLICT(id) DO UPDATE SET
        ${columns.where((c) => c != 'id').map((c) => '$c = excluded.$c').join(',\n        ')}
      ''', row.values.toList());
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

  Future<void> _upsertDose(DatabaseExecutor db, VaccineDose dose) {
    return _upsert(db, 'pet_vaccines', dose.toRow());
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
