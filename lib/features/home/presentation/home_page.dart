import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/health/presentation/status_badge.dart';
import 'package:bowie/features/pets/presentation/pet_photo.dart';
import 'package:bowie/features/pets/presentation/pet_summary.dart';
import 'package:bowie/features/pets/presentation/pets_page.dart';

/// What matters today: each pet with its most urgent vaccine.
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
                PetPhotoCard(
                  pet: pet,
                  large: true,
                  subtitle: petSummary(pet, DateTime.now()),
                  below: _NextVaccine(petId: pet.id),
                  onTap: () => context.push('/pets/${pet.id}'),
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

/// The most urgent vaccine of a pet, or an invitation to register one.
class _NextVaccine extends ConsumerWidget {
  const _NextVaccine({required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(vaccineGroupsProvider(petId)).asData?.value;
    final today = ref.watch(healthRepositoryProvider).today;
    final colors = context.colors;
    if (groups == null) return const SizedBox.shrink();
    if (groups.isEmpty) {
      return Text(
        'Nenhuma vacina registrada ainda. Registre na aba Saúde.',
        style: BowieType.callout.copyWith(color: colors.textMuted),
      );
    }
    final next = groups.first;
    return StatusBadge(
      status: next.statusOn(today),
      text: '${next.name}: ${describeDue(next.latest.nextDueOn, today)}',
    );
  }
}
