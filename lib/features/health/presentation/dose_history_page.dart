import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/health/presentation/status_badge.dart';

/// Every dose of the same vaccine as [doseId], newest first.
class DoseHistoryPage extends ConsumerWidget {
  const DoseHistoryPage({super.key, required this.doseId});

  final String doseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dose = ref.watch(doseProvider(doseId)).asData?.value;
    final groups = dose == null
        ? null
        : ref.watch(vaccineGroupsProvider(dose.petId)).asData?.value;
    final key = dose == null ? null : groupKey(dose.kind, dose.name);
    final group = groups
        ?.where((g) => groupKey(g.kind, g.name) == key)
        .firstOrNull;
    final today = ref.watch(healthRepositoryProvider).today;
    final colors = context.colors;

    if (group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: dose == null && groups == null
              ? const CircularProgressIndicator()
              : const Text('Este registro não está mais disponível.'),
        ),
      );
    }

    final latest = group.latest;
    return Scaffold(
      appBar: AppBar(title: Text(group.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          Text(
            group.kind.label,
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s2),
          StatusBadge(
            status: group.statusOn(today),
            text: describeDue(latest.nextDueOn, today),
          ),
          const SizedBox(height: BowieSpacing.s6),
          Text(
            group.doses.length == 1 ? 'Dose' : 'Doses',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s3),
          for (final dose in group.doses) ...[
            _DoseCard(
              dose: dose,
              status: group.doseStatus(dose, today),
              today: today,
            ),
            const SizedBox(height: BowieSpacing.s3),
          ],
          const SizedBox(height: BowieSpacing.s3),
          OutlinedButton.icon(
            onPressed: () => context.push(
              Uri(
                path: '/saude/doses/nova',
                queryParameters: {
                  'pet': latest.petId,
                  'tipo': latest.kind.name,
                  'nome': latest.name,
                },
              ).toString(),
            ),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Registrar nova dose'),
          ),
        ],
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.dose,
    required this.status,
    required this.today,
  });

  final VaccineDose dose;
  final VaccineStatus status;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final details = [
      ?dose.product,
      if (dose.lot != null) 'Lote ${dose.lot}',
      ?dose.veterinarian,
    ];
    return BowieCard(
      onTap: () => context.push('/saude/doses/${dose.id}/editar'),
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aplicada em ${formatDayBr(dose.appliedOn)}',
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    '${dose.kind == DoseKind.vaccine ? 'Revacinar em' : 'Próxima dose em'} '
                    '${formatDayBr(dose.nextDueOn)}',
                    style: BowieType.callout.copyWith(color: colors.textMuted),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: BowieSpacing.s1),
                    Text(
                      details.join(' · '),
                      style: BowieType.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: BowieSpacing.s2),
                  StatusBadge(
                    status: status,
                    text: status == VaccineStatus.replaced
                        ? 'Substituída por uma dose mais nova'
                        : describeDue(dose.nextDueOn, today),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.pencil, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
