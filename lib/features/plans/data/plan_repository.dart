import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/features/plans/domain/account_plan.dart';

enum Quota { aiPhotos, diaryFiles }

/// The server side of the plan: reading it and counting what the free plan
/// limits.
abstract interface class PlanApi {
  /// The row of the person signed in, or null when there is none. Throws
  /// when the server cannot answer.
  Future<Map<String, dynamic>?> fetch();

  Future<void> consume(Quota quota, int amount);
}

class SupabasePlanApi implements PlanApi {
  const SupabasePlanApi(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> fetch() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No session');
    return _client
        .from('account_plans')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
  }

  @override
  Future<void> consume(Quota quota, int amount) async {
    await _client.rpc(
      'consume_quota',
      params: {
        'kind': switch (quota) {
          Quota.aiPhotos => 'ai_photos',
          Quota.diaryFiles => 'diary_files',
        },
        'amount': amount,
      },
    );
  }
}

/// Keeps the last plan read, so the app knows it without internet.
abstract interface class PlanCache {
  Future<Map<String, dynamic>?> read(String userId);

  Future<void> write(String userId, Map<String, dynamic> row);
}

class PrefsPlanCache implements PlanCache {
  PrefsPlanCache([this._given]);

  SharedPreferencesAsync? _given;

  /// Made on first use, where failures are already handled.
  SharedPreferencesAsync get _prefs => _given ??= SharedPreferencesAsync();

  String _key(String userId) => 'account_plan_v1_$userId';

  @override
  Future<Map<String, dynamic>?> read(String userId) async {
    final raw = await _prefs.getString(_key(userId));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String userId, Map<String, dynamic> row) =>
      _prefs.setString(_key(userId), jsonEncode(row));
}

class MemoryPlanCache implements PlanCache {
  final _rows = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String userId) async => _rows[userId];

  @override
  Future<void> write(String userId, Map<String, dynamic> row) async =>
      _rows[userId] = row;
}

class PlanRepository {
  PlanRepository(this._api, this._cache, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Null when the app is not connected to a server.
  final PlanApi? _api;
  final PlanCache _cache;
  final DateTime Function() _now;

  /// The plan from the server; without internet, the last one read; without
  /// either, [AccountPlan.unknown], which blocks nothing. An account the
  /// server answers for but has no row is on the free plan, the default.
  Future<AccountPlan> current(String userId) async {
    final api = _api;
    if (api != null) {
      try {
        final row = await api.fetch();
        if (row == null) return const AccountPlan(tier: PlanTier.free);
        try {
          await _cache.write(userId, row);
        } catch (_) {}
        return AccountPlan.fromRow(row, _now().toUtc());
      } catch (_) {
        // Offline or the table is missing: fall back below.
      }
    }
    try {
      final cached = await _cache.read(userId);
      if (cached != null) return AccountPlan.fromRow(cached, _now().toUtc());
    } catch (_) {}
    return const AccountPlan.unknown();
  }

  /// Best effort: a count that cannot reach the server is not retried.
  Future<void> consume(Quota quota, int amount) async {
    if (amount < 1) return;
    try {
      await _api?.consume(quota, amount);
    } catch (_) {}
  }
}
