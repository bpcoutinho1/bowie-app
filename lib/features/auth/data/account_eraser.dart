import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/core/error/app_failure.dart';

/// Deletes the account on the server, for good.
abstract interface class AccountEraser {
  /// [transfers] maps each pet that has other tutors to the pet_tutors id of
  /// the one who becomes its main tutor.
  Future<void> erase(Map<String, String> transfers);
}

/// Calls the `delete-account` Edge Function (supabase/functions).
class SupabaseAccountEraser implements AccountEraser {
  SupabaseAccountEraser(this._client);

  final SupabaseClient _client;

  @override
  Future<void> erase(Map<String, String> transfers) async {
    try {
      await _client.functions
          .invoke('delete-account', body: {'transfers': transfers})
          .timeout(const Duration(seconds: 60));
    } on FunctionsFetchException {
      throw const AppFailure(
        'Sem conexão com a internet. A exclusão da conta precisa de internet.',
        retryable: true,
      );
    } on TimeoutException {
      throw const AppFailure(
        'O servidor demorou para responder. Tente de novo.',
        retryable: true,
      );
    } on FunctionException catch (error) {
      throw erasingFailure(error.status, error.details);
    }
  }
}

/// The function answers errors as `{error, message}` with a Portuguese
/// message; anything else becomes a generic one.
AppFailure erasingFailure(int status, Object? details) {
  if (kDebugMode) {
    final code = details is Map ? details['error'] : null;
    debugPrint('delete-account failed: status=$status code=$code');
  }
  final message = details is Map ? details['message'] : null;
  if (message is String && message.isNotEmpty) {
    return AppFailure(message, retryable: status >= 500);
  }
  return switch (status) {
    401 => const AppFailure('Entre na sua conta de novo para excluí-la.'),
    404 => const AppFailure(
      'A exclusão da conta ainda não foi configurada no servidor.',
    ),
    _ => const AppFailure(
      'Não foi possível excluir a conta agora. Tente de novo.',
      retryable: true,
    ),
  };
}
