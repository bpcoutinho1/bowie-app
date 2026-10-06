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
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/health/domain/medication.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/pets/domain/pet.dart';

/// Today's doses, to mark as given, and the pet's medications.
class MedicationsSection extends ConsumerWidget {
  const MedicationsSection({
    super.key,
    required this.pet,
    required this.medications,
  });

  final Pet pet;
  final List<Medication> medications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final today = ref.watch(medicationRepositoryProvider).today;
    final slots =
        ref.watch(todayDosesProvider(pet.id)).asData?.value ??
        const <DoseSlot>[];
    final active = [
      for (final med in medications)
        if (med.isActiveOn(today) || med.startOn.isAfter(today)) med,
    ];
    final finished = [
      for (final med in medications)
        if (!active.contains(med)) med,
    ];
    final given = slots.where((slot) => slot.given != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slots.isNotEmpty) ...[
          Semantics(
            header: true,
            child: Text(
              'Remédios de hoje',
              style: BowieType.title3.copyWith(color: colors.text),
            ),
          ),
          Text(
            given == slots.length
                ? 'Todas as doses de hoje foram dadas.'
                : '$given de ${slots.length} doses dadas',
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s3),
          BowieCard(
            child: Column(
              children: [
                for (var i = 0; i < slots.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.border),
                  DoseTile(slot: slots[i], day: today),
                ],
              ],
            ),
          ),
          const SizedBox(height: BowieSpacing.s6),
        ],
        Semantics(
          header: true,
          child: Text(
            'Medicações ${ofPet(pet)}',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
        ),
        const SizedBox(height: BowieSpacing.s3),
        for (final med in active) ...[
          MedicationCard(medication: med, today: today),
          const SizedBox(height: BowieSpacing.s3),
        ],
        if (finished.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                finished.length == 1
                    ? '1 tratamento encerrado'
                    : '${finished.length} tratamentos encerrados',
                style: BowieType.callout.copyWith(color: colors.textMuted),
              ),
              children: [
                for (final med in finished) ...[
                  MedicationCard(medication: med, today: today),
                  const SizedBox(height: BowieSpacing.s3),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// One dose of today: time, medication, dose, and who gave it. The check
/// marks or undoes it.
class DoseTile extends ConsumerWidget {
  const DoseTile({super.key, required this.slot, required this.day});

  final DoseSlot slot;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final med = slot.medication;
    final given = slot.given;
    final time = slot.time;
    final user = ref.watch(currentUserProvider);
    final when = time == null ? 'Hoje' : '${time.period.label} · ${time.time}';
    final String? givenText;
    if (given == null) {
      givenText = null;
    } else {
      final local = given.givenAt.toLocal();
      final at =
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      final who = user != null && given.givenBy == user.id
          ? 'você'
          : given.givenByEmail.split('@').first;
      givenText = 'Dada por $who às $at';
    }

    return Semantics(
      container: true,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s1,
          BowieSpacing.s2,
          BowieSpacing.s1,
        ),
        title: Text(
          med.name,
          style: BowieType.bodyStrong.copyWith(
            color: given == null ? colors.text : colors.textMuted,
          ),
        ),
        subtitle: Text(
          [when, med.doseText, ?givenText].join('\n'),
          style: BowieType.callout.copyWith(color: colors.textMuted),
        ),
        isThreeLine: true,
        trailing: IconButton(
          iconSize: 28,
          tooltip: given == null
              ? 'Marcar ${med.name} como dado'
              : 'Desfazer: ${med.name} não foi dado',
          onPressed: user == null ? null : () => _toggle(context, ref, user),
          icon: Icon(
            given == null ? LucideIcons.circle : LucideIcons.circleCheck,
            color: given == null ? colors.textMuted : colors.success,
          ),
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    try {
      await ref
          .read(medicationRepositoryProvider)
          .markGiven(
            slot: slot,
            day: day,
            given: slot.given == null,
            byUser: user,
          );
    } on AppFailure catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class MedicationCard extends StatelessWidget {
  const MedicationCard({
    super.key,
    required this.medication,
    required this.today,
  });

  final Medication medication;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final med = medication;
    final schedule = med.frequency == MedFrequency.daily
        ? [
            med.scheduleText,
            med.times.map((t) => t.time).join(', '),
          ].join(' · ')
        : med.scheduleText;
    final next = med.frequency == MedFrequency.daily
        ? null
        : med.nextDueOn(today);
    final end = med.endOn;
    final period = !med.isActiveOn(today) && med.startOn.isAfter(today)
        ? 'Começa em ${formatDayBr(med.startOn)}'
        : end == null
        ? 'Uso contínuo'
        : end.isBefore(today)
        ? 'Terminou em ${formatDayBr(end)}'
        : 'Até ${formatDayBr(end)}';

    return BowieCard(
      onTap: () => context.push('/saude/medicacoes/${med.id}'),
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.pill, color: colors.categoryVaccines),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    med.doseText,
                    style: BowieType.callout.copyWith(color: colors.text),
                  ),
                  Text(
                    schedule,
                    style: BowieType.callout.copyWith(color: colors.textMuted),
                  ),
                  if (next != null)
                    Text(
                      'Próxima: ${describeDay(next, today)}',
                      style: BowieType.callout.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  Text(
                    period,
                    style: BowieType.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
