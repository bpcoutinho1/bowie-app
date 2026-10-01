import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  Future<void> signIn({required String email, required String password}) async {
    _validate(email: email, password: password);
    try {
      await _require().auth.signInWithPassword(
        email: normalizeEmail(email),
        password: password,
      );
    } on AuthException catch (error) {
      throw AppFailure(error.message);
    }
  }

  /// Returns true when the account still needs an email confirmation.
  Future<bool> signUp({required String email, required String password}) async {
    _validate(email: email, password: password);
    try {
      final response = await _require().auth.signUp(
        email: normalizeEmail(email),
        password: password,
      );
      return response.session == null;
    } on AuthException catch (error) {
      throw AppFailure(error.message);
    }
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  SupabaseClient _require() {
    final client = _client;
    if (client == null) {
      throw const AppFailure('Supabase is not configured in this build.');
    }
    return client;
  }

  void _validate({required String email, required String password}) {
    if (!emailLooksValid(email)) {
      throw const AppFailure('Enter a valid email.');
    }
    if (password.length < 6) {
      throw const AppFailure('Use at least 6 characters.');
    }
  }
}
