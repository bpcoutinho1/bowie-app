import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/features/pets/domain/pet.dart';

/// The photo file on the phone. When another tutor added it, it is fetched
/// from the server once and kept. Null while it is not available.
final petPhotoProvider = FutureProvider.autoDispose.family<File?, String>((
  ref,
  path,
) async {
  final photos = ref.watch(petPhotoStoreProvider);
  final local = await photos.local(path);
  if (local != null) return local;
  final remote = ref.watch(petRemoteApiProvider);
  final bytes = await remote?.downloadPhoto(path);
  if (bytes == null) return null;
  await photos.write(path, bytes);
  return photos.local(path);
});

/// Round photo of the pet, or a paw when there is none.
class PetAvatar extends ConsumerWidget {
  const PetAvatar({super.key, required this.pet, this.size = 40});

  final Pet pet;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final path = pet.photoPath;
    final file = path == null
        ? null
        : ref.watch(petPhotoProvider(path)).asData?.value;
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: file == null
              ? ColoredBox(
                  color: colors.surfaceMuted,
                  child: Icon(
                    LucideIcons.pawPrint,
                    size: size * 0.5,
                    color: colors.textMuted,
                  ),
                )
              : Image.file(
                  file,
                  fit: BoxFit.cover,
                  cacheWidth: (size * 3).round(),
                ),
        ),
      ),
    );
  }
}

/// A card for choosing a pet: the photo shows translucent behind the name
/// and the summary. With a photo, the text keeps to the left 60%, over the
/// solid side of a gradient, so it keeps its contrast whatever the photo.
class PetPhotoCard extends ConsumerWidget {
  const PetPhotoCard({
    super.key,
    required this.pet,
    required this.subtitle,
    this.large = false,
    this.below,
    this.onTap,
  });

  final Pet pet;
  final String subtitle;

  /// Bigger name, as on Início.
  final bool large;
  final Widget? below;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final path = pet.photoPath;
    final file = path == null
        ? null
        : ref.watch(petPhotoProvider(path)).asData?.value;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pet.name,
          style: (large ? BowieType.title2 : BowieType.bodyStrong).copyWith(
            color: colors.text,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: BowieSpacing.s1),
          Text(
            subtitle,
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
        ],
        if (below != null) ...[const SizedBox(height: BowieSpacing.s2), below!],
      ],
    );
    final content = Padding(
      padding: const EdgeInsets.all(BowieSpacing.s4),
      child: Row(
        children: [
          if (file == null) ...[
            PetAvatar(pet: pet, size: large ? 56 : 44),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(child: text),
          ] else ...[
            Expanded(flex: 3, child: text),
            const Spacer(flex: 2),
          ],
          if (onTap != null)
            Icon(LucideIcons.chevronRight, color: colors.textMuted),
        ],
      ),
    );
    if (file == null) return BowieCard(onTap: onTap, child: content);

    return BowieCard(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BowieRadius.lg),
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0.6,
                  child: Image.file(file, fit: BoxFit.cover, cacheWidth: 900),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0, 0.6, 1],
                    colors: [
                      colors.surface,
                      colors.surface.withValues(alpha: 0.9),
                      colors.surface.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: large ? 132 : 96),
              child: Align(alignment: Alignment.centerLeft, child: content),
            ),
          ],
        ),
      ),
    );
  }
}
