import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/domain/vaccine_names.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';

/// Registers a dose, or edits one when [doseId] is given.
class DoseFormPage extends ConsumerWidget {
  const DoseFormPage({
    super.key,
    this.petId,
    this.doseId,
    this.kind,
    this.name,
  });

  final String? petId;
  final String? doseId;
  final DoseKind? kind;
  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doseId = this.doseId;
    if (doseId == null) {
      final petId = this.petId;
      if (petId == null) {
        return const _Message('Escolha um pet na aba Saúde.');
      }
      return _DoseForm(petId: petId, kind: kind, name: name);
    }
    final dose = ref.watch(doseProvider(doseId));
    return switch (dose) {
      AsyncData(value: final VaccineDose dose) => _DoseForm(
        petId: dose.petId,
        dose: dose,
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

class _DoseForm extends ConsumerStatefulWidget {
  const _DoseForm({required this.petId, this.dose, this.kind, this.name});

  final String petId;
  final VaccineDose? dose;
  final DoseKind? kind;
  final String? name;

  @override
  ConsumerState<_DoseForm> createState() => _DoseFormState();
}

class _DoseFormState extends ConsumerState<_DoseForm> {
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _product = TextEditingController();
  final _lot = TextEditingController();
  final _veterinarian = TextEditingController();
  final _notes = TextEditingController();
  late DoseKind _kind;
  late DateTime _appliedOn;
  DateTime? _nextDueOn;
  var _details = false;
  var _saving = false;
  String? _error;

  bool get _editing => widget.dose != null;

  @override
  void initState() {
    super.initState();
    final dose = widget.dose;
    final today = ref.read(healthRepositoryProvider).today;
    if (dose != null) {
      _kind = dose.kind;
      _name.text = dose.name;
      _appliedOn = dose.appliedOn;
      _nextDueOn = dose.nextDueOn;
      _product.text = dose.product ?? '';
      _lot.text = dose.lot ?? '';
      _veterinarian.text = dose.veterinarian ?? '';
      _notes.text = dose.notes ?? '';
      _details = [
        dose.product,
        dose.lot,
        dose.veterinarian,
        dose.notes,
      ].any((value) => value != null);
    } else {
      _kind = widget.kind ?? DoseKind.vaccine;
      _name.text = widget.name ?? '';
      _appliedOn = today;
      _nextDueOn = addMonths(today, defaultIntervalMonths(_kind));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _product.dispose();
    _lot.dispose();
    _veterinarian.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(healthRepositoryProvider).today;
    final species = ref
        .watch(petDetailsProvider(widget.petId))
        .asData
        ?.value
        ?.pet
        .species;
    final nextDue = _nextDueOn;
    const gap = SizedBox(height: BowieSpacing.s4);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? 'Editar registro'
              : 'Registrar ${_kind.label.toLowerCase()}',
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
          SegmentedButton<DoseKind>(
            showSelectedIcon: false,
            segments: [
              for (final kind in DoseKind.values)
                ButtonSegment(value: kind, label: Text(kind.label)),
            ],
            selected: {_kind},
            onSelectionChanged: _editing
                ? null
                : (selection) => setState(() {
                    _kind = selection.first;
                    _nextDueOn = addMonths(
                      _appliedOn,
                      defaultIntervalMonths(_kind),
                    );
                  }),
          ),
          gap,
          RawAutocomplete<String>(
            textEditingController: _name,
            focusNode: _nameFocus,
            optionsBuilder: (value) {
              final query = foldText(value.text.trim());
              return doseSuggestions(species, _kind).where(
                (option) => query.isEmpty || foldText(option).contains(query),
              );
            },
            fieldViewBuilder: (context, controller, focusNode, _) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _kind == DoseKind.vaccine
                      ? 'Nome da vacina'
                      : 'Nome do vermífugo',
                  helperText: 'Escolha da lista ou digite outro.',
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
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
              );
            },
          ),
          gap,
          _DateField(
            label: 'Aplicada em',
            value: _appliedOn,
            onTap: () async {
              final picked = await _pickDate(_appliedOn, last: today);
              if (picked == null) return;
              setState(() {
                final shift = _nextDueOn == null
                    ? null
                    : daysBetween(_appliedOn, _nextDueOn!);
                _appliedOn = picked;
                if (shift != null) {
                  _nextDueOn = picked.add(Duration(days: shift));
                }
              });
            },
          ),
          gap,
          _DateField(
            label: _kind == DoseKind.vaccine
                ? 'Revacinar em'
                : 'Próxima dose em',
            value: nextDue,
            onTap: () async {
              final picked = await _pickDate(
                nextDue ?? addMonths(_appliedOn, 12),
                first: _appliedOn.add(const Duration(days: 1)),
                last: DateTime(today.year + 5, 12, 31),
              );
              if (picked != null) setState(() => _nextDueOn = picked);
            },
          ),
          const SizedBox(height: BowieSpacing.s2),
          Wrap(
            spacing: BowieSpacing.s2,
            children: [
              for (final (label, months) in const [
                ('+1 ano', 12),
                ('+6 meses', 6),
                ('+3 meses', 3),
              ])
                ActionChip(
                  label: Text(label),
                  onPressed: () => setState(
                    () => _nextDueOn = addMonths(_appliedOn, months),
                  ),
                ),
            ],
          ),
          if (nextDue != null) ...[
            const SizedBox(height: BowieSpacing.s2),
            Text(
              describeDue(nextDue, today),
              style: BowieType.caption.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: BowieSpacing.s2),
          if (!_details)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _details = true),
                icon: const Icon(LucideIcons.plus),
                label: const Text('Produto, lote e veterinário'),
              ),
            )
          else ...[
            gap,
            TextField(
              controller: _product,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Produto e fabricante',
                hintText: 'Ex.: Vanguard Plus, Zoetis',
              ),
            ),
            gap,
            TextField(
              controller: _lot,
              decoration: const InputDecoration(
                labelText: 'Lote',
                hintText: 'Ex.: 003/25',
              ),
            ),
            gap,
            TextField(
              controller: _veterinarian,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Veterinário',
                hintText: 'Nome e CRMV',
              ),
            ),
            gap,
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
          ],
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
              label: const Text('Excluir este registro'),
            ),
          ],
        ],
      ),
    );
  }

  Future<DateTime?> _pickDate(
    DateTime initial, {
    DateTime? first,
    required DateTime last,
  }) {
    final firstDate = first ?? DateTime(last.year - 30);
    var initialDate = initial;
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(last)) initialDate = last;
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: last,
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
          .read(healthRepositoryProvider)
          .saveDose(
            id: widget.dose?.id,
            input: DoseInput(
              petId: widget.petId,
              kind: _kind,
              name: _name.text,
              appliedOn: _appliedOn,
              nextDueOn: _nextDueOn,
              product: _product.text,
              lot: _lot.text,
              veterinarian: _veterinarian.text,
              notes: _notes.text,
            ),
            byUser: user,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Registro atualizado' : 'Registro salvo'),
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
    final dose = widget.dose;
    final user = ref.read(currentUserProvider);
    if (dose == null || user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir este registro?'),
        content: Text(
          'A dose de ${dose.name} aplicada em ${formatDayBr(dose.appliedOn)} '
          'será removida para todos os tutores.',
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
          .read(healthRepositoryProvider)
          .deleteDose(id: dose.id, byUser: user);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registro excluído')));
      context.go('/saude');
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BowieRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(LucideIcons.calendar),
        ),
        child: Text(value == null ? 'Escolher data' : formatDayBr(value)),
      ),
    );
  }
}
