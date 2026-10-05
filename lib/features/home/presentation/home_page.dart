import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/features/pets/presentation/pets_page.dart';

/// What matters today. For now it lists the pets; reminders arrive with Saúde.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(petsHomeProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: const [NotificationsButton()],
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Não foi possível ler os pets salvos no celular.'),
        ),
        data: (data) {
          if (data.pets.isEmpty && data.invites.isEmpty) {
            return EmptyState(
              icon: LucideIcons.pawPrint,
              title: 'Boas-vindas ao Bowie',
              message:
                  'Comece cadastrando o seu pet. Depois, convide quem cuida dele com você.',
              action: FilledButton(
                onPressed: () => context.push('/pets/new'),
                child: const Text('Cadastrar pet'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(BowieSpacing.s4),
            children: [
              for (final invite in data.invites) ...[
                BowieCard(
                  onTap: () => context.go('/pets'),
                  child: ListTile(
                    leading: Icon(LucideIcons.mail, color: colors.info),
                    title: Text(
                      'Convite para cuidar de ${invite.petName}',
                      style: BowieType.bodyStrong,
                    ),
                    subtitle: const Text('Toque para ver e aceitar.'),
                  ),
                ),
                const SizedBox(height: BowieSpacing.s3),
              ],
              for (final pet in data.pets) ...[
                BowieCard(
                  onTap: () => context.push('/pets/${pet.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(BowieSpacing.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: BowieType.title2.copyWith(color: colors.text),
                        ),
                        const SizedBox(height: BowieSpacing.s2),
                        Text(
                          'Os lembretes de vacinas e remédios de ${pet.name} vão aparecer aqui.',
                          style: BowieType.callout.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: BowieSpacing.s3),
              ],
            ],
          );
        },
      ),
    );
  }
}
