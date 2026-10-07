import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/presentation/diary_providers.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/health/presentation/status_badge.dart';
import 'package:bowie/features/pets/domain/birthday.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_photo.dart';
import 'package:bowie/features/pets/presentation/pet_summary.dart';
import 'package:bowie/features/pets/presentation/pets_page.dart';

/// What matters today: each pet with its most urgent vaccine.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(petsHomeProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Início'),
        actions: const [NotificationsButton()],
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(
          child: Text('Não foi possível ler os pets salvos no celular.'),
        ),
        data: (data) {
          if (data.pets.isEmpty && data.invites.isEmpty) {
            return EmptyState(
              icon: LucideIcons.pawPrint,
              title: 'Boas-vindas ao Bowie',
              message:
                  'Comece cadastrando o seu pet. Depois, convide quem cuida dele com você.',
              action: FilledButton(
                onPressed: () => context.push('/pets/new'),
                child: const Text('Cadastrar pet'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(BowieSpacing.s4),
            children: [
              for (final invite in data.invites) ...[
                BowieCard(
                  onTap: () => context.go('/pets'),
                  child: ListTile(
                    leading: Icon(LucideIcons.mail, color: colors.info),
                    title: Text(
                      'Convite para cuidar de ${invite.petName}',
                      style: BowieType.bodyStrong,
                    ),
                    subtitle: const Text('Toque para ver e aceitar.'),
                  ),
                ),
                const SizedBox(height: BowieSpacing.s3),
              ],
              for (final pet in data.pets) ...[
                PetPhotoCard(
                  pet: pet,
                  large: true,
                  subtitle: petSummary(pet, DateTime.now()),
                  below: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Birthday(pet: pet),
                      _NextVaccine(petId: pet.id),
                      _TodayDoses(petId: pet.id),
                      _NextAppointment(petId: pet.id),
                    ],
                  ),
                  onTap: () => context.push('/pets/${pet.id}'),
                ),
                const SizedBox(height: BowieSpacing.s3),
              ],
              const _AddPetCard(),
            ],
          );
        },
      ),
    );
  }
}

/// "Faltam 30 dias para o aniversário do Bowie", from 30 days before.
class _Birthday extends StatelessWidget {
  const _Birthday({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final notice = birthdayNotice(pet, DateTime.now());
    if (notice == null) return const SizedBox.shrink();
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: BowieSpacing.s2),
      child: Row(
        children: [
          Icon(LucideIcons.cake, size: 18, color: BrandColors.smile),
          const SizedBox(width: BowieSpacing.s2),
          Flexible(
            child: Text(
              notice,
              style: BowieType.callout.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Remédios de hoje: 2 de 5 dados".
class _TodayDoses extends ConsumerWidget {
  const _TodayDoses({required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(todayDosesProvider(petId)).asData?.value;
    if (slots == null || slots.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final given = slots.where((slot) => slot.given != null).length;
    final pending = slots.where((slot) => slot.given == null).toList();
    final next = pending.firstOrNull;
    final text = pending.isEmpty
        ? 'Remédios de hoje: todos dados'
        : [
            'Remédios de hoje: $given de ${slots.length} dados',
            if (next != null)
              'próximo: ${next.medication.name}'
                  '${next.time == null ? '' : ' às ${next.time!.time}'}',
          ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(top: BowieSpacing.s2),
      child: Row(
        children: [
          Icon(
            pending.isEmpty ? LucideIcons.circleCheck : LucideIcons.pill,
            size: 16,
            color: pending.isEmpty ? colors.success : colors.textMuted,
          ),
          const SizedBox(width: BowieSpacing.s1),
          Flexible(
            child: Text(
              text,
              style: BowieType.caption.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's timed entries and the next scheduled one, from the diary.
class _NextAppointment extends ConsumerWidget {
  const _NextAppointment({required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(petEventsProvider(petId)).asData?.value;
    final today = ref.watch(diaryRepositoryProvider).today;
    final colors = context.colors;
    if (events == null) return const SizedBox.shrink();
    final todayTimed =
        events.where((e) => e.occursOn == today && e.time != null).toList()
          ..sort((a, b) => a.time!.compareTo(b.time!));
    final next =
        todayTimed.firstOrNull ?? upcomingEvents(events, today).firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final when = [
      describeDay(next.occursOn, today),
      if (next.time != null) 'às ${next.time}',
    ].join(' ');
    return Padding(
      padding: const EdgeInsets.only(top: BowieSpacing.s2),
      child: Row(
        children: [
          Icon(LucideIcons.calendarClock, size: 16, color: colors.textMuted),
          const SizedBox(width: BowieSpacing.s1),
          Flexible(
            child: Text(
              '${next.title} · $when',
              style: BowieType.caption.copyWith(
                color: colors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A blank pet card that opens the registration of a new pet.
class _AddPetCard extends StatelessWidget {
  const _AddPetCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BowieCard(
      onTap: () => context.push('/pets/new'),
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox.square(
                dimension: 56,
                child: ColoredBox(
                  color: colors.surfaceMuted,
                  child: Icon(LucideIcons.plus, color: colors.textMuted),
                ),
              ),
            ),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adicionar novo pet',
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    'Cão ou gato, com foto e carteirinha.',
                    style: BowieType.callout.copyWith(color: colors.textMuted),
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

/// The most urgent vaccine of a pet, or an invitation to register one.
class _NextVaccine extends ConsumerWidget {
  const _NextVaccine({required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(vaccineGroupsProvider(petId)).asData?.value;
    final today = ref.watch(healthRepositoryProvider).today;
    final colors = context.colors;
    if (groups == null) return const SizedBox.shrink();
    if (groups.isEmpty) {
      return Text(
        'Nenhuma vacina registrada ainda. Registre na aba Saúde.',
        style: BowieType.callout.copyWith(color: colors.textMuted),
      );
    }
    final next = groups.first;
    return StatusBadge(
      status: next.statusOn(today),
      text: '${next.name}: ${describeDue(next.latest.nextDueOn, today)}',
    );
  }
}
