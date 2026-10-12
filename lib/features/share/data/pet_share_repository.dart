import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_access.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/share/domain/pet_share.dart';

/// The server side of the shared links. Links only exist on the server (the
/// sheet is read from there), so they need internet and skip the outbox.
abstract interface class PetShareApi {
  Future<List<PetShare>> list(String petId);

  Future<PetShare> create({
    required String id,
    required String petId,
    required String token,
    required SharePreset preset,
    required String? label,
    required String createdBy,
  });

  Future<void> revoke(String id, DateTime at);
}

class SupabasePetShareApi implements PetShareApi {
  const SupabasePetShareApi(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PetShare>> list(String petId) async {
    final rows = await _client
        .from('pet_shares')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false);
    return rows.map(PetShare.fromRow).toList();
  }

  @override
  Future<PetShare> create({
    required String id,
    required String petId,
    required String token,
    required SharePreset preset,
    required String? label,
    required String createdBy,
  }) async {
    // The server sets when it was made and when it expires.
    final row = await _client
        .from('pet_shares')
        .insert({
          'id': id,
          'pet_id': petId,
          'token': token,
          'preset': preset.wire,
          'label': label,
          'created_by': createdBy,
        })
        .select()
        .single();
    return PetShare.fromRow(row);
  }

  @override
  Future<void> revoke(String id, DateTime at) async {
    await _client
        .from('pet_shares')
        .update({'revoked_at': at.toUtc().toIso8601String()})
        .eq('id', id)
        .select('id')
        .single();
  }
}

class PetShareRepository {
  PetShareRepository(
    this._store,
    this._api, {
    Uuid? ids,
    String Function()? tokens,
    DateTime Function()? now,
  }) : _ids = ids ?? const Uuid(),
       _tokens = tokens ?? newShareToken,
       _now = now ?? DateTime.now;

  final PetLocalStore _store;

  /// Null when the app is not connected to a server.
  final PetShareApi? _api;
  final Uuid _ids;
  final String Function() _tokens;
  final DateTime Function() _now;

  /// Links that still work, the newest first.
  Future<List<PetShare>> activeShares(String petId) async {
    final shares = await _call(() => _require().list(petId));
    final now = _now();
    return shares.where((share) => share.isActive(now)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<PetShare> create({
    required String petId,
    required SharePreset preset,
    String? label,
    required AppUser byUser,
  }) async {
    await requirePetMember(
      _store,
      petId,
      byUser,
      message: 'Só os tutores do pet podem compartilhar a ficha.',
    );
    final clean = label?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
    if (clean.length > 60) {
      throw const AppFailure('Use no máximo 60 caracteres em "Para quem".');
    }
    return _call(
      () => _require().create(
        id: _ids.v4(),
        petId: petId,
        token: _tokens(),
        preset: preset,
        label: clean.isEmpty ? null : clean,
        createdBy: byUser.id,
      ),
    );
  }

  /// The link stops working at once, for whoever has it.
  Future<void> revoke({
    required PetShare share,
    required AppUser byUser,
  }) async {
    await requirePetMember(
      _store,
      share.petId,
      byUser,
      message: 'Só os tutores do pet podem cancelar o link.',
    );
    await _call(() => _require().revoke(share.id, _now()));
  }

  PetShareApi _require() {
    final api = _api;
    if (api == null) {
      throw const AppFailure('Este app ainda não está conectado ao servidor.');
    }
    return api;
  }

  Future<T> _call<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on SocketException {
      throw const AppFailure(
        'Sem internet. A ficha compartilhada precisa de conexão.',
      );
    } on AuthException {
      throw const AppFailure('Entre de novo na sua conta e tente outra vez.');
    } on PostgrestException {
      throw const AppFailure(
        'O servidor recusou o pedido. Confira se a atualização do banco já '
        'foi aplicada e tente de novo.',
      );
    } catch (_) {
      throw const AppFailure(
        'Não foi possível falar com o servidor. Confira a internet e tente '
        'de novo.',
      );
    }
  }
}
