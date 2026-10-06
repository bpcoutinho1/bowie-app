import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/empty_state.dart';
import 'package:bowie/core/ui/notifications_button.dart';
import 'package:bowie/features/contacts/presentation/contact_actions.dart';
import 'package:bowie/features/contacts/presentation/contacts_providers.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/diary/presentation/diary_providers.dart';
import 'package:bowie/features/diary/presentation/month_calendar.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_selector.dart';
import 'package:bowie/features/pets/presentation/pets_page.dart';

/// The pet's diary: what happened (a diarrhea, a visit to the vet) and what
/// is scheduled (an ultrasound next week), on a calendar.
class DiaryPage extends ConsumerWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(petsHomeProvider);
    final pets = home.asData?.value.pets ?? const <Pet>[];
    final selectedId = ref.watch(selectedPetIdProvider);
    final pet =
        pets.where((p) => p.id == selectedId).firstOrNull ?? pets.firstOrNull;
    final today = ref.watch(diaryRepositoryProvider).today;
    final day = ref.watch(diaryDayProvider) ?? today;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diário'),
        actions: const [NotificationsButton()],
      ),
      floatingActionButton: pet == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(
                '/diario/novo?pet=${pet.id}&dia=${formatDay(day)}',
              ),
              icon: const Icon(LucideIcons.plus),
              label: Text(day.isAfter(today) ? 'Agendar' : 'Registrar'),
            ),
      body: switch (home) {
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => const Center(
          child: Text('Não foi possível ler os pets salvos no celular.'),
        ),
        _ when pet == null => EmptyState(
          icon: LucideIcons.notebookPen,
          title: 'Nenhum pet ainda',
          message: 'Cadastre um pet para começar o diário dele.',
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
            Expanded(
              child: _Diary(pet: pet, day: day, today: today),
            ),
          ],
        ),
      },
    );
  }
}

class _Diary extends ConsumerStatefulWidget {
  const _Diary({required this.pet, required this.day, required this.today});

  final Pet pet;
  final DateTime day;
  final DateTime today;

  @override
  ConsumerState<_Diary> createState() => _DiaryState();
}

class _DiaryState extends ConsumerState<_Diary> {
  late DateTime _month = widget.day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final events =
        ref.watch(petEventsProvider(widget.pet.id)).asData?.value ??
        const <PetEvent>[];
    final counts = <DateTime, int>{};
    for (final event in events) {
      counts.update(event.occursOn, (n) => n + 1, ifAbsent: () => 1);
    }
    final ofDay = sortEvents(events.where((e) => e.occursOn == widget.day));
    final upcoming = upcomingEvents(
      events,
      widget.today,
    ).where((e) => e.occursOn != widget.day).take(5).toList();
    final recent = events
        .where((e) => !e.isScheduled(widget.today) && e.occursOn != widget.day)
        .take(5)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BowieSpacing.s4,
        0,
        BowieSpacing.s4,
        96,
      ),
      children: [
        BowieCard(
          child: Padding(
            padding: const EdgeInsets.all(BowieSpacing.s2),
            child: MonthCalendar(
              month: _month,
              selected: widget.day,
              today: widget.today,
              counts: counts,
              onSelect: (day) {
                ref.read(diaryDayProvider.notifier).select(day);
                setState(() => _month = day);
              },
              onMonth: (month) => setState(() => _month = month),
            ),
          ),
        ),
        const SizedBox(height: BowieSpacing.s6),
        Semantics(
          header: true,
          child: Text(
            describeDay(widget.day, widget.today),
            style: BowieType.title3.copyWith(color: colors.text),
          ),
        ),
        const SizedBox(height: BowieSpacing.s3),
        if (ofDay.isEmpty)
          Text(
            widget.day.isAfter(widget.today)
                ? 'Nada agendado para este dia. Toque em "Agendar" para marcar '
                      'uma consulta ou um exame.'
                : 'Nada registrado neste dia. Toque em "Registrar" para '
                      'anotar um sintoma, uma consulta ou um exame.',
            style: BowieType.body.copyWith(color: colors.textMuted),
          )
        else
          for (final event in ofDay) ...[
            EventCard(event: event, today: widget.today),
            const SizedBox(height: BowieSpacing.s3),
          ],
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: BowieSpacing.s6),
          _SectionTitle('Próximos agendamentos'),
          const SizedBox(height: BowieSpacing.s3),
          for (final event in upcoming) ...[
            EventCard(event: event, today: widget.today, showDay: true),
            const SizedBox(height: BowieSpacing.s3),
          ],
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: BowieSpacing.s6),
          _SectionTitle('Registros recentes'),
          const SizedBox(height: BowieSpacing.s3),
          for (final event in recent) ...[
            EventCard(event: event, today: widget.today, showDay: true),
            const SizedBox(height: BowieSpacing.s3),
          ],
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: BowieType.title3.copyWith(color: context.colors.text),
      ),
    );
  }
}

IconData eventIcon(EventKind kind) => switch (kind) {
  EventKind.symptom => LucideIcons.thermometer,
  EventKind.vetVisit => LucideIcons.stethoscope,
  EventKind.exam => LucideIcons.microscope,
  EventKind.other => LucideIcons.notebookPen,
};

/// One diary entry: kind, title, when, who, and the start of the notes.
class EventCard extends ConsumerWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.today,
    this.showDay = false,
  });

  final PetEvent event;
  final DateTime today;
  final bool showDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final contactId = event.contactId;
    final contact = contactId == null
        ? null
        : ref.watch(contactProvider(contactId)).asData?.value;
    final scheduled = event.isScheduled(today);
    final when = [
      if (showDay) describeDay(event.occursOn, today),
      if (event.time != null) 'às ${event.time}',
    ].join(' ');
    final phone = contact?.phone;

    return BowieCard(
      onTap: () => context.push('/diario/${event.id}'),
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(eventIcon(event.kind), color: colors.categoryIncidents),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    [
                      event.kind.label,
                      if (scheduled) 'Agendado',
                      if (when.isNotEmpty) when,
                    ].join(' · '),
                    style: BowieType.callout.copyWith(color: colors.textMuted),
                  ),
                  if (contact != null)
                    Text(
                      contact.name,
                      style: BowieType.callout.copyWith(color: colors.text),
                    ),
                  if (event.notes != null) ...[
                    const SizedBox(height: BowieSpacing.s1),
                    Text(
                      event.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BowieType.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (phone != null)
              IconButton(
                tooltip: 'Ligar para ${contact!.name}',
                onPressed: () => openContactLink(context, callUri(phone)),
                icon: Icon(LucideIcons.phone, color: colors.text),
              ),
          ],
        ),
      ),
    );
  }
}
