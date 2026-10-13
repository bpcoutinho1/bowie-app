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
  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    final profile = checkProfile(name: name, phone: phone);
    _validate(email: email, password: password);
    try {
      final response = await _require().auth.signUp(
        email: normalizeEmail(email),
        password: password,
        data: {'name': profile.name, 'phone': profile.phone},
      );
      return response.session == null;
    } on AuthException catch (error) {
      throw AppFailure(authMessage(error));
    }
  }

  /// Emails a code to create a new password. The server answers the same
  /// whether or not the email has an account, so nobody learns who uses
  /// the app.
  Future<void> sendPasswordCode(String email) async {
    if (!emailLooksValid(email)) {
      throw const AppFailure('Digite um email válido.');
    }
    try {
      await _require().auth.resetPasswordForEmail(normalizeEmail(email));
    } on AuthException catch (error) {
      throw AppFailure(authMessage(error));
    }
  }

  /// Checks the emailed code, which signs the person in, and saves the new
  /// password right away.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final digits = code.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6,10}$').hasMatch(digits)) {
      throw const AppFailure('Digite o código de 6 números que enviamos.');
    }
    _checkPassword(newPassword);
    final client = _require();
    try {
      await client.auth.verifyOTP(
        email: normalizeEmail(email),
        token: digits,
        type: OtpType.recovery,
      );
      await client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AppFailure(authMessage(error));
    }
  }

  /// A new password for the account already signed in.
  Future<void> changePassword(String newPassword) async {
    _checkPassword(newPassword);
    try {
      await _require().auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AppFailure(authMessage(error));
    }
  }

  /// Saves the name and cell phone in the account. The session updates, so
  /// the new values reach the app by itself.
  Future<void> updateProfile({
    required String name,
    required String phone,
  }) async {
    final profile = checkProfile(name: name, phone: phone);
    try {
      await _require().auth.updateUser(
        UserAttributes(data: {'name': profile.name, 'phone': profile.phone}),
      );
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
    _checkPassword(password);
  }

  void _checkPassword(String password) {
    if (password.length < 6) {
      throw const AppFailure('A senha precisa ter pelo menos 6 caracteres.');
    }
  }
}

/// Supabase sends English messages; show the common ones in Portuguese.
String authMessage(AuthException error) {
  if (kDebugMode) {
    // Status and code show what the server said. Without a status the request
    // never arrived, and the message is the network error (no user data).
    debugPrint(
      'Supabase auth error: status=${error.statusCode} code=${error.code}'
      '${error.statusCode == null ? ' message=${error.message}' : ''}',
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
    'otp_expired' ||
    'otp_disabled' => 'Código inválido ou vencido. Peça um novo código.',
    'same_password' => 'Escolha uma senha diferente da anterior.',
    'email_address_invalid' => 'Digite um email válido.',
    'email_address_not_authorized' =>
      'O servidor não pode enviar emails para este endereço. Tente outro email.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Muitas tentativas seguidas. Espere alguns minutos e tente de novo.',
    'signup_disabled' => 'Novos cadastros estão desativados no momento.',
    _ => 'Algo deu errado. Tente de novo.',
  };
}
