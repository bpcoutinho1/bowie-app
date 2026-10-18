import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Which "Continuar com…" buttons the app shows. Each one only appears once
/// it is configured (docs/guias/login-social.md), so the app keeps working
/// before that.
class SocialConfig {
  const SocialConfig({
    this.googleIosClientId = '',
    this.googleWebClientId = '',
    this.appleEnabled = false,
    this._iOS,
  });

  factory SocialConfig.fromEnvironment() => const SocialConfig(
    googleIosClientId: String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
    googleWebClientId: String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    appleEnabled: bool.fromEnvironment('SIGN_IN_WITH_APPLE'),
  );

  /// The iOS OAuth client of the Google Cloud project.
  final String googleIosClientId;

  /// The Web OAuth client: the one Supabase checks the token against.
  final String googleWebClientId;

  /// On only after the Apple Developer Program is paid and the "Sign in
  /// with Apple" capability is added in Xcode.
  final bool appleEnabled;

  /// The phone's system; set only in tests.
  final bool? _iOS;
  bool get _onIOS => _iOS ?? Platform.isIOS;

  bool get google =>
      googleWebClientId.isNotEmpty && (!_onIOS || googleIosClientId.isNotEmpty);

  /// Apple sign-in is offered on the iPhone only.
  bool get apple => appleEnabled && _onIOS;
}

enum SocialProvider { google, apple }

/// What Google or Apple returns, for Supabase to check.
class SocialToken {
  const SocialToken({
    required this.provider,
    required this.idToken,
    this.nonce,
    this.name,
  });

  final SocialProvider provider;
  final String idToken;

  /// The raw nonce whose hash went to Apple.
  final String? nonce;

  /// Apple sends the name only the first time.
  final String? name;
}

/// Shows the Google or Apple sign-in. Null when the person cancels.
abstract interface class SocialSignIn {
  Future<SocialToken?> google();

  Future<SocialToken?> apple();
}

class NativeSocialSignIn implements SocialSignIn {
  NativeSocialSignIn(this._config);

  final SocialConfig _config;
  Future<void>? _googleReady;

  @override
  Future<SocialToken?> google() async {
    final google = GoogleSignIn.instance;
    _googleReady ??= google.initialize(
      clientId: Platform.isIOS ? _config.googleIosClientId : null,
      serverClientId: _config.googleWebClientId,
    );
    await _googleReady;
    try {
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return null;
      return SocialToken(provider: SocialProvider.google, idToken: idToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<SocialToken?> apple() async {
    // Apple gets the hash; Supabase gets the raw value and compares.
    final nonce = _rawNonce();
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(nonce)).toString(),
      );
      final idToken = credential.identityToken;
      if (idToken == null) return null;
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().join(' ').trim();
      return SocialToken(
        provider: SocialProvider.apple,
        idToken: idToken,
        nonce: nonce,
        name: name.isEmpty ? null : name,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  static String _rawNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
