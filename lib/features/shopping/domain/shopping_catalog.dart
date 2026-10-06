import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/core/text.dart';

/// An item of the catalog, shown as a tile with an icon, like in Bring!.
class CatalogEntry {
  const CatalogEntry(
    this.key,
    this.label,
    this.icon, [
    this.aliases = const [],
  ]);

  /// Stored with the item, so the icon survives a rename. Never change one.
  final String key;
  final String label;
  final IconData icon;

  /// Other words people type for the same thing, without accents.
  final List<String> aliases;
}

const shoppingCatalog = [
  CatalogEntry('food', 'Ração', LucideIcons.package, ['racao']),
  CatalogEntry('wet_food', 'Sachê', LucideIcons.beef, [
    'sache',
    'patê',
    'pate',
    'lata',
  ]),
  CatalogEntry('treat', 'Petisco', LucideIcons.cookie, [
    'petiscos',
    'biscoito',
    'bifinho',
  ]),
  CatalogEntry('chew', 'Osso', LucideIcons.bone, ['ossinho', 'mordedor']),
  CatalogEntry('litter', 'Areia', LucideIcons.shovel, [
    'areia higienica',
    'granulado',
  ]),
  CatalogEntry('pads', 'Tapete higiênico', LucideIcons.layers, [
    'tapete',
    'tapete higienico',
  ]),
  CatalogEntry('poop_bags', 'Saquinhos', LucideIcons.shoppingBag, [
    'saquinho',
    'saco',
  ]),
  CatalogEntry('flea', 'Antipulgas', LucideIcons.bug, [
    'antipulga',
    'coleira antipulgas',
    'pulga',
    'carrapato',
  ]),
  CatalogEntry('dewormer', 'Vermífugo', LucideIcons.pill, ['vermifugo']),
  CatalogEntry('medicine', 'Remédio', LucideIcons.bandage, [
    'remedio',
    'medicamento',
  ]),
  CatalogEntry('shampoo', 'Shampoo', LucideIcons.droplets, ['xampu', 'banho']),
  CatalogEntry('toy', 'Brinquedo', LucideIcons.volleyball, ['bolinha', 'bola']),
  CatalogEntry('brush', 'Escova', LucideIcons.brush, ['escovinha', 'pente']),
  CatalogEntry('bed', 'Caminha', LucideIcons.bed, ['cama']),
  CatalogEntry('bowl', 'Comedouro', LucideIcons.utensils, [
    'pote',
    'bebedouro',
    'tigela',
  ]),
  CatalogEntry('collar', 'Coleira', LucideIcons.circleDot, [
    'guia',
    'peitoral',
  ]),
];

/// Icon for items typed outside the catalog.
const IconData defaultShoppingIcon = LucideIcons.shoppingBasket;

CatalogEntry? catalogEntry(String? key) =>
    shoppingCatalog.where((entry) => entry.key == key).firstOrNull;

/// The catalog entry a typed name refers to, by its label or a known alias at
/// the start: "Ração Golden 15 kg" → Ração.
CatalogEntry? matchCatalog(String name) {
  final text = foldText(name.trim());
  if (text.isEmpty) return null;
  for (final entry in shoppingCatalog) {
    final words = [foldText(entry.label), ...entry.aliases.map(foldText)];
    if (words.any((word) => text == word || text.startsWith('$word '))) {
      return entry;
    }
  }
  return null;
}

IconData shoppingIcon(String? catalogKey) =>
    catalogEntry(catalogKey)?.icon ?? defaultShoppingIcon;
