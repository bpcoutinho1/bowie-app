import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';

/// One option of a [ChoiceField].
class ChoiceOption<T> {
  const ChoiceOption({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
  });

  final T value;
  final String label;
  final IconData icon;

  /// A short example, shown in the list: "Diarreia, vômito, tosse".
  final String? description;
}

/// A field that shows the chosen option and opens the list of options in a
/// bottom sheet. Used instead of a segmented button when the labels do not
/// fit side by side (three or more, or long words).
class ChoiceField<T> extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final T value;
  final List<ChoiceOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  ChoiceOption<T> get _selected =>
      options.firstWhere((o) => o.value == value, orElse: () => options.first);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = _selected;
    return Semantics(
      button: true,
      label: '$label: ${selected.label}. Toque para trocar.',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(BowieRadius.md),
        onTap: enabled ? () => _choose(context) : null,
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: label,
            enabled: enabled,
            suffixIcon: Icon(LucideIcons.chevronDown, color: colors.textMuted),
          ),
          child: Row(
            children: [
              Icon(selected.icon, size: 20, color: colors.text),
              const SizedBox(width: BowieSpacing.s3),
              Expanded(
                child: Text(
                  selected.label,
                  style: BowieType.body.copyWith(color: colors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final chosen = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final colors = sheet.colors;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BowieSpacing.s4,
                    0,
                    BowieSpacing.s4,
                    BowieSpacing.s2,
                  ),
                  child: Text(
                    label,
                    style: BowieType.title3.copyWith(color: colors.text),
                  ),
                ),
                for (final option in options)
                  ListTile(
                    leading: Icon(option.icon, color: colors.text),
                    title: Text(option.label),
                    subtitle: option.description == null
                        ? null
                        : Text(option.description!),
                    trailing: option.value == value
                        ? Icon(LucideIcons.check, color: colors.primary)
                        : null,
                    selected: option.value == value,
                    onTap: () => Navigator.of(sheet).pop(option.value),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (chosen != null && chosen != value) onChanged(chosen);
  }
}
