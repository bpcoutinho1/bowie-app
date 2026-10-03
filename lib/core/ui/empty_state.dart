import 'package:flutter/material.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BowieSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.textMuted),
            const SizedBox(height: BowieSpacing.s4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: BowieType.title3.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: BowieSpacing.s6),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
