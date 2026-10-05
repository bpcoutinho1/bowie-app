import 'package:flutter/foundation.dart';
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
      throw AppFailure(authMessage(error));
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
      throw AppFailure(authMessage(error));
    }
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  SupabaseClient _require() {
    final client = _client;
    if (client == null) {
      throw const AppFailure('Este app ainda não está conectado ao servidor.');
    }
    return client;
  }

  void _validate({required String email, required String password}) {
    if (!emailLooksValid(email)) {
      throw const AppFailure('Digite um email válido.');
    }
    if (password.length < 6) {
      throw const AppFailure('A senha precisa ter pelo menos 6 caracteres.');
    }
  }
}

/// Supabase sends English messages; show the common ones in Portuguese.
String authMessage(AuthException error) {
  if (kDebugMode) {
    // Only the status and code, so the Terminal shows what the server said.
    debugPrint(
      'Supabase auth error: status=${error.statusCode} code=${error.code}',
    );
  }
  if (error is AuthRetryableFetchException) {
    // No status means the request never reached the server.
    if (error.statusCode == null) {
      return 'Não foi possível falar com o servidor. Confira a internet e tente de novo.';
    }
    if (error.message.contains('confirmation email')) {
      return 'O servidor não conseguiu enviar o email de confirmação. Tente de novo mais tarde.';
    }
    return 'O servidor teve um problema (erro ${error.statusCode}). Tente de novo em alguns minutos.';
  }
  return switch (error.code) {
    'invalid_credentials' => 'Email ou senha incorretos.',
    'user_already_exists' ||
    'email_exists' => 'Já existe uma conta com este email. Tente entrar.',
    'email_not_confirmed' =>
      'Confirme o seu email pelo link que enviamos e tente de novo.',
    'weak_password' => 'Escolha uma senha mais forte.',
    'email_address_invalid' => 'Digite um email válido.',
    'email_address_not_authorized' =>
      'O servidor não pode enviar emails para este endereço. Tente outro email.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Muitas tentativas seguidas. Espere alguns minutos e tente de novo.',
    'signup_disabled' => 'Novos cadastros estão desativados no momento.',
    _ => 'Algo deu errado. Tente de novo.',
  };
}
