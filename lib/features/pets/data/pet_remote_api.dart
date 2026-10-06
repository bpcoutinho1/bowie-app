import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/photo_picker.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

abstract class PetRemoteApi {
  Future<void> upsertPet(Map<String, dynamic> row);

  Future<void> upsertTutor(Map<String, dynamic> row);

  Future<List<Pet>> pullPets();

  Future<List<PetTutor>> pullTutors();

  Future<void> upsertDose(Map<String, dynamic> row);

  Future<List<VaccineDose>> pullDoses();

  Future<void> uploadPhoto(String path, Uint8List photo);

  Future<void> removePhoto(String path);

  /// Null when the photo is not on the server (yet).
  Future<Uint8List?> downloadPhoto(String path);

  /// Makes the tutor row [tutorId] the main tutor of [petId]; the current
  /// main tutor becomes a regular tutor. Runs on the server in one step.
  Future<void> transferPet({required String petId, required String tutorId});
}

/// Private bucket for pet profile photos.
const petPhotosBucket = 'pet-photos';

/// Shown when the server refuses a change, usually because of a permission rule.
const _rejected = 'O servidor recusou uma alteração. Tente de novo mais tarde.';

class SupabasePetApi implements PetRemoteApi {
  const SupabasePetApi(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsertPet(Map<String, dynamic> row) => _save('pets', row);

  @override
  Future<void> upsertTutor(Map<String, dynamic> row) =>
      _save('pet_tutors', row);

  /// Update an existing row, otherwise insert it.
  ///
  /// A plain upsert checks insert policies against the final row, which would
  /// reject an invite being accepted. Update-then-insert follows the policies
  /// that match each case.
  Future<void> _save(String table, Map<String, dynamic> row) async {
    final id = row['id'] as String;
    final updated = await _guard(() {
      return _client.from(table).update(row).eq('id', id).select('id');
    });
    if (updated.isNotEmpty) return;
    try {
      await _guard(() => _client.from(table).insert(row));
    } on PostgrestException catch (error) {
      if (error.code != '23505') throw const AppFailure(_rejected);
      await _guard(() {
        return _client.from(table).update(row).eq('id', id).select('id');
      });
    }
  }

  @override
  Future<void> upsertDose(Map<String, dynamic> row) =>
      _save('pet_vaccines', row);

  @override
  Future<List<VaccineDose>> pullDoses() async {
    final rows = await _pull('pet_vaccines');
    return rows.map(VaccineDose.fromRow).toList();
  }

  @override
  Future<void> uploadPhoto(String path, Uint8List photo) {
    return _guard(
      () => _client.storage
          .from(petPhotosBucket)
          .uploadBinary(
            path,
            photo,
            fileOptions: FileOptions(
              contentType: photoMediaType(photo) ?? 'image/jpeg',
              upsert: true,
            ),
          ),
    );
  }

  @override
  Future<void> removePhoto(String path) {
    return _guard(() => _client.storage.from(petPhotosBucket).remove([path]));
  }

  @override
  Future<Uint8List?> downloadPhoto(String path) async {
    // Best effort: a photo that is missing, not uploaded yet or unreachable
    // just does not show, and is tried again later.
    try {
      return await _client.storage.from(petPhotosBucket).download(path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> transferPet({
    required String petId,
    required String tutorId,
  }) async {
    try {
      await _client.rpc(
        'transfer_pet',
        params: {'target_pet': petId, 'new_owner': tutorId},
      );
    } on PostgrestException catch (error) {
      throw AppFailure(switch (error.code) {
        '42501' => 'Só o tutor principal pode transferir o pet.',
        'P0002' => 'Só quem já aceitou o convite pode virar tutor principal.',
        _ => 'O servidor não conseguiu transferir o pet. Tente de novo.',
      });
    } on AppFailure {
      rethrow;
    } catch (error) {
      if (_isOffline(error)) {
        throw const AppFailure(
          'Para transferir o pet, conecte-se à internet.',
          retryable: true,
        );
      }
      throw const AppFailure(
        'O servidor não conseguiu transferir o pet. Tente de novo.',
      );
    }
  }

  @override
  Future<List<Pet>> pullPets() async {
    final rows = await _pull('pets');
    return rows.map(Pet.fromRow).toList();
  }

  @override
  Future<List<PetTutor>> pullTutors() async {
    final rows = await _pull('pet_tutors');
    return rows.map(PetTutor.fromRow).toList();
  }

  Future<List<Map<String, Object?>>> _pull(String table) async {
    final rows = <Map<String, Object?>>[];
    var start = 0;
    const pageSize = 200;
    while (true) {
      final end = start + pageSize - 1;
      final batch = await _guard(() {
        return _client
            .from(table)
            .select()
            .order('updated_at', ascending: true)
            .order('id', ascending: true)
            .range(start, end);
      });
      final page = [for (final row in batch) Map<String, Object?>.from(row)];
      rows.addAll(page);
      if (page.length < pageSize) return rows;
      start += pageSize;
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (error) {
      if (error.code == '23505') rethrow;
      throw const AppFailure(_rejected);
    } on StorageException catch (error) {
      if (_isOffline(error)) {
        throw const AppFailure(
          'Sem conexão com o servidor. As alterações ficam salvas no celular.',
          retryable: true,
        );
      }
      throw const AppFailure(_rejected);
    } on SocketException {
      throw const AppFailure(
        'Sem conexão com o servidor. As alterações ficam salvas no celular.',
        retryable: true,
      );
    } on TimeoutException {
      throw const AppFailure(
        'Sem conexão com o servidor. As alterações ficam salvas no celular.',
        retryable: true,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      if (_isOffline(error)) {
        throw const AppFailure(
          'Sem conexão com o servidor. As alterações ficam salvas no celular.',
          retryable: true,
        );
      }
      throw const AppFailure(
        'Algo deu errado na sincronização. Tente de novo.',
      );
    }
  }

  bool _isOffline(Object error) {
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup');
  }
}
