import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

final petDetailsProvider = FutureProvider.autoDispose
    .family<PetDetails?, String>((ref, id) async {
      final repository = ref.watch(petRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.getDetails(id);
    });

class PetPage extends ConsumerStatefulWidget {
  const PetPage({super.key, this.petId});

  final String? petId;

  @override
  ConsumerState<PetPage> createState() => _PetPageState();
}

class _PetPageState extends ConsumerState<PetPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  var _seeded = false;
  var _saving = false;
  var _inviting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final petId = widget.petId;
    final asyncDetails = petId == null
        ? null
        : ref.watch(petDetailsProvider(petId));
    if (asyncDetails case AsyncData(value: final value?) when !_seeded) {
      _seeded = true;
      _name.text = value.pet.name;
    }

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(petId == null ? 'New pet' : 'Pet')),
      body: switch (asyncDetails) {
        null => _form(context, details: null, theme: theme),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => const Center(
          child: Text('Could not read this pet on this device.'),
        ),
        AsyncData(value: final PetDetails details) => _form(
          context,
          details: details,
          theme: theme,
        ),
        AsyncData() => const Center(
          child: Text('This pet is not on this device.'),
        ),
      },
    );
  }

  Widget _form(
    BuildContext context, {
    required PetDetails? details,
    required ThemeData theme,
  }) {
    final user = ref.watch(currentUserProvider);
    final owner = details != null && user != null && _isOwner(details, user);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : () => _save(details),
          child: Text(_saving ? 'Saving' : 'Save'),
        ),
        if (details != null) ...[
          const SizedBox(height: 32),
          Text('People', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final tutor in details.tutors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tutor.email),
              subtitle: Text(_label(tutor)),
            ),
          if (owner) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              enabled: !_inviting,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Invite by email'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _inviting ? null : () => _invite(details),
              child: Text(_inviting ? 'Inviting' : 'Invite'),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _save(PetDetails? details) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(petRepositoryProvider);
    try {
      if (details == null) {
        final pet = await repository.createPet(name: _name.text, owner: user);
        if (!mounted) return;
        context.go('/pets/${pet.id}');
      } else {
        await repository.renamePet(
          petId: details.pet.id,
          name: _name.text,
          byUser: user,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name saved')));
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _invite(PetDetails details) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _inviting = true;
      _error = null;
    });
    try {
      await ref
          .read(petRepositoryProvider)
          .inviteTutor(petId: details.pet.id, email: _email.text, byUser: user);
      _email.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation saved on this device')),
      );
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  bool _isOwner(PetDetails details, AppUser user) {
    final email = normalizeEmail(user.email);
    return details.tutors.any(
      (tutor) =>
          tutor.role == PetRole.owner &&
          tutor.status == TutorStatus.accepted &&
          tutor.email == email &&
          tutor.deletedAt == null,
    );
  }

  String _label(PetTutor tutor) {
    if (tutor.role == PetRole.owner) return 'Owner';
    if (tutor.status == TutorStatus.pending) return 'Invited';
    return 'Tutor';
  }
}
