import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/diary/data/diary_repository.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';

/// A PDF on the diary form: already saved, or just chosen.
class EventFileItem {
  const EventFileItem.saved(EventFile this.saved) : fresh = null;

  const EventFileItem.fresh(NewEventFile this.fresh) : saved = null;

  final EventFile? saved;
  final NewEventFile? fresh;

  String get name => saved?.name ?? cleanFileName(fresh!.name);
}

/// The file on the phone, downloaded first when another tutor added it.
Future<File?> localEventFile(WidgetRef ref, String path) async {
  final files = ref.read(petPhotoStoreProvider);
  final local = await files.local(path);
  if (local != null) return local;
  final bytes = await ref.read(petRemoteApiProvider)?.downloadPhoto(path);
  if (bytes == null) return null;
  await files.write(path, bytes);
  return files.local(path);
}

Future<void> openEventFile(
  BuildContext context,
  WidgetRef ref,
  EventFile file,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final local = await localEventFile(ref, file.path);
  if (local == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível abrir o arquivo. Confira a internet e tente de novo.',
        ),
      ),
    );
    return;
  }
  final opened = await ref
      .read(documentOpenerProvider)
      .open(local, name: file.name);
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Nenhum app deste celular abre PDF.')),
    );
  }
}

/// The PDFs of an entry, in the diary list: tap to open.
class EventFileChips extends ConsumerWidget {
  const EventFileChips({super.key, required this.files});

  final List<EventFile> files;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Wrap(
      spacing: BowieSpacing.s2,
      runSpacing: BowieSpacing.s2,
      children: [
        for (final file in files)
          ActionChip(
            avatar: Icon(LucideIcons.fileText, size: 18, color: colors.text),
            label: Text(file.name, overflow: TextOverflow.ellipsis),
            tooltip: 'Abrir ${file.name}',
            onPressed: () => openEventFile(context, ref, file),
          ),
      ],
    );
  }
}

/// "Arquivos" on the diary form: the PDFs of the entry, with remove, and
/// "Adicionar PDF".
class EventFilesField extends ConsumerWidget {
  const EventFilesField({
    super.key,
    required this.files,
    required this.onChanged,
    required this.onError,
  });

  final List<EventFileItem> files;
  final ValueChanged<List<EventFileItem>> onChanged;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final room = maxEventFiles - files.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Arquivos',
          style: BowieType.bodyStrong.copyWith(color: colors.text),
        ),
        const SizedBox(height: BowieSpacing.s1),
        Text(
          'Resultados de exames, receitas e laudos em PDF, até 10 MB cada. '
          'Entram na ficha que você compartilhar com o veterinário.',
          style: BowieType.caption.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: BowieSpacing.s2),
        for (var i = 0; i < files.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.fileText, color: colors.text),
            title: Text(
              files[i].name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: switch (files[i].saved) {
              final EventFile saved => () => openEventFile(context, ref, saved),
              null => null,
            },
            trailing: IconButton(
              tooltip: 'Remover ${files[i].name}',
              onPressed: () => onChanged([...files]..removeAt(i)),
              icon: Icon(LucideIcons.x, color: colors.textMuted),
            ),
          ),
        if (room > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _add(ref, room),
              icon: const Icon(LucideIcons.filePlus),
              label: const Text('Adicionar PDF'),
            ),
          ),
      ],
    );
  }

  Future<void> _add(WidgetRef ref, int room) async {
    try {
      final picked = await ref
          .read(documentPickerProvider)
          .pickPdfs(max: room, maxBytes: maxEventFileBytes);
      if (picked.isEmpty) return;
      onChanged([
        ...files,
        for (final doc in picked)
          EventFileItem.fresh(NewEventFile(name: doc.name, bytes: doc.bytes)),
      ]);
    } on AppFailure catch (error) {
      onError(error.message);
    } catch (_) {
      onError('Não foi possível abrir os arquivos do celular.');
    }
  }
}
