import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';

/// Status with icon, text and color together; never color alone.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, required this.text});

  final VaccineStatus status;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (IconData icon, Color fg, Color bg) = switch (status) {
      VaccineStatus.upToDate => (
        LucideIcons.circleCheck,
        c.success,
        c.successSoft,
      ),
      VaccineStatus.dueSoon => (LucideIcons.clock, c.warning, c.warningSoft),
      VaccineStatus.overdue => (
        LucideIcons.circleAlert,
        c.danger,
        c.dangerSoft,
      ),
      VaccineStatus.replaced => (
        LucideIcons.history,
        c.textMuted,
        c.surfaceMuted,
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BowieRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BowieSpacing.s2,
          vertical: BowieSpacing.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: BowieSpacing.s1),
            Flexible(
              child: Text(
                text,
                style: BowieType.caption.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
