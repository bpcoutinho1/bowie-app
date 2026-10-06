import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/ui/bowie_logo.dart';
import 'package:bowie/features/auth/presentation/sign_out.dart';

class UnlockPage extends ConsumerStatefulWidget {
  const UnlockPage({super.key});

  @override
  ConsumerState<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends ConsumerState<UnlockPage> {
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BowieSpacing.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Center(child: BowieLogo(height: 144, tagline: true)),
              const SizedBox(height: BowieSpacing.s8),
              Text(
                'Desbloquear',
                style: BowieType.title1.copyWith(color: colors.text),
              ),
              const SizedBox(height: BowieSpacing.s2),
              Text(
                'Use a biometria ou o código de bloqueio do celular.',
                style: BowieType.body.copyWith(color: colors.textMuted),
              ),
              if (_error != null) ...[
                const SizedBox(height: BowieSpacing.s4),
                Text(
                  _error!,
                  style: BowieType.callout.copyWith(color: colors.danger),
                ),
              ],
              const SizedBox(height: BowieSpacing.s6),
              FilledButton(
                onPressed: _busy ? null : _unlock,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Desbloquear'),
              ),
              const SizedBox(height: BowieSpacing.s2),
              TextButton(
                onPressed: _busy ? null : () => signOut(ref),
                child: const Text('Sair da conta'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(deviceLockProvider).unlock();
      ref.read(unlockedProvider.notifier).unlock();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
