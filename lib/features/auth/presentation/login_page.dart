import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/data/auth_repository.dart';
import 'package:bowie/features/auth/data/social_sign_in.dart';
import 'package:bowie/core/ui/bowie_logo.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _creating = false;
  var _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configProblem = ref.watch(appConfigProvider).problem;
    final configured = configProblem == null;
    final colors = context.colors;
    final social = ref.watch(socialConfigProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            BowieSpacing.s6,
            BowieSpacing.s12,
            BowieSpacing.s6,
            BowieSpacing.s6,
          ),
          children: [
            const Center(child: BowieLogo(height: 144, tagline: true)),
            const SizedBox(height: BowieSpacing.s8),
            Text(
              _creating ? 'Criar conta' : 'Entrar',
              style: BowieType.title1.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s2),
            Text(
              _creating
                  ? 'O seu nome e o celular aparecem para quem cuida do pet '
                        'com você.'
                  : 'Use o email e a senha da sua conta.',
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
            if (configProblem != null) ...[
              const SizedBox(height: BowieSpacing.s6),
              Text(
                configProblem,
                style: BowieType.callout.copyWith(color: colors.textMuted),
              ),
            ],
            const SizedBox(height: BowieSpacing.s8),
            AutofillGroup(
              child: Column(
                children: [
                  if (_creating) ...[
                    TextField(
                      controller: _name,
                      enabled: configured && !_busy,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nome'),
                    ),
                    const SizedBox(height: BowieSpacing.s3),
                    TextField(
                      controller: _phone,
                      enabled: configured && !_busy,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Celular',
                        hintText: '(11) 98765-4321',
                      ),
                    ),
                    const SizedBox(height: BowieSpacing.s3),
                  ],
                  TextField(
                    controller: _email,
                    enabled: configured && !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: BowieSpacing.s3),
                  TextField(
                    controller: _password,
                    enabled: configured && !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Senha'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: BowieSpacing.s4),
              Text(
                _error!,
                style: BowieType.callout.copyWith(color: colors.danger),
              ),
            ],
            if (_notice != null) ...[
              const SizedBox(height: BowieSpacing.s4),
              Text(_notice!, style: BowieType.callout),
            ],
            const SizedBox(height: BowieSpacing.s6),
            FilledButton(
              onPressed: configured && !_busy ? _submit : null,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_creating ? 'Criar conta' : 'Entrar'),
            ),
            if (social.apple || social.google) ...[
              const SizedBox(height: BowieSpacing.s4),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: BowieSpacing.s3,
                    ),
                    child: Text(
                      'ou',
                      style: BowieType.callout.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: BowieSpacing.s4),
              if (social.apple) ...[
                // Apple asks for its own button, black or white.
                SignInWithAppleButton(
                  text: 'Continuar com a Apple',
                  height: 48,
                  style: Theme.of(context).brightness == Brightness.dark
                      ? SignInWithAppleButtonStyle.white
                      : SignInWithAppleButtonStyle.black,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(BowieRadius.md),
                  ),
                  onPressed: () {
                    if (!_busy) _social(SocialProvider.apple);
                  },
                ),
                const SizedBox(height: BowieSpacing.s3),
              ],
              if (social.google)
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _social(SocialProvider.google),
                  child: const Text('Continuar com o Google'),
                ),
              const SizedBox(height: BowieSpacing.s2),
            ],
            if (!_creating)
              TextButton(
                onPressed: _busy || !configured
                    ? null
                    : () => context.go(
                        Uri(
                          path: '/recuperar-senha',
                          queryParameters: {
                            if (_email.text.trim().isNotEmpty)
                              'email': _email.text.trim(),
                          },
                        ).toString(),
                      ),
                child: const Text('Esqueci minha senha'),
              ),
            const SizedBox(height: BowieSpacing.s2),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _creating = !_creating;
                        _error = null;
                        _notice = null;
                      });
                    },
              child: Text(
                _creating
                    ? 'Já tem conta? Entrar'
                    : 'Ainda não tem conta? Criar conta',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Google or Apple: no password, and the account is made on the first
  /// time. Name and phone are asked afterwards, in "Complete o seu cadastro".
  Future<void> _social(SocialProvider provider) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final social = ref.read(socialSignInProvider);
    final auth = ref.read(authRepositoryProvider);
    try {
      final token = switch (provider) {
        SocialProvider.google => await social.google(),
        SocialProvider.apple => await social.apple(),
      };
      if (token == null) return;
      await auth.signInWithToken(token);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = switch (provider) {
            SocialProvider.google =>
              'Não foi possível entrar com o Google. Tente de novo.',
            SocialProvider.apple =>
              'Não foi possível entrar com a Apple. Tente de novo.',
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _confirm({required bool justSent}) {
    context.go(
      Uri(
        path: '/confirmar-email',
        queryParameters: {
          'email': _email.text.trim(),
          if (justSent) 'enviado': '1',
        },
      ).toString(),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_creating) {
        final needsConfirmation = await auth.signUp(
          name: _name.text,
          phone: _phone.text,
          email: _email.text,
          password: _password.text,
        );
        if (needsConfirmation && mounted) {
          _confirm(justSent: true);
        }
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
    } on EmailNotConfirmed {
      if (mounted) _confirm(justSent: false);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
