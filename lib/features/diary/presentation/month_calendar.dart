import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';

/// A month grid, Sunday first. Days with entries get a dot: filled for what
/// happened, hollow for what is scheduled.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onSelect,
    required this.onMonth,
  });

  /// Any day of the month shown.
  final DateTime month;
  final DateTime selected;
  final DateTime today;

  /// Entries per day.
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mês anterior',
              onPressed: () => onMonth(DateTime(month.year, month.month - 1)),
              icon: const Icon(LucideIcons.chevronLeft),
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  formatMonth(month),
                  textAlign: TextAlign.center,
                  style: BowieType.bodyStrong.copyWith(color: colors.text),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Próximo mês',
              onPressed: () => onMonth(DateTime(month.year, month.month + 1)),
              icon: const Icon(LucideIcons.chevronRight),
            ),
          ],
        ),
        const SizedBox(height: BowieSpacing.s1),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final name in const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'])
                Expanded(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: BowieType.caption.copyWith(color: colors.textMuted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: BowieSpacing.s1),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: _cell(context, row * 7 + col - leading + 1)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int dayNumber) {
    final colors = context.colors;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 48);
    }
    final day = DateTime(month.year, month.month, dayNumber);
    final isSelected = day == dayOf(selected);
    final isToday = day == dayOf(today);
    final count = counts[day] ?? 0;
    final future = day.isAfter(dayOf(today));

    final label = [
      describeDay(day, today),
      if (count == 1) '1 registro',
      if (count > 1) '$count registros',
    ].join(', ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(BowieRadius.md),
        onTap: () => onSelect(day),
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : null,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: colors.primary, width: 1.5)
                      : null,
                ),
                child: Text(
                  '$dayNumber',
                  style: BowieType.callout.copyWith(
                    color: isSelected ? colors.textOnPrimary : colors.text,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w800
                        : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 6,
                child: count == 0
                    ? null
                    : Container(
                        width: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: future ? null : colors.categoryIncidents,
                          border: future
                              ? Border.all(
                                  color: colors.categoryIncidents,
                                  width: 1.5,
                                )
                              : null,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
