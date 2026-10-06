import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/features/shopping/data/shopping_repository.dart';
import 'package:bowie/features/shopping/domain/shopping_catalog.dart';
import 'package:bowie/features/shopping/domain/shopping_item.dart';
import 'package:bowie/features/shopping/presentation/shopping_providers.dart';

/// The house's shopping list, as in Bring!: big tiles, a tap marks an item
/// as bought, and bought items wait among the frequent ones to come back.
class ShoppingPage extends ConsumerWidget {
  const ShoppingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final houses = ref.watch(housesProvider);
    final house = ref.watch(currentHouseProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
        actions: const [NotificationsButton()],
      ),
      floatingActionButton: house == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddItemSheet(context, house.id),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Adicionar item'),
            ),
      body: switch (houses) {
        AsyncError() => const Center(
          child: Text('Não foi possível ler a lista salva no celular.'),
        ),
        AsyncData(value: final list) when list.isEmpty => EmptyState(
          icon: LucideIcons.shoppingCart,
          title: 'A lista começa com o primeiro pet',
          message:
              'Cadastre um pet para ter a lista de compras da casa, '
              'compartilhada com quem cuida dele com você.',
          action: FilledButton(
            onPressed: () => context.push('/pets/new'),
            child: const Text('Cadastrar pet'),
          ),
        ),
        AsyncData(value: final list) when house != null => Column(
          children: [
            if (list.length > 1)
              _HouseSelector(
                houses: list,
                selected: house,
                onSelected: (id) =>
                    ref.read(chosenHouseProvider.notifier).choose(id),
              ),
            Expanded(child: _HouseList(house: house)),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _HouseSelector extends StatelessWidget {
  const _HouseSelector({
    required this.houses,
    required this.selected,
    required this.onSelected,
  });

  final List<House> houses;
  final House selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BowieSpacing.s4),
        children: [
          for (final house in houses) ...[
            ChoiceChip(
              avatar: const Icon(LucideIcons.house, size: 18),
              label: Text(house.label),
              selected: house.id == selected.id,
              onSelected: (_) => onSelected(house.id),
            ),
            const SizedBox(width: BowieSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _HouseList extends ConsumerWidget {
  const _HouseList({required this.house});

  final House house;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final list = ref.watch(shoppingListProvider(house.id));
    return switch (list) {
      AsyncError() => const Center(
        child: Text('Não foi possível ler a lista salva no celular.'),
      ),
      AsyncData(value: final list) => ListView(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          96,
        ),
        children: [
          _SectionTitle(title: 'A comprar', count: list.toBuy.length),
          const SizedBox(height: BowieSpacing.s3),
          if (list.toBuy.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: BowieSpacing.s4),
              child: Text(
                list.frequent.isEmpty
                    ? 'Nada para comprar ainda. Toque em "Adicionar item" '
                          'para começar a lista.'
                    : 'Nada para comprar. Toque num item frequente para '
                          'pôr de volta na lista.',
                style: BowieType.body.copyWith(color: colors.textMuted),
              ),
            )
          else
            _TileGrid(
              children: [
                for (final item in list.toBuy)
                  _ItemTile(item: item, house: house),
              ],
            ),
          if (list.frequent.isNotEmpty) ...[
            const SizedBox(height: BowieSpacing.s8),
            _SectionTitle(
              title: 'Itens frequentes',
              count: list.frequent.length,
            ),
            const SizedBox(height: BowieSpacing.s1),
            Text(
              'Toque para pôr de volta na lista.',
              style: BowieType.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s3),
            _TileGrid(
              children: [
                for (final item in list.frequent)
                  _ItemTile(item: item, house: house),
              ],
            ),
          ],
        ],
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Text(title, style: BowieType.title3.copyWith(color: colors.text)),
          const SizedBox(width: BowieSpacing.s2),
          if (count > 0)
            Text(
              '$count',
              style: BowieType.callout.copyWith(color: colors.textMuted),
            ),
        ],
      ),
    );
  }
}

/// Three tiles per row on a phone, more on wider screens.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = BowieSpacing.s3;
        final columns = (constraints.maxWidth / 120).floor().clamp(3, 6);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item, required this.house});

  final ShoppingItem item;
  final House house;

  bool get _toBuy => item.status == ShoppingStatus.toBuy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final details = item.details;
    return Semantics(
      button: true,
      label: [item.name, ?details].join(', '),
      hint: _toBuy
          ? 'Toque para marcar como comprado'
          : 'Toque para pôr de volta na lista',
      excludeSemantics: true,
      child: Material(
        color: _toBuy ? colors.surface : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(BowieRadius.md),
        elevation: _toBuy ? 1 : 0,
        shadowColor: colors.text.withValues(alpha: 0.2),
        child: InkWell(
          borderRadius: BorderRadius.circular(BowieRadius.md),
          onTap: () => _toggle(context, ref),
          onLongPress: () => _showActions(context, ref),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 104),
            child: Padding(
              padding: const EdgeInsets.all(BowieSpacing.s2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    shoppingIcon(item.catalogKey),
                    size: 32,
                    color: _toBuy ? colors.categoryShopping : colors.textMuted,
                  ),
                  const SizedBox(height: BowieSpacing.s2),
                  Text(
                    item.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BowieType.callout.copyWith(
                      color: _toBuy ? colors.text : colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (details != null)
                    Text(
                      details,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BowieType.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repository = ref.read(shoppingRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final next = _toBuy ? ShoppingStatus.bought : ShoppingStatus.toBuy;
    try {
      await repository.setStatus(id: item.id, status: next, byUser: user);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            // A snack bar with an action stays until dismissed by default;
            // this one should leave on its own and free the add button.
            persist: false,
            duration: const Duration(seconds: 5),
            content: Text(
              next == ShoppingStatus.bought
                  ? '${item.name} foi para os itens frequentes'
                  : '${item.name} voltou para a lista',
            ),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () => repository.setStatus(
                id: item.id,
                status: item.status,
                byUser: user,
              ),
            ),
          ),
        );
    } on AppFailure catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil),
              title: const Text('Editar'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: context.colors.danger),
              title: Text(
                'Remover ${item.name}',
                style: TextStyle(color: context.colors.danger),
              ),
              subtitle: const Text('Sai da lista e dos itens frequentes.'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repository = ref.read(shoppingRepositoryProvider);
    if (action == 'delete') {
      try {
        await repository.delete(id: item.id, byUser: user);
      } on AppFailure catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    } else if (action == 'edit') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _EditItemSheet(item: item),
      );
    }
  }
}

