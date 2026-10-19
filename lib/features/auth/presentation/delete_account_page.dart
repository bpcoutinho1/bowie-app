import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/ui/choice_field.dart';
import 'package:bowie/features/auth/data/account_eraser.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/auth/presentation/sign_out.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

final accountEraserProvider = Provider<AccountEraser?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseAccountEraser(client);
});

/// A pet of the person and, when it has them, the tutors who can keep it.
typedef PetHeirs = ({Pet pet, List<PetTutor> heirs});

/// What deleting the account does to the person's pets: the ones they are the
/// main tutor of (with the tutors who could keep each) and how many others
/// they only take part in.
typedef AccountPets = ({List<PetHeirs> owned, int member});

Future<AccountPets> accountPets(PetLocalStore store, AppUser user) async {
  final email = normalizeEmail(user.email);
  final owned = <PetHeirs>[];
  var member = 0;
  for (final pet in await store.listPetsFor(email)) {
    final tutors = await store.listTutors(pet.id);
    final mine = tutors.any(
      (tutor) =>
          tutor.role == PetRole.owner &&
          tutor.status == TutorStatus.accepted &&
          tutor.email == email &&
          tutor.deletedAt == null,
    );
    if (!mine) {
      member++;
      continue;
    }
    owned.add((
      pet: pet,
      heirs: [
        for (final tutor in tutors)
          if (tutor.role == PetRole.tutor &&
              tutor.status == TutorStatus.accepted &&
              tutor.userId != null &&
              tutor.email != email &&
              tutor.deletedAt == null)
            tutor,
      ],
    ));
  }
  return (owned: owned, member: member);
}

final _accountPetsProvider = FutureProvider.autoDispose<AccountPets>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return (owned: <PetHeirs>[], member: 0);
  return accountPets(ref.watch(petLocalStoreProvider), user);
});

/// "Bowie", "Bowie e Mia", "Bowie, Mia e Thor".
String joinNames(List<String> names) {
  if (names.length <= 1) return names.join();
  return '${names.sublist(0, names.length - 1).join(', ')} e ${names.last}';
}

/// "Excluir minha conta": what goes, who keeps each shared pet, and a
/// confirmation that the deletion is permanent.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  /// Pet id → pet_tutors id of who keeps it.
  final _heirs = <String, String>{};
  var _understood = false;
  var _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pets = ref.watch(_accountPetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Excluir conta')),
      body: switch (pets) {
        AsyncData(:final value) => _body(context, colors, value),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(BowieSpacing.s4),
            child: Text(
              'Não foi possível carregar os seus pets. Tente de novo.',
              textAlign: TextAlign.center,
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _body(BuildContext context, BowieColors colors, AccountPets pets) {
    final alone = [
      for (final owned in pets.owned)
        if (owned.heirs.isEmpty) owned.pet.name,
    ];
    final shared = [
      for (final owned in pets.owned)
        if (owned.heirs.isNotEmpty) owned,
    ];
    for (final owned in shared) {
      _heirs.putIfAbsent(owned.pet.id, () => owned.heirs.first.id);
    }

    Widget item(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: BowieSpacing.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.textMuted),
          const SizedBox(width: BowieSpacing.s3),
          Expanded(
            child: Text(
              text,
              style: BowieType.body.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: BowieSpacing.s6),
      child: Semantics(
        header: true,
        child: Text(text, style: BowieType.title3.copyWith(color: colors.text)),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BowieSpacing.s4,
        BowieSpacing.s2,
        BowieSpacing.s4,
        BowieSpacing.s8,
      ),
      children: [
        Text(
          'Antes de continuar',
          style: BowieType.title2.copyWith(color: colors.text),
        ),
        const SizedBox(height: BowieSpacing.s2),
        Text(
          'A exclusão da conta é definitiva. Ao confirmar, a sua conta e os '
          'dados ligados a ela serão apagados dos nossos servidores e deste '
          'celular, sem possibilidade de recuperação.',
          style: BowieType.body.copyWith(color: colors.textMuted),
        ),
        heading('O que será apagado'),
        item(
          LucideIcons.userRound,
          'Seus dados de cadastro: nome, email e celular.',
        ),
        item(
          LucideIcons.listChecks,
          'Seu plano, sua lista de compras e seus contatos.',
        ),
        if (alone.isNotEmpty)
          item(
            LucideIcons.pawPrint,
            '${joinNames(alone)}, com todo o histórico: vacinas, remédios, '
            'diário, fotos e documentos.',
          ),
        if (pets.member > 0)
          item(
            LucideIcons.users,
            pets.member == 1
                ? 'Sua participação no pet de outro tutor. O que você '
                      'registrou continua no histórico dele.'
                : 'Sua participação nos ${pets.member} pets de outros '
                      'tutores. O que você registrou continua no histórico '
                      'deles.',
          ),
        if (shared.isNotEmpty) ...[
          heading('Quem fica com cada pet'),
          const SizedBox(height: BowieSpacing.s2),
          Text(
            shared.length == 1
                ? '${shared.single.pet.name} tem outros tutores e continua '
                      'com eles, com todo o histórico. Escolha quem passa a '
                      'ser o tutor principal.'
                : 'Estes pets têm outros tutores e continuam com eles, com '
                      'todo o histórico. Escolha quem passa a ser o tutor '
                      'principal de cada um.',
            style: BowieType.body.copyWith(color: colors.textMuted),
          ),
          for (final owned in shared)
            Padding(
              padding: const EdgeInsets.only(top: BowieSpacing.s4),
              child: ChoiceField<String>(
                label: 'Tutor principal de ${owned.pet.name}',
                value: _heirs[owned.pet.id]!,
                enabled: !_busy,
                options: [
                  for (final tutor in owned.heirs)
                    ChoiceOption(
                      value: tutor.id,
                      label: tutor.email,
                      icon: LucideIcons.userRound,
                    ),
                ],
                onChanged: (id) => setState(() => _heirs[owned.pet.id] = id),
              ),
            ),
        ],
        const SizedBox(height: BowieSpacing.s6),
        CheckboxListTile(
          value: _understood,
          onChanged: _busy
              ? null
              : (value) => setState(() => _understood = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            'Entendo que a exclusão é permanente e que os dados não poderão '
            'ser recuperados.',
            style: BowieType.body.copyWith(color: colors.text),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: BowieSpacing.s3),
          Text(
            _error!,
            style: BowieType.callout.copyWith(color: colors.danger),
          ),
        ],
        const SizedBox(height: BowieSpacing.s4),
        OutlinedButton.icon(
          onPressed: _understood && !_busy ? _erase : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.danger,
            side: BorderSide(
              color: _understood && !_busy ? colors.danger : colors.textMuted,
            ),
          ),
          icon: const Icon(LucideIcons.trash2),
          label: Text(_busy ? 'Excluindo' : 'Excluir minha conta'),
        ),
        const SizedBox(height: BowieSpacing.s2),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Manter minha conta'),
        ),
      ],
    );
  }

  Future<void> _erase() async {
    final eraser = ref.read(accountEraserProvider);
    if (eraser == null) {
      setState(() => _error = 'Este app ainda não está conectado ao servidor.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await eraser.erase(Map.of(_heirs));
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
      return;
    }
    // The account is gone: nothing of it stays on the phone.
    try {
      await ref.read(petLocalStoreProvider).eraseAll();
      await ref.read(petPhotoStoreProvider).eraseAll();
    } catch (_) {}
    if (!mounted) return;
    await signOut(ref);
    messenger.showSnackBar(
      const SnackBar(content: Text('Sua conta foi excluída.')),
    );
  }
}
