import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/features/auth/presentation/sign_out.dart';
import 'package:bowie/features/pets/data/pet_sync_controller.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';
import 'package:bowie/features/pets/presentation/pet_photo.dart';
import 'package:bowie/features/pets/presentation/pet_summary.dart';

class PetsHome {
  const PetsHome({required this.pets, required this.invites});

  final List<Pet> pets;
  final List<TutorInvite> invites;
}

final petsHomeProvider = FutureProvider.autoDispose<PetsHome>((ref) async {
  final repository = ref.watch(petRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  final changes = repository.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(changes.cancel);
  if (user == null) return const PetsHome(pets: [], invites: []);
  return PetsHome(
    pets: await repository.listPetsFor(user.email),
    invites: await repository.listInvites(user.email),
  );
});

class PetsPage extends ConsumerWidget {
  const PetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(petsHomeProvider);
    final sync = ref.watch(syncControllerProvider);
    final theme = Theme.of(context);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets'),
        actions: [
          IconButton(
            tooltip: sync.syncing ? 'Sincronizando' : 'Sincronizar',
            onPressed: sync.syncing
                ? null
                : () => ref.read(syncControllerProvider.notifier).sync(),
            icon: sync.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.refreshCw),
          ),
          TextButton(onPressed: () => signOut(ref), child: const Text('Sair')),
          const NotificationsButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pets/new'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Adicionar pet'),
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => const Center(
          child: Text('Não foi possível ler os pets salvos no celular.'),
        ),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              BowieSpacing.s4,
              BowieSpacing.s2,
              BowieSpacing.s4,
              96,
            ),
            children: [
              if (sync.message != null) ...[
                _SyncBanner(status: sync),
                const SizedBox(height: 16),
              ],
              BowieCard(
                onTap: () => context.push('/pets/contatos'),
                child: ListTile(
                  leading: Icon(LucideIcons.bookUser, color: colors.text),
                  title: Text('Contatos', style: BowieType.bodyStrong),
                  subtitle: const Text(
                    'Veterinários, creche, hotelzinho e mais',
                  ),
                  trailing: const Icon(LucideIcons.chevronRight),
                ),
              ),
              const SizedBox(height: BowieSpacing.s4),
              if (data.invites.isNotEmpty) ...[
                Text('Convites', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final invite in data.invites) ...[
                  _InviteCard(invite: invite),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
              ],
              if (data.pets.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: BowieSpacing.s12),
                  child: EmptyState(
                    icon: LucideIcons.pawPrint,
                    title: 'Nenhum pet ainda',
                    message:
                        'Cadastre um pet e depois convide as pessoas que cuidam dele com você.',
                  ),
                )
              else
                for (final pet in data.pets) ...[
                  PetPhotoCard(
                    pet: pet,
                    subtitle: petSummary(pet, DateTime.now()),
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

class _InviteCard extends ConsumerWidget {
  const _InviteCard({required this.invite});

  final TutorInvite invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BowieCard(
      child: ListTile(
        title: Text(invite.petName, style: BowieType.bodyStrong),
        subtitle: const Text('Você recebeu um convite para cuidar deste pet.'),
        trailing: TextButton(
          onPressed: () => _accept(context, ref),
          child: const Text('Aceitar'),
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(petRepositoryProvider)
          .acceptInvite(tutorId: invite.tutor.id, user: user);
    } on AppFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final failed = status.failed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: failed ? colors.dangerSoft : colors.infoSoft,
        borderRadius: BorderRadius.circular(BowieRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s3),
        child: Row(
          children: [
            Icon(
              failed ? LucideIcons.circleAlert : LucideIcons.info,
              color: failed ? colors.danger : colors.info,
            ),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Text(
                status.message ?? '',
                style: BowieType.callout.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
