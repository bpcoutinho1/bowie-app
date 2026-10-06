import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/contacts/data/contacts_repository.dart';
import 'package:bowie/features/contacts/domain/contact.dart';
import 'package:bowie/features/contacts/presentation/contact_actions.dart';
import 'package:bowie/features/contacts/presentation/contacts_providers.dart';

/// Adds a contact to [houseId], or edits one when [contactId] is given.
class ContactFormPage extends ConsumerWidget {
  const ContactFormPage({super.key, this.houseId, this.contactId});

  final String? houseId;
  final String? contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactId = this.contactId;
    if (contactId == null) {
      final houseId = this.houseId;
      if (houseId == null) return const _Message('Abra os contatos da casa.');
      return _ContactForm(houseId: houseId);
    }
    return switch (ref.watch(contactProvider(contactId))) {
      AsyncData(value: final Contact contact) when contact.deletedAt == null =>
        _ContactForm(houseId: contact.houseId, contact: contact),
      AsyncData() => const _Message('Este contato não está mais disponível.'),
      AsyncError() => const _Message('Não foi possível ler este contato.'),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(text)),
    );
  }
}

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm({required this.houseId, this.contact});

  final String houseId;
  final Contact? contact;

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  late final _name = TextEditingController(text: widget.contact?.name);
  late final _phone = TextEditingController(
    text: widget.contact?.phone == null
        ? null
        : formatPhone(widget.contact!.phone!),
  );
  late final _email = TextEditingController(text: widget.contact?.email);
  late final _address = TextEditingController(text: widget.contact?.address);
  late final _notes = TextEditingController(text: widget.contact?.notes);
  late ContactCategory _category =
      widget.contact?.category ?? ContactCategory.vet;
  var _saving = false;
  String? _error;

  bool get _editing => widget.contact != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const gap = SizedBox(height: BowieSpacing.s4);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar contato' : 'Novo contato')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          Text(
            'Tipo',
            style: BowieType.bodyStrong.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s2),
          Wrap(
            spacing: BowieSpacing.s2,
            runSpacing: BowieSpacing.s2,
            children: [
              for (final category in ContactCategory.values)
                ChoiceChip(
                  avatar: Icon(categoryIcon(category), size: 18),
                  label: Text(category.label),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          gap,
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Pessoa, clínica ou empresa',
            ),
          ),
          gap,
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Telefone (opcional)',
              hintText: '(11) 98765-4321',
              helperText: 'Com DDD. Celulares ganham o botão do WhatsApp.',
            ),
          ),
          gap,
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email (opcional)'),
          ),
          gap,
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Endereço (opcional)'),
          ),
          gap,
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
              hintText: 'Horário de atendimento, especialidade, CRMV',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: BowieSpacing.s3),
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
          if (_editing) ...[
            const SizedBox(height: BowieSpacing.s4),
            TextButton.icon(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              icon: const Icon(LucideIcons.trash2),
              label: const Text('Excluir contato'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(contactsRepositoryProvider)
          .save(
            id: widget.contact?.id,
            houseId: widget.houseId,
            input: ContactInput(
              name: _name.text,
              category: _category,
              phone: _phone.text,
              email: _email.text,
              address: _address.text,
              notes: _notes.text,
            ),
            byUser: user,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Contato atualizado' : 'Contato salvo'),
        ),
      );
      context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final contact = widget.contact;
    final user = ref.read(currentUserProvider);
    if (contact == null || user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${contact.name}?'),
        content: const Text(
          'O contato sai da agenda de todos da casa. Os registros do diário '
          'que citam esse contato continuam mostrando o nome.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(contactsRepositoryProvider)
          .delete(id: contact.id, byUser: user);
      if (!mounted) return;
      context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}
