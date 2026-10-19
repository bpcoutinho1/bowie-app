import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/presentation/sign_out.dart';
import 'package:bowie/features/contacts/domain/contact.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/features/plans/domain/account_plan.dart';
import 'package:bowie/features/plans/presentation/plan_providers.dart';
import 'package:bowie/features/plans/presentation/premium_sheet.dart';

/// "Minha conta": name and cell phone, the email, and signing out.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  late final _name = TextEditingController(
    text: ref.read(currentUserProvider)?.name,
  );
  late final _phone = TextEditingController(
    text: switch (ref.read(currentUserProvider)?.phone) {
      final String phone => formatPhone(phone),
      null => null,
    },
  );
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final colors = context.colors;
    const gap = SizedBox(height: BowieSpacing.s3);
    return Scaffold(
      appBar: AppBar(title: const Text('Minha conta')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          if (user != null && !user.profileComplete) ...[
            Text(
              'Complete o seu cadastro. O seu nome e o celular aparecem para '
              'quem cuida do pet com você e na ficha que você compartilhar.',
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s4),
          ],
          AutofillGroup(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  enabled: !_saving,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                gap,
                TextField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Celular',
                    hintText: '(11) 98765-4321',
                  ),
                ),
              ],
            ),
          ),
          gap,
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.mail, color: colors.textMuted),
            title: const Text('Email'),
            subtitle: Text(user?.email ?? ''),
          ),
          if (_error != null) ...[
            gap,
            Text(
              _error!,
              style: BowieType.callout.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: BowieSpacing.s6),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Salvando' : 'Salvar'),
          ),
          const SizedBox(height: BowieSpacing.s8),
          const _PlanSection(),
          const SizedBox(height: BowieSpacing.s8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _changePassword,
            icon: const Icon(LucideIcons.keyRound),
            label: const Text('Trocar a senha'),
          ),
          const SizedBox(height: BowieSpacing.s3),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => signOut(ref),
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Sair da conta'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => const _PasswordDialog(),
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Senha trocada')));
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .updateProfile(name: _name.text, phone: _phone.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dados salvos')));
      Navigator.of(context).maybePop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trocar a senha'),
      content: TextField(
        controller: _password,
        enabled: !_busy,
        autofocus: true,
        obscureText: true,
        autofillHints: const [AutofillHints.newPassword],
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Senha nova',
          helperText: 'Pelo menos 6 caracteres.',
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Salvando' : 'Salvar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(_password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// "Seu plano": the tier and, on the free plan, how much of each limit is
/// used.
class _PlanSection extends ConsumerWidget {
  const _PlanSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final usage = ref.watch(planUsageProvider).asData?.value;
    if (usage == null || !usage.plan.known) return const SizedBox.shrink();
    final plan = usage.plan;
    final title = switch (plan.tier) {
      PlanTier.free => 'Grátis',
      PlanTier.trial =>
        'Premium · teste grátis até ${formatDayBr(plan.trialEndsAt!.toLocal())}',
      PlanTier.premium =>
        plan.premiumUntil == null
            ? 'Premium'
            : 'Premium até ${formatDayBr(plan.premiumUntil!.toLocal())}',
    };
    Widget line(String label, int used, int total) => Padding(
      padding: const EdgeInsets.only(top: BowieSpacing.s2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: BowieType.callout.copyWith(color: colors.textMuted),
            ),
          ),
          Text(
            '${used > total ? total : used} de $total',
            style: BowieType.bodyStrong.copyWith(
              color: used >= total ? colors.warning : colors.text,
            ),
          ),
        ],
      ),
    );

    return BowieCard(
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Seu plano',
              style: BowieType.caption.copyWith(color: colors.textMuted),
            ),
            Text(title, style: BowieType.title3.copyWith(color: colors.text)),
            if (!plan.isPremium) ...[
              line('Pets', usage.pets, freePetLimit),
              line('Fotos lidas pela IA', plan.aiPhotosUsed, freeAiPhotos),
              line(
                'Fotos e PDFs enviados ao diário',
                plan.diaryFilesUsed,
                freeDiaryFiles,
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: BowieSpacing.s2),
                child: Text(
                  'Até $premiumPetLimit pets, leitura por IA e arquivos no '
                  'diário sem limite.',
                  style: BowieType.callout.copyWith(color: colors.textMuted),
                ),
              ),
            if (plan.tier != PlanTier.premium) ...[
              const SizedBox(height: BowieSpacing.s3),
              OutlinedButton(
                onPressed: () => showPremiumSheet(context),
                child: const Text('Conhecer o Premium'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
