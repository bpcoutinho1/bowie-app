import 'package:flutter/material.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_photo.dart';

/// Chips to pick one pet when there is more than one, with each pet's photo.
class PetSelector extends StatelessWidget {
  const PetSelector({
    super.key,
    required this.pets,
    required this.selected,
    required this.onSelected,
  });

  final List<Pet> pets;
  final Pet selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BowieSpacing.s4),
        children: [
          for (final pet in pets) ...[
            ChoiceChip(
              avatar: PetAvatar(pet: pet, size: 24),
              label: Text(pet.name),
              selected: pet.id == selected.id,
              onSelected: (_) => onSelected(pet.id),
            ),
            const SizedBox(width: BowieSpacing.s2),
          ],
        ],
      ),
    );
  }
}
