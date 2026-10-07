import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/health/data/medication_repository.dart';
import 'package:bowie/features/health/domain/medication.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';

/// Registers a medication, or edits one when [medicationId] is given.
class MedicationFormPage extends ConsumerWidget {
  const MedicationFormPage({super.key, this.petId, this.medicationId});

  final String? petId;
  final String? medicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = medicationId;
    if (id == null) {
      final petId = this.petId;
      if (petId == null) return const _Message('Escolha um pet na aba Saúde.');
      return _MedicationForm(petId: petId);
    }
    return switch (ref.watch(medicationProvider(id))) {
      AsyncData(value: final Medication medication) => _MedicationForm(
        petId: medication.petId,
        medication: medication,
      ),
      AsyncData() => const _Message('Este remédio não está mais disponível.'),
      AsyncError() => const _Message('Não foi possível ler este remédio.'),
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

class _MedicationForm extends ConsumerStatefulWidget {
  const _MedicationForm({required this.petId, this.medication});

  final String petId;
  final Medication? medication;

  @override
  ConsumerState<_MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends ConsumerState<_MedicationForm> {
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _amount = TextEditingController(text: '1');
  final _interval = TextEditingController(text: '2');
  final _notes = TextEditingController();
  var _unit = DoseUnit.tablet;
  var _frequency = MedFrequency.daily;

  /// The chosen periods and their times.
  final _times = <DosePeriod, String>{};
  late DateTime _start;
  DateTime? _end;
  var _continuous = true;
  var _saving = false;
  String? _error;

  bool get _editing => widget.medication != null;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _start = ref.read(medicationRepositoryProvider).today;
    if (med == null) {
      _times[DosePeriod.morning] = DosePeriod.morning.defaultTime;
      return;
    }
    _name.text = med.name;
    _strength.text = med.strength ?? '';
    _amount.text = med.amount == med.amount.roundToDouble()
        ? med.amount.toStringAsFixed(0)
        : med.amount.toString().replaceAll('.', ',');
    _unit = med.unit;
    _frequency = med.frequency;
    _interval.text = '${med.interval}';
    for (final t in med.times) {
      _times[t.period] = t.time;
    }
    _start = med.startOn;
    _end = med.endOn;
    _continuous = med.endOn == null;
    _notes.text = med.notes ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _amount.dispose();
    _interval.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const gap = SizedBox(height: BowieSpacing.s4);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar remédio' : 'Registrar medicação'),
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
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do remédio',
              hintText: 'Ex.: Pregabalina, Omega 3',
            ),
          ),
          gap,
          TextField(
            controller: _strength,
            decoration: const InputDecoration(
              labelText: 'Concentração (opcional)',
              hintText: 'Ex.: 75 mg',
            ),
          ),
          gap,
          Text(
            'Cada dose',
            style: BowieType.bodyStrong.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                ),
              ),
              const SizedBox(width: BowieSpacing.s3),
              Expanded(
                child: DropdownButtonFormField<DoseUnit>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unidade'),
                  items: [
                    for (final unit in DoseUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.plural)),
                  ],
                  onChanged: (unit) => setState(() => _unit = unit ?? _unit),
                ),
              ),
            ],
          ),
          gap,
          DropdownButtonFormField<MedFrequency>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequência'),
            items: [
              for (final frequency in MedFrequency.values)
                DropdownMenuItem(
                  value: frequency,
                  child: Text(frequency.label),
                ),
            ],
            onChanged: (value) =>
                setState(() => _frequency = value ?? _frequency),
          ),
          if (_frequency == MedFrequency.everyDays ||
              _frequency == MedFrequency.everyMonths) ...[
            gap,
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _frequency == MedFrequency.everyDays
                    ? 'A cada quantos dias?'
                    : 'A cada quantos meses?',
              ),
            ),
          ],
          if (_frequency == MedFrequency.daily) ...[
            gap,
            Text(
              'Períodos e horários',
              style: BowieType.bodyStrong.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s2),
            for (final period in DosePeriod.values)
              _PeriodRow(
                period: period,
                time: _times[period],
                onToggle: (on) => setState(() {
                  if (on) {
                    _times[period] = period.defaultTime;
                  } else {
                    _times.remove(period);
                  }
                }),
                onPickTime: () => _pickTime(period),
              ),
          ] else ...[
            const SizedBox(height: BowieSpacing.s2),
            Text(
              'As próximas datas seguem a data de início.',
              style: BowieType.caption.copyWith(color: colors.textMuted),
            ),
          ],
          gap,
          _DateField(
            label: 'Início',
            value: _start,
            onTap: () async {
              final picked = await _pickDate(_start);
              if (picked != null) setState(() => _start = picked);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Uso contínuo'),
            subtitle: const Text('Sem data para acabar, como o Omega 3'),
            value: _continuous,
            onChanged: (value) => setState(() {
              _continuous = value;
              if (!value) _end ??= addMonths(_start, 1);
            }),
          ),
          if (!_continuous)
            _DateField(
              label: 'Fim do tratamento',
              value: _end,
              onTap: () async {
                final picked = await _pickDate(_end ?? _start);
                if (picked != null) setState(() => _end = picked);
              },
            ),
          gap,
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
              hintText: 'Ex.: dar junto com a comida',
            ),
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
              label: const Text('Excluir este remédio'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickTime(DosePeriod period) async {
    final current = _times[period] ?? period.defaultTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(current.substring(0, 2)),
        minute: int.parse(current.substring(3, 5)),
      ),
    );
    if (picked == null) return;
    setState(
      () => _times[period] =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    final today = ref.read(medicationRepositoryProvider).today;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 5, 12, 31),
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
          .read(medicationRepositoryProvider)
          .saveMedication(
            id: widget.medication?.id,
            input: MedicationInput(
              petId: widget.petId,
              name: _name.text,
              strength: _strength.text,
              amount: double.tryParse(_amount.text.replaceAll(',', '.')),
              unit: _unit,
              frequency: _frequency,
              interval: int.tryParse(_interval.text) ?? 0,
              times: [
                for (final entry in _times.entries)
                  DoseTime(entry.key, entry.value),
              ],
              startOn: _start,
              endOn: _continuous ? null : _end,
              notes: _notes.text,
            ),
            byUser: user,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editing ? 'Remédio atualizado' : 'Remédio registrado'),
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
    final med = widget.medication;
    final user = ref.read(currentUserProvider);
    if (med == null || user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir ${med.name}?'),
        content: const Text(
          'O remédio sai da lista de todos os tutores. Se o tratamento só '
          'terminou, prefira desligar "Uso contínuo" e marcar a data de fim.',
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
          .read(medicationRepositoryProvider)
          .deleteMedication(id: med.id, byUser: user);
      if (mounted) context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
  });

  final DosePeriod period;
  final String? time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) {
    final time = this.time;
    final icon = switch (period) {
      DosePeriod.morning => LucideIcons.sunrise,
      DosePeriod.afternoon => LucideIcons.sun,
      DosePeriod.night => LucideIcons.moon,
    };
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: time != null,
            onChanged: (value) => onToggle(value ?? false),
            secondary: Icon(icon, color: context.colors.textMuted),
            title: Text(period.label),
          ),
        ),
        if (time != null)
          OutlinedButton.icon(
            onPressed: onPickTime,
            icon: const Icon(LucideIcons.clock, size: 18),
            label: Text(time),
          ),
      ],
    );
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
