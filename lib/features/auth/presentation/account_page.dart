import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/presentation/sign_out.dart';
import 'package:bowie/features/contacts/domain/contact.dart';

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
          OutlinedButton.icon(
            onPressed: _saving ? null : () => signOut(ref),
            icon: const Icon(LucideIcons.logOut),
            label: const Text('Sair da conta'),
          ),
        ],
      ),
    );
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
