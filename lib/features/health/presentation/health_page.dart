import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/features/health/domain/medication.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/health/presentation/medications_section.dart';
import 'package:bowie/features/health/presentation/status_badge.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_selector.dart';
import 'package:bowie/features/pets/presentation/pets_page.dart';

class HealthPage extends ConsumerWidget {
  const HealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(petsHomeProvider);
    final pets = home.asData?.value.pets ?? const <Pet>[];
    final selectedId = ref.watch(selectedPetIdProvider);
    final pet =
        pets.where((p) => p.id == selectedId).firstOrNull ?? pets.firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saúde'),
        actions: [
          if (pet != null)
            IconButton(
              tooltip: 'Ler carteirinha',
              onPressed: () => context.push('/saude/carteirinha?pet=${pet.id}'),
              icon: const Icon(LucideIcons.scanText),
            ),
          const NotificationsButton(),
        ],
      ),
      floatingActionButton: pet == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'medication',
                  onPressed: () =>
                      context.push('/saude/medicacoes/nova?pet=${pet.id}'),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Registrar medicação'),
                ),
                const SizedBox(height: BowieSpacing.s3),
                FloatingActionButton.extended(
                  heroTag: 'vaccine',
                  onPressed: () =>
                      context.push('/saude/doses/nova?pet=${pet.id}'),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Registrar vacina'),
                ),
              ],
            ),
      body: switch (home) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => const Center(
          child: Text('Não foi possível ler os pets salvos no celular.'),
        ),
        _ when pet == null => EmptyState(
          icon: LucideIcons.heartPulse,
          title: 'Nenhum pet ainda',
          message: 'Cadastre um pet para registrar as vacinas dele.',
          action: FilledButton(
            onPressed: () => context.push('/pets/new'),
            child: const Text('Cadastrar pet'),
          ),
        ),
        _ => Column(
          children: [
            if (pets.length > 1)
              PetSelector(
                pets: pets,
                selected: pet,
                onSelected: (id) =>
                    ref.read(selectedPetIdProvider.notifier).select(id),
              ),
            Expanded(child: _Vaccines(pet: pet)),
          ],
        ),
      },
    );
  }
}

class _Vaccines extends ConsumerWidget {
  const _Vaccines({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(vaccineGroupsProvider(pet.id));
    final medications =
        ref.watch(medicationsProvider(pet.id)).asData?.value ??
        const <Medication>[];
    final today = ref.watch(healthRepositoryProvider).today;
    final colors = context.colors;

    return groups.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Text('Não foi possível ler as vacinas salvas no celular.'),
      ),
      data: (groups) {
        if (groups.isEmpty && medications.isEmpty) {
          return EmptyState(
            icon: LucideIcons.syringe,
            title: 'Nenhuma vacina registrada ainda',
            message:
                'Fotografe a carteirinha ${ofPet(pet)} e o app registra as '
                'vacinas e os vermífugos para você conferir.',
            action: Column(
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/saude/carteirinha?pet=${pet.id}'),
                  icon: const Icon(LucideIcons.scanText),
                  label: const Text('Ler a carteirinha'),
                ),
                const SizedBox(height: BowieSpacing.s3),
                TextButton(
                  onPressed: () =>
                      context.push('/saude/doses/nova?pet=${pet.id}'),
                  child: const Text('Registrar à mão'),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            BowieSpacing.s4,
            BowieSpacing.s2,
            BowieSpacing.s4,
            176,
          ),
          children: [
            if (medications.isNotEmpty) ...[
              MedicationsSection(pet: pet, medications: medications),
              const SizedBox(height: BowieSpacing.s6),
            ],
            Text(
              'Vacinas e vermífugos ${ofPet(pet)}',
              style: BowieType.title3.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s3),
            if (groups.isEmpty)
              Text(
                'Nenhuma vacina registrada ainda. Toque em "Registrar vacina" '
                'ou leia a carteirinha pelo ícone no topo.',
                style: BowieType.body.copyWith(color: colors.textMuted),
              ),
            for (final group in groups) ...[
              _GroupCard(group: group, today: today),
              const SizedBox(height: BowieSpacing.s3),
            ],
          ],
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.today});

  final VaccineGroup group;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final latest = group.latest;
    return BowieCard(
      onTap: () => context.push('/saude/doses/${latest.id}'),
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Row(
          children: [
            Icon(
              group.kind == DoseKind.vaccine
                  ? LucideIcons.syringe
                  : LucideIcons.pill,
              color: colors.categoryVaccines,
            ),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    '${group.kind.label} · aplicada em '
                    '${formatDayBr(latest.appliedOn)}',
                    style: BowieType.caption.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: BowieSpacing.s2),
                  StatusBadge(
                    status: group.statusOn(today),
                    text: describeDue(latest.nextDueOn, today),
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
