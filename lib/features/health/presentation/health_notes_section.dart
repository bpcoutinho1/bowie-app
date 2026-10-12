import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/features/health/domain/health_note.dart';
import 'package:bowie/features/pets/domain/pet.dart';

IconData healthNoteIcon(HealthNoteKind kind) => switch (kind) {
  HealthNoteKind.specialCare => LucideIcons.triangleAlert,
  HealthNoteKind.allergy => LucideIcons.shieldAlert,
  HealthNoteKind.diet => LucideIcons.utensils,
};

/// "Importante sobre o Bowie": special care, allergies and diet, at the top
/// of Saúde so nobody misses them.
class HealthNotesSection extends StatelessWidget {
  const HealthNotesSection({super.key, required this.pet, required this.notes});

  final Pet pet;
  final List<HealthNote> notes;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Importante sobre ${pet.name}',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
        ),
        const SizedBox(height: BowieSpacing.s3),
        BowieCard(
          child: Column(
            children: [
              for (var i = 0; i < notes.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                _NoteTile(note: notes[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final HealthNote note;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final warn = note.kind != HealthNoteKind.diet;
    return ListTile(
      onTap: () => context.push('/saude/notas/${note.id}'),
      leading: Icon(
        healthNoteIcon(note.kind),
        color: warn ? colors.warning : colors.textMuted,
      ),
      title: Text(
        note.title,
        style: BowieType.bodyStrong.copyWith(color: colors.text),
      ),
      subtitle: Text(
        [note.kind.label, ?note.details].join(' · '),
        style: BowieType.callout.copyWith(color: colors.textMuted),
      ),
      trailing: Icon(LucideIcons.chevronRight, color: colors.textMuted),
    );
  }
}

/// The single "+" of Saúde: what to add.
Future<void> showHealthAddSheet(BuildContext context, String petId) async {
  final route = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final colors = sheet.colors;
      Widget option(IconData icon, String title, String subtitle, String to) {
        return ListTile(
          leading: Icon(icon, color: colors.text),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: () => Navigator.of(sheet).pop(to),
        );
      }

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
                  'O que você quer registrar?',
                  style: BowieType.title3.copyWith(color: colors.text),
                ),
              ),
              option(
                LucideIcons.pill,
                'Medicação',
                'Remédio com dose, horários e duração',
                '/saude/medicacoes/nova?pet=$petId',
              ),
              option(
                LucideIcons.syringe,
                'Vacina ou vermífugo',
                'Dose aplicada e quando vence',
                '/saude/doses/nova?pet=$petId',
              ),
              option(
                healthNoteIcon(HealthNoteKind.allergy),
                'Alergia',
                'Alimento, remédio ou outra substância',
                '/saude/notas/nova?pet=$petId&tipo=allergy',
              ),
              option(
                healthNoteIcon(HealthNoteKind.diet),
                'Alimentação',
                'Ração, quantidade e o que não pode comer',
                '/saude/notas/nova?pet=$petId&tipo=diet',
              ),
              option(
                healthNoteIcon(HealthNoteKind.specialCare),
                'Cuidado especial',
                'Condição de saúde ou comportamento',
                '/saude/notas/nova?pet=$petId&tipo=special_care',
              ),
            ],
          ),
        ),
      );
    },
  );
  if (route != null && context.mounted) context.push(route);
}
