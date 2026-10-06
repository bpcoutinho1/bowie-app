import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/features/contacts/domain/contact.dart';
import 'package:bowie/features/contacts/presentation/contact_actions.dart';
import 'package:bowie/features/contacts/presentation/contacts_providers.dart';
import 'package:bowie/features/houses/house_selector.dart';
import 'package:bowie/features/houses/houses.dart';
import 'package:bowie/features/houses/houses_providers.dart';

/// The house's contact book: vets, nutritionists, daycare, hotel, and more.
class ContactsPage extends ConsumerWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(housesProvider);
    final house = ref.watch(currentHouseProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Contatos')),
      floatingActionButton: house == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  context.push('/pets/contatos/novo?casa=${house.id}'),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Adicionar contato'),
            ),
      body: switch (houses) {
        AsyncError() => const Center(
          child: Text('Não foi possível ler os contatos salvos no celular.'),
        ),
        AsyncData(value: final list) when list.isEmpty => EmptyState(
          icon: LucideIcons.bookUser,
          title: 'Os contatos começam com o primeiro pet',
          message:
              'Cadastre um pet para guardar os contatos da casa, '
              'compartilhados com quem cuida dele com você.',
          action: FilledButton(
            onPressed: () => context.push('/pets/new'),
            child: const Text('Cadastrar pet'),
          ),
        ),
        AsyncData(value: final list) when house != null => Column(
          children: [
            if (list.length > 1)
              HouseSelector(
                houses: list,
                selected: house,
                onSelected: (id) =>
                    ref.read(chosenHouseProvider.notifier).choose(id),
              ),
            Expanded(child: _ContactList(house: house)),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ContactList extends ConsumerStatefulWidget {
  const _ContactList({required this.house});

  final House house;

  @override
  ConsumerState<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends ConsumerState<_ContactList> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final contacts = ref.watch(contactsProvider(widget.house.id));
    return switch (contacts) {
      AsyncError() => const Center(
        child: Text('Não foi possível ler os contatos salvos no celular.'),
      ),
      AsyncData(value: final all) when all.isEmpty => EmptyState(
        icon: LucideIcons.bookUser,
        title: 'Nenhum contato ainda',
        message:
            'Guarde aqui o veterinário, a creche, o hotelzinho e quem mais '
            'cuida do seu pet. Todos da casa veem a mesma agenda.',
        action: FilledButton(
          onPressed: () =>
              context.push('/pets/contatos/novo?casa=${widget.house.id}'),
          child: const Text('Adicionar o primeiro'),
        ),
      ),
      AsyncData(value: final all) => _list(context, colors, all),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _list(BuildContext context, BowieColors colors, List<Contact> all) {
    final query = foldText(_search.text.trim());
    final shown = query.isEmpty
        ? all
        : all
              .where(
                (c) =>
                    foldText(c.name).contains(query) ||
                    foldText(c.category.label).contains(query),
              )
              .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BowieSpacing.s4,
        BowieSpacing.s2,
        BowieSpacing.s4,
        96,
      ),
      children: [
        if (all.length > 5) ...[
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              labelText: 'Buscar por nome ou tipo',
              prefixIcon: Icon(LucideIcons.search),
            ),
          ),
          const SizedBox(height: BowieSpacing.s4),
        ],
        if (shown.isEmpty)
          Text(
            'Nenhum contato com "${_search.text.trim()}".',
            style: BowieType.body.copyWith(color: colors.textMuted),
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i == 0 || shown[i - 1].category != shown[i].category) ...[
            if (i > 0) const SizedBox(height: BowieSpacing.s3),
            Semantics(
              header: true,
              child: Text(
                shown[i].category.label,
                style: BowieType.callout.copyWith(
                  color: colors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: BowieSpacing.s2),
          ],
          ContactCard(contact: shown[i]),
          const SizedBox(height: BowieSpacing.s2),
        ],
      ],
    );
  }
}

class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phone = contact.phone;
    final detail = [
      if (phone != null) formatPhone(phone),
      ?contact.email,
    ].join(' · ');
    return BowieCard(
      onTap: () => showContactActions(
        context,
        contact,
        onEdit: () => context.push('/pets/contatos/${contact.id}'),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BowieSpacing.s4,
          vertical: BowieSpacing.s3,
        ),
        child: Row(
          children: [
            Icon(categoryIcon(contact.category), color: colors.textMuted),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: BowieType.callout.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (phone != null)
              IconButton(
                tooltip: 'Ligar para ${contact.name}',
                onPressed: () => openContactLink(context, callUri(phone)),
                icon: Icon(LucideIcons.phone, color: colors.text),
              ),
          ],
        ),
      ),
    );
  }
}
