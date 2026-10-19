import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
          const _PlanSection(),
          const SizedBox(height: BowieSpacing.s6),
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
          const SizedBox(height: BowieSpacing.s6),
          TextButton.icon(
            onPressed: _saving ? null : () => context.push('/conta/excluir'),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            icon: const Icon(LucideIcons.trash2),
            label: const Text('Excluir minha conta'),
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

/// The plan, first thing on the page: "Conta: Teste grátis do Premium",
/// when it ends and, on the free plan, how much of each limit is used.
/// Always shown, also when the plan could not be read.
class _PlanSection extends ConsumerWidget {
  const _PlanSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(planUsageProvider);
    final usage = state.asData?.value;

    // Label on the left, value on the right; with large text, the value
    // goes to the next line instead of squeezing the label.
    Widget row(String label, String value, {bool warn = false}) => Padding(
      padding: const EdgeInsets.only(top: BowieSpacing.s2),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: BowieSpacing.s3,
        children: [
          Text(
            label,
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
          Text(
            value,
            style: BowieType.bodyStrong.copyWith(
              color: warn ? colors.warning : colors.text,
            ),
          ),
        ],
      ),
    );

    Widget note(String text) => Padding(
      padding: const EdgeInsets.only(top: BowieSpacing.s3),
      child: Text(
        text,
        style: BowieType.callout.copyWith(color: colors.textMuted),
      ),
    );

    Widget card(List<Widget> children) => BowieCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );

    if (usage == null && state.isLoading) {
      return card([row('Conta', 'Carregando…')]);
    }
    if (usage == null || !usage.plan.known) {
      return card([
        row('Conta', 'Não foi possível ver o plano'),
        note('Confira a internet e tente de novo.'),
        const SizedBox(height: BowieSpacing.s3),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(planUsageProvider),
          icon: const Icon(LucideIcons.refreshCw),
          label: const Text('Tentar de novo'),
        ),
      ]);
    }

    final plan = usage.plan;
    // Pets added during the trial stay: then the count is over the limit.
    String count(int used, int total) =>
        used > total ? '$used (limite: $total)' : '$used de $total';

    return card([
      ...switch (plan.tier) {
        PlanTier.free => [
          row('Conta', 'Grátis'),
          row(
            'Pets',
            count(usage.pets, freePetLimit),
            warn: usage.pets >= freePetLimit,
          ),
          row(
            'Fotos lidas pela IA',
            count(plan.aiPhotosUsed, freeAiPhotos),
            warn: plan.aiPhotosUsed >= freeAiPhotos,
          ),
          row(
            'Fotos e PDFs no diário',
            count(plan.diaryFilesUsed, freeDiaryFiles),
            warn: plan.diaryFilesUsed >= freeDiaryFiles,
          ),
        ],
        PlanTier.trial => [
          row('Conta', 'Teste grátis do Premium'),
          row('Acaba em', formatDayBr(plan.trialEndsAt!.toLocal())),
          note(
            'Depois, a conta passa para o plano grátis: $freePetLimit pet, '
            '$freeAiPhotos fotos lidas pela IA e $freeDiaryFiles envios ao '
            'diário.',
          ),
        ],
        PlanTier.premium => [
          row('Conta', 'Premium'),
          if (plan.premiumUntil != null)
            row('Válido até', formatDayBr(plan.premiumUntil!.toLocal())),
          note(
            'Até $premiumPetLimit pets, leitura por IA e arquivos no diário '
            'sem limite.',
          ),
        ],
      },
      if (plan.tier != PlanTier.premium) ...[
        const SizedBox(height: BowieSpacing.s4),
        FilledButton.icon(
          onPressed: () => showPremiumSheet(context),
          icon: const Icon(LucideIcons.sparkles),
          label: const Text('Mudar para Premium'),
        ),
      ],
    ]);
  }
}
