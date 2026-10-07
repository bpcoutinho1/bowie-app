import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/photo_picker.dart';
import 'package:bowie/features/diary/domain/pet_event.dart';
import 'package:bowie/features/pets/presentation/pet_photo.dart';

/// A photo of a diary entry: already saved ([path]) or just taken ([bytes]).
class EventPhoto {
  const EventPhoto.saved(String this.path) : bytes = null;

  const EventPhoto.fresh(Uint8List this.bytes) : path = null;

  final String? path;
  final Uint8List? bytes;
}

/// A square thumbnail. Saved photos come from the phone, or from the server
/// when another tutor took them.
class EventPhotoThumb extends ConsumerWidget {
  const EventPhotoThumb({super.key, required this.photo, this.size = 64});

  final EventPhoto photo;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final bytes = photo.bytes;
    final path = photo.path;
    final cache = (size * 3).round();
    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover, cacheWidth: cache);
    } else {
      final File? file = path == null
          ? null
          : ref.watch(petPhotoProvider(path)).asData?.value;
      image = file == null
          ? ColoredBox(
              color: colors.surfaceMuted,
              child: Icon(LucideIcons.image, color: colors.textMuted),
            )
          : Image.file(file, fit: BoxFit.cover, cacheWidth: cache);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(BowieRadius.md),
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}

/// A row of thumbnails; a tap opens the photo full screen, with zoom.
class EventPhotoStrip extends StatelessWidget {
  const EventPhotoStrip({super.key, required this.paths, this.size = 64});

  final List<String> paths;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photos = [for (final path in paths) EventPhoto.saved(path)];
    return Wrap(
      spacing: BowieSpacing.s2,
      runSpacing: BowieSpacing.s2,
      children: [
        for (var i = 0; i < photos.length; i++)
          Semantics(
            button: true,
            label: 'Ver a foto ${i + 1} de ${photos.length}',
            child: InkWell(
              borderRadius: BorderRadius.circular(BowieRadius.md),
              onTap: () => showEventPhotos(context, photos, i),
              child: EventPhotoThumb(photo: photos[i], size: size),
            ),
          ),
      ],
    );
  }
}

/// The photos full screen: swipe between them, pinch to zoom.
Future<void> showEventPhotos(
  BuildContext context,
  List<EventPhoto> photos,
  int initial,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PhotoGallery(photos: photos, initial: initial),
    ),
  );
}

class _PhotoGallery extends ConsumerStatefulWidget {
  const _PhotoGallery({required this.photos, required this.initial});

  final List<EventPhoto> photos;
  final int initial;

  @override
  ConsumerState<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends ConsumerState<_PhotoGallery> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photos.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(total == 1 ? 'Foto' : 'Foto ${_index + 1} de $total'),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: total,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) {
          final photo = widget.photos[index];
          final bytes = photo.bytes;
          final path = photo.path;
          final Widget image;
          if (bytes != null) {
            image = Image.memory(bytes);
          } else {
            final file = path == null
                ? null
                : ref.watch(petPhotoProvider(path)).asData?.value;
            image = file == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Image.file(file);
          }
          return InteractiveViewer(maxScale: 6, child: Center(child: image));
        },
      ),
    );
  }
}

/// The photos on the diary form: thumbnails with a remove button, and a tile
/// to take or choose more.
class EventPhotosField extends ConsumerWidget {
  const EventPhotosField({
    super.key,
    required this.photos,
    required this.onChanged,
    required this.onError,
  });

  final List<EventPhoto> photos;
  final ValueChanged<List<EventPhoto>> onChanged;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    const size = 88.0;
    final room = maxEventPhotos - photos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos', style: BowieType.bodyStrong.copyWith(color: colors.text)),
        const SizedBox(height: BowieSpacing.s1),
        Text(
          'Ajudam a comparar depois e a mostrar ao veterinário. Só os tutores '
          'do pet veem.',
          style: BowieType.caption.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: BowieSpacing.s3),
        Wrap(
          spacing: BowieSpacing.s2,
          runSpacing: BowieSpacing.s2,
          children: [
            for (var i = 0; i < photos.length; i++)
              Stack(
                children: [
                  Semantics(
                    button: true,
                    label: 'Ver a foto ${i + 1}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(BowieRadius.md),
                      onTap: () => showEventPhotos(context, photos, i),
                      child: EventPhotoThumb(photo: photos[i], size: size),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: 'Remover a foto ${i + 1}',
                      onPressed: () => onChanged([...photos]..removeAt(i)),
                      style: IconButton.styleFrom(
                        backgroundColor: colors.surface,
                        foregroundColor: colors.text,
                      ),
                      icon: const Icon(LucideIcons.x, size: 18),
                    ),
                  ),
                ],
              ),
            if (room > 0)
              Semantics(
                button: true,
                label: 'Adicionar foto',
                child: InkWell(
                  borderRadius: BorderRadius.circular(BowieRadius.md),
                  onTap: () => _add(context, ref, room),
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(BowieRadius.md),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.camera, color: colors.textMuted),
                        const SizedBox(height: BowieSpacing.s1),
                        Text(
                          'Adicionar',
                          style: BowieType.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, int room) async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.images),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ref
          .read(photoPickerProvider)
          .pick(source, max: room, maxSide: 1600);
      if (picked.isEmpty) return;
      final accepted = picked.where((p) => photoMediaType(p) != null).toList();
      if (accepted.length < picked.length) {
        onError(
          'Uma das fotos está em um formato que o app não aceita. Tente tirar '
          'a foto pela câmera.',
        );
      }
      onChanged([
        ...photos,
        for (final bytes in accepted.take(room)) EventPhoto.fresh(bytes),
      ]);
    } on Exception {
      onError(
        source == PhotoSource.camera
            ? 'Não foi possível abrir a câmera. Confira se o Bowie tem '
                  'permissão nos Ajustes do celular.'
            : 'Não foi possível abrir as fotos. Confira se o Bowie tem '
                  'permissão nos Ajustes do celular.',
      );
    }
  }
}
