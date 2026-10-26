import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/features/notifications/domain/vaccine_notice.dart';
import 'package:bowie/features/notifications/presentation/notices_providers.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/plans/presentation/plan_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(vaccineNoticesProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: notices == null || notices.isEmpty
          ? const EmptyState(
              icon: LucideIcons.bell,
              title: 'Nenhuma notificação por enquanto',
              message:
                  'Convites, lembretes e o que os outros tutores fizerem vão '
                  'aparecer aqui.',
            )
          : ListView(
              padding: const EdgeInsets.all(BowieSpacing.s4),
              children: [
                for (final notice in notices) ...[
                  _VaccineNoticeCard(notice: notice),
                  const SizedBox(height: BowieSpacing.s3),
                ],
              ],
            ),
    );
  }
}

/// "O Bowie ainda não tem todas as vacinas cadastradas", with what is missing
/// and the way to add it.
class _VaccineNoticeCard extends ConsumerWidget {
  const _VaccineNoticeCard({required this.notice});

  final VaccineNotice notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final pet = notice.pet;
    final first = notice.missing.first;
    final reads = ref.watch(canReadCardsProvider).asData?.value ?? false;
    return BowieCard(
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.syringe, color: colors.warning),
                const SizedBox(width: BowieSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.title,
                        style: BowieType.bodyStrong.copyWith(
                          color: colors.text,
                        ),
                      ),
                      const SizedBox(height: BowieSpacing.s1),
                      Text(
                        notice.body,
                        style: BowieType.callout.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: BowieSpacing.s1),
                      Text(
                        'Com as vacinas no app, você recebe um aviso antes de '
                        'cada uma vencer.',
                        style: BowieType.callout.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: BowieSpacing.s4),
            FilledButton.icon(
              onPressed: () => context.push(
                Uri(
                  path: '/saude/doses/nova',
                  queryParameters: {'pet': pet.id, 'nome': ?first.suggestion},
                ).toString(),
              ),
              icon: const Icon(LucideIcons.plus),
              label: Text('Registrar vacina: ${first.label}'),
            ),
            if (reads) ...[
              const SizedBox(height: BowieSpacing.s2),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/saude/carteirinha?pet=${pet.id}'),
                icon: const Icon(LucideIcons.scanText),
                label: const Text('Ler a carteirinha'),
              ),
            ],
            const SizedBox(height: BowieSpacing.s2),
            TextButton(
              onPressed: () => _turnOff(context, ref),
              child: const Text('Não lembrar mais'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    await ref.read(flagsProvider).set(vaccineNoticeOffKey(notice.pet.id));
    ref.invalidate(vaccineNoticesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pronto. O app não lembra mais das vacinas ${ofPet(notice.pet)}.',
        ),
      ),
    );
  }
}