class _EditItemSheet extends ConsumerStatefulWidget {
  const _EditItemSheet({required this.item});

  final ShoppingItem item;

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _details = TextEditingController(text: widget.item.details);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        BowieSpacing.s4,
        0,
        BowieSpacing.s4,
        BowieSpacing.s6 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Editar item',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s4),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: BowieSpacing.s4),
          TextField(
            controller: _details,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              hintText: 'Marca, tamanho: Golden 15 kg',
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
          FilledButton(onPressed: _save, child: const Text('Salvar')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(shoppingRepositoryProvider)
          .edit(
            id: widget.item.id,
            name: _name.text,
            details: _details.text,
            byUser: user,
          );
      if (mounted) Navigator.of(context).pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}

Future<void> showAddItemSheet(BuildContext context, String houseId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _AddItemSheet(houseId: houseId),
  );
}

/// Type a name or tap a catalog tile. The sheet stays open to add several
/// items in a row, as in Bring!.
class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet({required this.houseId});

  final String houseId;

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _name = TextEditingController();
  final _details = TextEditingController();
  String? _message;
  var _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final list = ref.watch(shoppingListProvider(widget.houseId)).asData?.value;
    final onList = {
      for (final item in list?.toBuy ?? const <ShoppingItem>[])
        foldText(item.name),
    };
    final query = foldText(_name.text.trim());
    final catalog = [
      for (final entry in shoppingCatalog)
        if (query.isEmpty ||
            foldText(entry.label).contains(query) ||
            entry.aliases.any((alias) => foldText(alias).contains(query)))
          entry,
    ];
    final typed = _name.text.trim();
    final typedIsCatalog = catalog.any(
      (entry) => foldText(entry.label) == query,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          0,
          BowieSpacing.s4,
          BowieSpacing.s6,
        ),
        children: [
          Text(
            'Adicionar à lista',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s4),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addTyped(),
            decoration: const InputDecoration(
              labelText: 'O que precisa comprar?',
              prefixIcon: Icon(LucideIcons.search),
            ),
          ),
          const SizedBox(height: BowieSpacing.s3),
          TextField(
            controller: _details,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              hintText: 'Marca, tamanho: Golden 15 kg',
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: BowieSpacing.s3),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    _messageIsError
                        ? LucideIcons.circleAlert
                        : LucideIcons.circleCheck,
                    size: 18,
                    color: _messageIsError ? colors.danger : colors.success,
                  ),
                  const SizedBox(width: BowieSpacing.s2),
                  Expanded(
                    child: Text(
                      _message!,
                      style: BowieType.callout.copyWith(color: colors.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (typed.isNotEmpty && !typedIsCatalog) ...[
            const SizedBox(height: BowieSpacing.s3),
            FilledButton.icon(
              onPressed: _addTyped,
              icon: const Icon(LucideIcons.plus),
              label: Text('Adicionar "$typed"'),
            ),
          ],
          const SizedBox(height: BowieSpacing.s4),
          if (catalog.isNotEmpty) ...[
            Text(
              'Catálogo',
              style: BowieType.bodyStrong.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s3),
            _TileGrid(
              children: [
                for (final entry in catalog)
                  _CatalogTile(
                    entry: entry,
                    onList: onList.contains(foldText(entry.label)),
                    onTap: () => _add(entry.label, catalogKey: entry.key),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addTyped() async {
    final typed = _name.text.trim();
    if (typed.isEmpty) return;
    await _add(typed);
  }

  Future<void> _add(String name, {String? catalogKey}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      final item = await ref
          .read(shoppingRepositoryProvider)
          .add(
            houseId: widget.houseId,
            name: name,
            details: _details.text,
            catalogKey: catalogKey,
            byUser: user,
          );
      if (!mounted) return;
      _name.clear();
      _details.clear();
      setState(() {
        _message = '${item.name} está na lista.';
        _messageIsError = false;
      });
    } on AppFailure catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _messageIsError = true;
        });
      }
    }
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.entry,
    required this.onList,
    required this.onTap,
  });

  final CatalogEntry entry;
  final bool onList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      label: entry.label,
      hint: onList ? 'Já está na lista' : 'Toque para adicionar',
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(BowieRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(BowieRadius.md),
          onTap: onList ? null : onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(BowieSpacing.s2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    onList ? LucideIcons.check : entry.icon,
                    size: 28,
                    color: onList ? colors.success : colors.categoryShopping,
                  ),
                  const SizedBox(height: BowieSpacing.s2),
                  Text(
                    entry.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BowieType.caption.copyWith(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
