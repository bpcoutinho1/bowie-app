import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/data/auth_repository.dart';
import 'package:bowie/features/auth/presentation/forgot_password_page.dart';

/// Records the calls instead of reaching Supabase.
class FakeAuth extends AuthRepository {
  FakeAuth() : super(null);

  final sentTo = <String>[];
  final resets = <(String, String, String)>[];

  @override
  Future<void> sendPasswordCode(String email) async => sentTo.add(email);

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async => resets.add((email, code, newPassword));
}

void main() {
  const auth = AuthRepository(null);

  test('bad input is caught before anything is sent', () async {
    expect(
      () => auth.sendPasswordCode('bruno@'),
      throwsA(
        isA<AppFailure>().having(
          (f) => f.message,
          'message',
          contains('email'),
        ),
      ),
    );
    expect(
      () => auth.resetPassword(
        email: 'bruno@example.com',
        code: '12a456',
        newPassword: 'segredo123',
      ),
      throwsA(
        isA<AppFailure>().having(
          (f) => f.message,
          'message',
          contains('código'),
        ),
      ),
    );
    expect(
      () => auth.resetPassword(
        email: 'bruno@example.com',
        code: '123 456',
        newPassword: '123',
      ),
      throwsA(
        isA<AppFailure>().having((f) => f.message, 'message', contains('6')),
      ),
    );
    expect(() => auth.changePassword('abc'), throwsA(isA<AppFailure>()));
  });

  test('an expired code and a repeated password are explained', () {
    expect(
      authMessage(
        const AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
      ),
      contains('Peça um novo código'),
    );
    expect(
      authMessage(
        const AuthApiException(
          'New password should be different',
          statusCode: '422',
          code: 'same_password',
        ),
      ),
      contains('diferente'),
    );
  });

  testWidgets('asks for the email, then the code and the new password', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final fake = FakeAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ForgotPasswordPage(email: 'bruno@example.com'),
        ),
      ),
    );

    expect(find.text('bruno@example.com'), findsOneWidget);
    expect(find.text('Código'), findsNothing);
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(fake.sentTo, ['bruno@example.com']);
    expect(find.textContaining('enviamos um código'), findsOneWidget);
    expect(find.text('Reenviar o código em 60 s'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Código'), '123456');
    await tester.enterText(
      find.widgetWithText(TextField, 'Senha nova'),
      'segredo123',
    );
    await tester.tap(find.text('Salvar a senha nova'));
    await tester.pump();
    expect(fake.resets, [('bruno@example.com', '123456', 'segredo123')]);

    // After a minute, another code can be asked for.
    await tester.pump(const Duration(seconds: 61));
    expect(find.text('Reenviar o código'), findsOneWidget);
  });
}
