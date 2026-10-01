import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

abstract class PetRemoteApi {
  Future<void> upsertPet(Map<String, dynamic> row);

  Future<void> upsertTutor(Map<String, dynamic> row);

  Future<List<Pet>> pullPets();

  Future<List<PetTutor>> pullTutors();
}

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
      if (error.code != '23505') throw AppFailure(error.message);
      await _guard(() {
        return _client.from(table).update(row).eq('id', id).select('id');
      });
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
      throw AppFailure(error.message);
    } on SocketException {
      throw const AppFailure(
        'Could not reach the server. Changes stay on this device.',
        retryable: true,
      );
    } on TimeoutException {
      throw const AppFailure(
        'Could not reach the server. Changes stay on this device.',
        retryable: true,
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      if (_isOffline(error)) {
        throw const AppFailure(
          'Could not reach the server. Changes stay on this device.',
          retryable: true,
        );
      }
      throw const AppFailure('Something went wrong while syncing.');
    }
  }

  bool _isOffline(Object error) {
    final text = error.toString();
    return text.contains('SocketException') ||
        text.contains('ClientException') ||
        text.contains('Failed host lookup');
  }
}
