import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/text.dart';
import 'package:bowie/features/health/domain/health_note.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';

/// Adds an allergy, a diet note or a special care, or edits one when
/// [noteId] is given.
class HealthNoteFormPage extends ConsumerWidget {
  const HealthNoteFormPage({super.key, this.petId, this.kind, this.noteId});

  final String? petId;
  final HealthNoteKind? kind;
  final String? noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = noteId;
    if (id == null) {
      final petId = this.petId;
      if (petId == null) return const _Message('Escolha um pet na aba Saúde.');
      return _NoteForm(petId: petId, kind: kind ?? HealthNoteKind.specialCare);
    }
    return switch (ref.watch(healthNoteProvider(id))) {
      AsyncData(value: final HealthNote note) => _NoteForm(
        petId: note.petId,
        kind: note.kind,
        note: note,
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

class _NoteForm extends ConsumerStatefulWidget {
  const _NoteForm({required this.petId, required this.kind, this.note});

  final String petId;
  final HealthNoteKind kind;
  final HealthNote? note;

  @override
  ConsumerState<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends ConsumerState<_NoteForm> {
  late final _title = TextEditingController(text: widget.note?.title);
  late final _details = TextEditingController(text: widget.note?.details);
  final _titleFocus = FocusNode();
  late HealthNoteKind _kind = widget.kind;
  var _saving = false;
  String? _error;

  bool get _editing => widget.note != null;

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const gap = SizedBox(height: BowieSpacing.s4);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar' : _kind.label)),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          SegmentedButton<HealthNoteKind>(
            showSelectedIcon: false,
            segments: [
              for (final kind in HealthNoteKind.values)
                ButtonSegment(value: kind, label: Text(kind.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          gap,
          RawAutocomplete<String>(
            textEditingController: _title,
            focusNode: _titleFocus,
            optionsBuilder: (value) {
              final query = foldText(value.text.trim());
              return healthNoteSuggestions(
                _kind,
              ).where((o) => query.isEmpty || foldText(o).contains(query));
            },
            fieldViewBuilder: (context, controller, focusNode, _) => TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: switch (_kind) {
                  HealthNoteKind.specialCare => 'Qual cuidado?',
                  HealthNoteKind.allergy => 'Alergia a quê?',
                  HealthNoteKind.diet => 'O que come?',
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
          TextField(
            controller: _details,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Detalhes (opcional)',
              hintText: switch (_kind) {
                HealthNoteKind.specialCare =>
                  'Ex.: evitar arranques, corridas e pulos',
                HealthNoteKind.allergy => 'Ex.: coceira e vermelhidão',
                HealthNoteKind.diet =>
                  'Ex.: Golden light, 150 g duas vezes ao dia',
              },
            ),
          ),
          const SizedBox(height: BowieSpacing.s2),
          Text(
            'Aparece em destaque na Saúde e na ficha que você compartilhar com '
            'hotéis, creches e veterinários.',
            style: BowieType.caption.copyWith(color: colors.textMuted),
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
            child: Text(_saving ? 'Salvando' : 'Salvar'),
          ),
          if (_editing) ...[
            const SizedBox(height: BowieSpacing.s4),
            TextButton.icon(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              icon: const Icon(LucideIcons.trash2),
              label: const Text('Excluir'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(healthNoteRepositoryProvider)
          .saveNote(
            id: widget.note?.id,
            petId: widget.petId,
            kind: _kind,
            title: _title.text,
            details: _details.text,
            byUser: user,
          );
      if (mounted) context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final note = widget.note;
    final user = ref.read(currentUserProvider);
    if (note == null || user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir "${note.title}"?'),
        content: const Text('Sai da Saúde e da ficha para todos os tutores.'),
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
          .read(healthNoteRepositoryProvider)
          .deleteNote(id: note.id, byUser: user);
      if (mounted) context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}
