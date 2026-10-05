import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/features/auth/data/auth_repository.dart';

void main() {
  test(
    'a request that never reached the server asks to check the internet',
    () {
      final message = authMessage(
        AuthRetryableFetchException(
          message: 'SocketException: Failed host lookup',
        ),
      );
      expect(message, contains('Confira a internet'));
    },
  );

  test('a server error is not reported as missing internet', () {
    final message = authMessage(
      AuthRetryableFetchException(
        message: '{"msg":"Database error saving new user"}',
        statusCode: '500',
      ),
    );
    expect(message, isNot(contains('internet')));
    expect(message, contains('erro 500'));
  });

  test('a failed confirmation email says so', () {
    final message = authMessage(
      AuthRetryableFetchException(
        message: '{"msg":"Error sending confirmation email"}',
        statusCode: '500',
      ),
    );
    expect(message, contains('email de confirmação'));
  });

  test('wrong password has its own message', () {
    final message = authMessage(
      const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      ),
    );
    expect(message, 'Email ou senha incorretos.');
  });
}
