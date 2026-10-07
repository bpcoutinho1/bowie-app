import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/features/contacts/domain/contact.dart';
import 'package:bowie/features/contacts/presentation/contacts_providers.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/diary/presentation/diary_providers.dart';
import 'package:bowie/features/diary/presentation/event_photos.dart';

/// Records or schedules a diary entry, or edits one when [eventId] is given.
class EventFormPage extends ConsumerWidget {
  const EventFormPage({super.key, this.petId, this.eventId, this.day});

  final String? petId;
  final String? eventId;
  final DateTime? day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventId = this.eventId;
    if (eventId == null) {
      final petId = this.petId;
      if (petId == null) {
        return const _Message('Escolha um pet na aba Diário.');
      }
      return _EventForm(petId: petId, day: day);
    }
    return switch (ref.watch(petEventProvider(eventId))) {
      AsyncData(value: final PetEvent event) => _EventForm(
        petId: event.petId,
        event: event,
      ),
      AsyncData() => const _Message('Este registro não está mais disponível.'),
      AsyncError() => const _Message('Não foi possível ler este registro.'),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(text)),
    );
  }
}

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({required this.petId, this.event, this.day});

  final String petId;
  final PetEvent? event;
  final DateTime? day;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _notes = TextEditingController();
  var _photos = <EventPhoto>[];
  late EventKind _kind;
  late DateTime _day;
  TimeOfDay? _time;
  String? _contactId;
  var _saving = false;
  String? _error;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final today = ref.read(diaryRepositoryProvider).today;
    if (event != null) {
      _kind = event.kind;
      _title.text = event.title;
      _day = event.occursOn;
      _notes.text = event.notes ?? '';
      _contactId = event.contactId;
      _photos = [for (final path in event.photoPaths) EventPhoto.saved(path)];
      final time = event.time;
      if (time != null) {
        _time = TimeOfDay(
          hour: int.parse(time.substring(0, 2)),
          minute: int.parse(time.substring(3, 5)),
        );
      }
    } else {
      _day = widget.day ?? today;
      // A future day is usually an appointment; today, often a symptom.
      _kind = _day.isAfter(today) ? EventKind.vetVisit : EventKind.symptom;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _titleFocus.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(diaryRepositoryProvider).today;
    final scheduled = _day.isAfter(today);
    final contacts =
        ref.watch(petContactsProvider(widget.petId)).asData?.value ??
        const <Contact>[];
    final currentContact = _contactId == null
        ? null
        : ref.watch(contactProvider(_contactId!)).asData?.value;
    const gap = SizedBox(height: BowieSpacing.s4);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Editar registro'
              : scheduled
              ? 'Agendar'
              : 'Registrar no diário',
        ),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          SegmentedButton<EventKind>(
            showSelectedIcon: false,
            segments: [
              for (final kind in EventKind.values)
                ButtonSegment(value: kind, label: Text(kind.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (selection) =>
                setState(() => _kind = selection.first),
          ),
          if (_kind == EventKind.symptom) ...[
            const SizedBox(height: BowieSpacing.s3),
            Text(
              'O diário registra o que aconteceu, sem diagnóstico. Em sintomas '
              'fortes ou que não passam, procure um veterinário.',
              style: BowieType.caption.copyWith(color: colors.textMuted),
            ),
          ],
          gap,
          RawAutocomplete<String>(
            textEditingController: _title,
            focusNode: _titleFocus,
            optionsBuilder: (value) {
              final query = foldText(value.text.trim());
              return eventSuggestions(_kind).where(
                (option) => query.isEmpty || foldText(option).contains(query),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, _) => TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: switch (_kind) {
                  EventKind.symptom => 'O que aconteceu?',
                  EventKind.vetVisit => 'Tipo de consulta',
                  EventKind.exam => 'Qual exame?',
                  EventKind.other => 'O que é?',
                },
                helperText: 'Escolha da lista ou digite outro.',
              ),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: colors.surface,
                elevation: 4,
                borderRadius: BorderRadius.circular(BowieRadius.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 260,
                    maxWidth: 360,
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: [
                      for (final option in options)
                        ListTile(
                          title: Text(option),
                          onTap: () => onSelected(option),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          gap,
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _PickerField(
                  label: 'Dia',
                  value: formatDayBr(_day),
                  icon: LucideIcons.calendar,
                  onTap: _pickDay,
                ),
              ),
              const SizedBox(width: BowieSpacing.s3),
              Expanded(
                flex: 2,
                child: _PickerField(
                  label: 'Horário',
                  value: _time == null ? 'Opcional' : _formatTime(_time!),
                  icon: LucideIcons.clock,
                  onTap: _pickTime,
                  onClear: _time == null
                      ? null
                      : () => setState(() => _time = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: BowieSpacing.s2),
          Text(
            describeDay(_day, today) + (scheduled ? ' · agendado' : ''),
            style: BowieType.caption.copyWith(color: colors.textMuted),
          ),
          gap,
          DropdownButtonFormField<String?>(
            initialValue:
                contacts.any((c) => c.id == _contactId) || _contactId == null
                ? _contactId
                : null,
            decoration: InputDecoration(
              labelText: 'Profissional ou local',
              helperText: contacts.isEmpty
                  ? 'Cadastre veterinários e clínicas em Pets → Contatos.'
                  : currentContact != null &&
                        !contacts.any((c) => c.id == _contactId)
                  ? '${currentContact.name} não está mais nos contatos.'
                  : null,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Nenhum'),
              ),
              for (final contact in contacts)
                DropdownMenuItem<String?>(
                  value: contact.id,
                  child: Text('${contact.name} · ${contact.category.label}'),
                ),
            ],
            onChanged: (value) => setState(() => _contactId = value),
          ),
          gap,
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Observações',
              hintText: switch (_kind) {
                EventKind.symptom => 'Quantas vezes, como estava, o que comeu',
                EventKind.vetVisit =>
                  'O que foi dito, remédios, próximos passos',
                EventKind.exam => 'Jejum, preparo, resultado',
                EventKind.other => null,
              },
            ),
          ),
          gap,
          EventPhotosField(
            photos: _photos,
            onChanged: (photos) => setState(() {
              _photos = photos;
              _error = null;
            }),
            onError: (message) => setState(() => _error = message),
          ),
          if (_error != null) ...[
            const SizedBox(height: BowieSpacing.s3),
            Text(
              _error!,
              style: BowieType.callout.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: BowieSpacing.s6),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving
                  ? 'Salvando'
                  : scheduled && !_editing
                  ? 'Agendar'
                  : 'Salvar',
            ),
          ),
          if (_editing) ...[
            const SizedBox(height: BowieSpacing.s4),
            TextButton.icon(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              icon: const Icon(LucideIcons.trash2),
              label: const Text('Excluir este registro'),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDay() async {
    final today = ref.read(diaryRepositoryProvider).today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final today = ref.read(diaryRepositoryProvider).today;
      await ref
          .read(diaryRepositoryProvider)
          .saveEvent(
            id: widget.event?.id,
            input: EventInput(
              petId: widget.petId,
              kind: _kind,
              title: _title.text,
              occursOn: _day,
              time: _time == null ? null : _formatTime(_time!),
              notes: _notes.text,
              keptPhotos: [for (final photo in _photos) ?photo.path],
              newPhotos: [for (final photo in _photos) ?photo.bytes],
              contactId: _contactId,
            ),
            byUser: user,
          );
      if (!mounted) return;
      ref.read(diaryDayProvider.notifier).select(_day);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Registro atualizado'
                : _day.isAfter(today)
                ? 'Agendado para ${formatDayLong(_day)}'
                : 'Registrado no diário',
          ),
        ),
      );
      context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final event = widget.event;
    final user = ref.read(currentUserProvider);
    if (event == null || user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir este registro?'),
        content: Text(
          '${event.title} de ${formatDayBr(event.occursOn)} será removido '
          'para todos os tutores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(diaryRepositoryProvider)
          .deleteEvent(id: event.id, byUser: user);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registro excluído')));
      context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BowieRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear == null
              ? Icon(icon)
              : IconButton(
                  tooltip: 'Tirar o horário',
                  onPressed: onClear,
                  icon: const Icon(LucideIcons.x),
                ),
        ),
        child: Text(value),
      ),
    );
  }
}
