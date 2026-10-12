import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';

/// "Esqueci minha senha": an emailed code, typed here with the new
/// password. No link to open, so it works without a domain or deep links.
/// Saving signs the person in, and the app opens (after the device unlock).
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key, this.email});

  /// Brought from the login form, when already typed there.
  final String? email;

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  var _codeSent = false;
  var _busy = false;
  var _hidden = true;
  String? _error;

  /// Seconds before another code can be asked for.
  var _wait = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const gap = SizedBox(height: BowieSpacing.s3);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar a senha'),
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            BowieSpacing.s6,
            BowieSpacing.s4,
            BowieSpacing.s6,
            BowieSpacing.s6,
          ),
          children: [
            Text(
              _codeSent
                  ? 'Se houver uma conta com ${_email.text.trim()}, enviamos '
                        'um código de 6 números para lá. Confira também a '
                        'caixa de spam.'
                  : 'Digite o email da sua conta. Vamos enviar um código para '
                        'você criar uma senha nova.',
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s6),
            TextField(
              controller: _email,
              enabled: !_busy && !_codeSent,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _codeSent ? null : _send(),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            if (_codeSent) ...[
              gap,
              TextField(
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.next,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  counterText: '',
                ),
              ),
              gap,
              TextField(
                controller: _password,
                enabled: !_busy,
                obscureText: _hidden,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _reset(),
                decoration: InputDecoration(
                  labelText: 'Senha nova',
                  helperText: 'Pelo menos 6 caracteres.',
                  suffixIcon: IconButton(
                    tooltip: _hidden ? 'Mostrar a senha' : 'Esconder a senha',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(_hidden ? LucideIcons.eye : LucideIcons.eyeOff),
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: BowieSpacing.s4),
              Text(
                _error!,
                style: BowieType.callout.copyWith(color: colors.danger),
              ),
            ],
            const SizedBox(height: BowieSpacing.s6),
            FilledButton(
              onPressed: _busy ? null : (_codeSent ? _reset : _send),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_codeSent ? 'Salvar a senha nova' : 'Enviar código'),
            ),
            if (_codeSent) ...[
              const SizedBox(height: BowieSpacing.s2),
              TextButton(
                onPressed: _busy || _wait > 0 ? null : _send,
                child: Text(
                  _wait > 0
                      ? 'Reenviar o código em $_wait s'
                      : 'Reenviar o código',
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _error = null;
                        _code.clear();
                      }),
                child: const Text('Usar outro email'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordCode(_email.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startWait();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startWait() {
    _timer?.cancel();
    setState(() => _wait = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _wait--);
      if (_wait <= 0) timer.cancel();
    });
  }

  Future<void> _reset() async {
    // Read now: once the code is accepted the session starts and this page
    // goes away.
    final auth = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.resetPassword(
        email: _email.text,
        code: _code.text,
        newPassword: _password.text,
      );
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
