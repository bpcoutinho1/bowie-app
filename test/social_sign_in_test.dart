import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/config/app_config.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/data/auth_repository.dart';
import 'package:bowie/features/auth/data/social_sign_in.dart';
import 'package:bowie/features/auth/presentation/login_page.dart';

class FakeSocial implements SocialSignIn {
  FakeSocial({this.cancel = false});

  final bool cancel;
  final asked = <SocialProvider>[];

  @override
  Future<SocialToken?> google() async {
    asked.add(SocialProvider.google);
    return cancel
        ? null
        : const SocialToken(provider: SocialProvider.google, idToken: 'g');
  }

  @override
  Future<SocialToken?> apple() async {
    asked.add(SocialProvider.apple);
    return cancel
        ? null
        : const SocialToken(
            provider: SocialProvider.apple,
            idToken: 'a',
            nonce: 'n',
            name: 'Bruno Coutinho',
          );
  }
}

class FakeAuth extends AuthRepository {
  FakeAuth({this.fail = false}) : super(null);

  final bool fail;
  final tokens = <SocialToken>[];

  @override
  Future<void> signInWithToken(SocialToken token) async {
    if (fail) throw const AppFailure('O servidor recusou.');
    tokens.add(token);
  }
}

void main() {
  test('each button appears only once configured', () {
    expect(const SocialConfig(iOS: true).google, isFalse);
    expect(
      const SocialConfig(googleWebClientId: 'web', iOS: true).google,
      isFalse,
      reason: 'the iPhone also needs the iOS client',
    );
    expect(
      const SocialConfig(
        googleWebClientId: 'web',
        googleIosClientId: 'ios',
        iOS: true,
      ).google,
      isTrue,
    );
    expect(
      const SocialConfig(googleWebClientId: 'web', iOS: false).google,
      isTrue,
    );
    expect(const SocialConfig(appleEnabled: true, iOS: false).apple, isFalse);
    expect(const SocialConfig(appleEnabled: true, iOS: true).apple, isTrue);
  });

  Future<void> pump(
    WidgetTester tester, {
    required SocialConfig config,
    required SocialSignIn social,
    required AuthRepository auth,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              supabaseUrl: 'https://example.supabase.co',
              supabaseAnonKey: 'sb_publishable_test',
            ),
          ),
          socialConfigProvider.overrideWithValue(config),
          socialSignInProvider.overrideWithValue(social),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const both = SocialConfig(
    googleWebClientId: 'web',
    googleIosClientId: 'ios',
    appleEnabled: true,
    iOS: true,
  );

  testWidgets('without configuration, only email and password', (tester) async {
    await pump(
      tester,
      config: const SocialConfig(iOS: true),
      social: FakeSocial(),
      auth: FakeAuth(),
    );
    expect(find.text('Continuar com o Google'), findsNothing);
    expect(find.byType(SignInWithAppleButton), findsNothing);
  });

  testWidgets('Google and Apple sign in with their tokens', (tester) async {
    final social = FakeSocial();
    final auth = FakeAuth();
    await pump(tester, config: both, social: social, auth: auth);

    await tester.ensureVisible(find.text('Continuar com o Google'));
    await tester.tap(find.text('Continuar com o Google'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(SignInWithAppleButton));
    await tester.tap(find.byType(SignInWithAppleButton));
    await tester.pumpAndSettle();

    expect(social.asked, [SocialProvider.google, SocialProvider.apple]);
    expect(auth.tokens.map((t) => t.idToken), ['g', 'a']);
    expect(auth.tokens.last.nonce, 'n');
    expect(auth.tokens.last.name, 'Bruno Coutinho');
  });

  testWidgets('a cancel is silent; a refusal is explained', (tester) async {
    final cancelled = FakeAuth();
    await pump(
      tester,
      config: both,
      social: FakeSocial(cancel: true),
      auth: cancelled,
    );
    await tester.ensureVisible(find.text('Continuar com o Google'));
    await tester.tap(find.text('Continuar com o Google'));
    await tester.pumpAndSettle();
    expect(cancelled.tokens, isEmpty);
    expect(find.text('O servidor recusou.'), findsNothing);

    await pump(
      tester,
      config: both,
      social: FakeSocial(),
      auth: FakeAuth(fail: true),
    );
    await tester.ensureVisible(find.text('Continuar com o Google'));
    await tester.tap(find.text('Continuar com o Google'));
    await tester.pumpAndSettle();
    expect(find.text('O servidor recusou.'), findsOneWidget);
  });
}
