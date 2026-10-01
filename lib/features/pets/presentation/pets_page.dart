import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/presentation/sign_out.dart';
import 'package:bowie/features/pets/data/pet_sync_controller.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pets'),
        actions: [
          IconButton(
            tooltip: sync.syncing ? 'Syncing' : 'Sync',
            onPressed: sync.syncing
                ? null
                : () => ref.read(syncControllerProvider.notifier).sync(),
            icon: sync.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          TextButton(
            onPressed: () => signOut(ref),
            child: const Text('Sign out'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pets/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add pet'),
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            const Center(child: Text('Could not read pets on this device.')),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              if (sync.message != null) ...[
                _SyncBanner(status: sync),
                const SizedBox(height: 16),
              ],
              if (data.invites.isNotEmpty) ...[
                Text('Invitations', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final invite in data.invites) ...[
                  _InviteCard(invite: invite),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 16),
              ],
              if (data.pets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 72),
                  child: Column(
                    children: [
                      Text('No pets yet', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Add a pet, then invite the other people who care for them.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final pet in data.pets)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(pet.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/pets/${pet.id}'),
                  ),
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
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(invite.petName),
        subtitle: const Text('You are invited to care for this pet.'),
        trailing: TextButton(
          onPressed: () => _accept(context, ref),
          child: const Text('Accept'),
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
    final scheme = Theme.of(context).colorScheme;
    final failed = status.failed;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: failed ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          status.message ?? '',
          style: TextStyle(
            color: failed
                ? scheme.onErrorContainer
                : scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
