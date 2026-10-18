import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';

/// "Confirme o seu email": the 6-digit code sent at sign up, typed here. No
/// link to open, so it works without opening the app from an email.
/// Confirming signs the person in, and the app opens.
class ConfirmEmailPage extends ConsumerStatefulWidget {
  const ConfirmEmailPage({
    super.key,
    required this.email,
    this.justSent = false,
  });

  final String email;

  /// True right after sign up: the code is on its way, so "Reenviar" waits.
  final bool justSent;

  @override
  ConsumerState<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends ConsumerState<ConfirmEmailPage> {
  final _code = TextEditingController();
  var _busy = false;
  String? _error;
  String? _notice;
  var _wait = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.justSent) _startWait();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirme o seu email'),
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
              widget.justSent
                  ? 'Enviamos um código de 6 números para ${widget.email}. '
                        'Digite aqui para confirmar a conta. Confira também a '
                        'caixa de spam.'
                  : 'A conta ${widget.email} ainda não foi confirmada. Digite '
                        'o código que enviamos, ou peça um novo.',
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s6),
            TextField(
              controller: _code,
              enabled: !_busy,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirm(),
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Código',
                counterText: '',
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
              onPressed: _busy ? null : _confirm,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar'),
            ),
            const SizedBox(height: BowieSpacing.s2),
            TextButton(
              onPressed: _busy || _wait > 0 ? null : _resend,
              child: Text(
                _wait > 0
                    ? 'Reenviar o código em $_wait s'
                    : 'Reenviar o código',
              ),
            ),
          ],
        ),
      ),
    );
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

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(widget.email);
      if (!mounted) return;
      setState(() => _notice = 'Enviamos um código novo.');
      _startWait();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    // Read now: once the code is accepted the session starts and this page
    // goes away.
    final auth = ref.read(authRepositoryProvider);
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await auth.confirmEmail(email: widget.email, code: _code.text);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
