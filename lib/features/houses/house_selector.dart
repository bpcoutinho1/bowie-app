import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/features/houses/houses.dart';

/// Chips to switch houses, for people who belong to more than one.
class HouseSelector extends StatelessWidget {
  const HouseSelector({
    super.key,
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
