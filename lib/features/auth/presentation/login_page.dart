import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
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
          setState(() {
            _creating = false;
            _notice =
                'Enviamos um link para o seu email. Confirme a conta e depois entre.';
          });
        }
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
