import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/core/error/app_failure.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _creating = false;
  var _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(appConfigProvider).isConfigured;
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Text('Bowie', style: theme.textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
              _creating
                  ? 'Create an account with the email you want to use.'
                  : 'Sign in with the email you use for this account.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!configured) ...[
              const SizedBox(height: 24),
              Text(
                'This build has no Supabase project yet. Copy dart_defines.example.json to dart_defines.json, add the project URL and anon key, then run with --dart-define-from-file=dart_defines.json.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 32),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    enabled: configured && !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: configured && !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 16),
              Text(_notice!),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: configured && !_busy ? _submit : null,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_creating ? 'Create account' : 'Sign in'),
            ),
            const SizedBox(height: 8),
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
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
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
          email: _email.text,
          password: _password.text,
        );
        if (needsConfirmation && mounted) {
          setState(() {
            _creating = false;
            _notice = 'Check your email to confirm the account, then sign in.';
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
