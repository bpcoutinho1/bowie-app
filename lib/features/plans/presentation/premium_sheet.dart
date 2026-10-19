import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/plans/domain/account_plan.dart';

/// "Bowie Premium": what it adds and the price. Payment is not live yet
/// (docs/produto/planos.md), so the button only says so.
Future<void> showPremiumSheet(BuildContext context, {String? reason}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheet) {
      final colors = sheet.colors;
      Widget benefit(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: BowieSpacing.s2),
        child: Row(
          children: [
            Icon(icon, color: colors.text),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Text(
                text,
                style: BowieType.body.copyWith(color: colors.text),
              ),
            ),
          ],
        ),
      );

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          0,
          BowieSpacing.s4,
          BowieSpacing.s6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Bowie Premium',
              style: BowieType.title2.copyWith(color: colors.text),
            ),
            if (reason != null) ...[
              const SizedBox(height: BowieSpacing.s2),
              Text(
                reason,
                style: BowieType.body.copyWith(color: colors.textMuted),
              ),
            ],
            const SizedBox(height: BowieSpacing.s4),
            benefit(LucideIcons.pawPrint, 'Até $premiumPetLimit pets'),
            benefit(
              LucideIcons.scanLine,
              'Leitura da carteirinha por IA sem limite',
            ),
            benefit(LucideIcons.fileText, 'Fotos e PDFs no diário sem limite'),
            const SizedBox(height: BowieSpacing.s4),
            Text(
              'R\$ 9,90 por mês ou R\$ 99,90 por ano',
              style: BowieType.title3.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s1),
            Text(
              'Tudo o que você já registrou continua seu, em qualquer plano.',
              style: BowieType.callout.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s6),
            const FilledButton(
              onPressed: null,
              child: Text('Assinatura em breve'),
            ),
            const SizedBox(height: BowieSpacing.s2),
            Text(
              'A assinatura pelo app chega nas próximas versões.',
              textAlign: TextAlign.center,
              style: BowieType.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s2),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(),
              child: const Text('Agora não'),
            ),
          ],
        ),
      );
    },
  );
}

/// A limit that the Premium does not lift.
Future<void> showLimitNotice(BuildContext context, String text) {
  return showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Limite do plano'),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}
