import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/diary/presentation/event_photos.dart';
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
    final key = dose == null ? null : doseGroupKey(dose);
    final group = groups?.where((g) => g.key == key).firstOrNull;
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
    final others = [
      for (final other in groups!)
        if (other.key != group.key && other.kind == group.kind) other,
    ];
    final otherNames = group.otherNames;
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
          if (otherNames.isNotEmpty)
            Text(
              'Também registrada como ${joinNames(otherNames)}',
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
              showName: foldText(dose.name) != foldText(group.name),
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
          if (group.kind == DoseKind.vaccine && others.isNotEmpty) ...[
            const SizedBox(height: BowieSpacing.s6),
            Text(
              'É a mesma vacina de outro registro, com outro nome? Junte '
              'os dois: a dose mais recente passa a valer para ambos.',
              style: BowieType.callout.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s2),
            OutlinedButton.icon(
              onPressed: () => _join(context, ref, group, others),
              icon: const Icon(LucideIcons.merge),
              label: const Text('Juntar com outra vacina'),
            ),
          ],
          if (group.hasJoined) ...[
            const SizedBox(height: BowieSpacing.s2),
            TextButton.icon(
              onPressed: () => _separate(context, ref, group),
              icon: const Icon(LucideIcons.split),
              label: const Text('Desfazer junção'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _join(
    BuildContext context,
    WidgetRef ref,
    VaccineGroup group,
    List<VaccineGroup> others,
  ) async {
    final into = await showModalBottomSheet<VaccineGroup>(
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
                    '${group.name} é a mesma vacina que:',
                    style: BowieType.title3.copyWith(color: colors.text),
                  ),
                ),
                for (final other in others)
                  ListTile(
                    leading: Icon(LucideIcons.syringe, color: colors.text),
                    title: Text(other.name),
                    subtitle: Text(
                      'Aplicada em ${formatDayBr(other.latest.appliedOn)}',
                    ),
                    onTap: () => Navigator.of(sheet).pop(other),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (into == null || !context.mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(healthRepositoryProvider)
          .joinGroups(from: group, into: into, byUser: user);
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${group.name} e ${into.name} agora são uma vacina só.'),
      ),
    );
  }

  Future<void> _separate(
    BuildContext context,
    WidgetRef ref,
    VaccineGroup group,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    try {
      await ref
          .read(healthRepositoryProvider)
          .separateGroup(group: group, byUser: user);
    } on AppFailure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Junção desfeita.')));
  }
}

class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.dose,
    required this.showName,
    required this.status,
    required this.today,
  });

  final VaccineDose dose;

  /// The dose was written with another name than the vaccine's.
  final bool showName;
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
                  if (showName)
                    Text(
                      dose.name,
                      style: BowieType.callout.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  Text(
                    'Aplicada em ${formatDayBr(dose.appliedOn)}',
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    '${dose.kind.dueLabel} '
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
                  ProofBadge(hasProof: dose.hasProof),
                  if (dose.hasProof) ...[
                    const SizedBox(height: BowieSpacing.s2),
                    EventPhotoStrip(paths: dose.proofPaths, size: 56),
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
