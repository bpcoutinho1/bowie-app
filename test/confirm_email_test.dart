import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/router.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/config/app_config.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/data/auth_repository.dart';
import 'package:bowie/features/auth/presentation/confirm_email_page.dart';
import 'package:bowie/features/auth/presentation/login_page.dart';

/// Records the calls instead of reaching Supabase.
class FakeAuth extends AuthRepository {
  FakeAuth({this.unconfirmed = false}) : super(null);

  final bool unconfirmed;
  final confirmed = <(String, String)>[];
  final resent = <String>[];

  @override
  bool get isConfigured => true;

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (unconfirmed) throw const EmailNotConfirmed();
  }

  @override
  Future<void> confirmEmail({
    required String email,
    required String code,
  }) async => confirmed.add((email, code));

  @override
  Future<void> resendConfirmation(String email) async => resent.add(email);
}

void main() {
  const auth = AuthRepository(null);

  test('a code that is not 6 to 10 digits never leaves the phone', () {
    expect(
      () => auth.confirmEmail(email: 'bruno@example.com', code: '12 34'),
      throwsA(
        isA<AppFailure>().having(
          (f) => f.message,
          'message',
          contains('código'),
        ),
      ),
    );
    expect(() => auth.resendConfirmation('bruno@'), throwsA(isA<AppFailure>()));
  });

  test('the confirmation screen is reachable signed out', () {
    expect(redirectFor(AuthGate.signedOut, '/confirmar-email'), isNull);
    expect(redirectFor(AuthGate.ready, '/confirmar-email'), homeLocation);
  });

  testWidgets('right after sign up, the code is typed and resent later', (
    tester,
  ) async {
    final fake = FakeAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const ConfirmEmailPage(
            email: 'bruno@example.com',
            justSent: true,
          ),
        ),
      ),
    );
    expect(find.textContaining('Enviamos um código'), findsOneWidget);
    expect(find.text('Reenviar o código em 60 s'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    expect(fake.confirmed, [('bruno@example.com', '123456')]);

    await tester.pump(const Duration(seconds: 61));
    await tester.tap(find.text('Reenviar o código'));
    await tester.pump();
    expect(fake.resent, ['bruno@example.com']);
    expect(find.text('Enviamos um código novo.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('signing in to an unconfirmed account opens the code screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/confirmar-email',
          builder: (context, state) => ConfirmEmailPage(
            email: state.uri.queryParameters['email'] ?? '',
            justSent: state.uri.queryParameters['enviado'] == '1',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuth(unconfirmed: true)),
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://example.supabase.co',
              supabaseAnonKey: 'sb_publishable_test',
            ),
          ),
        ],
        child: MaterialApp.router(
          theme: buildTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      'bruno@example.com',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Senha'), 'segredo');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Confirme o seu email'), findsOneWidget);
    expect(
      find.textContaining('A conta bruno@example.com ainda não foi confirmada'),
      findsOneWidget,
    );
  });
}
