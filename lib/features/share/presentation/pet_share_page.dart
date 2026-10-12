import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/features/pets/data/pet_sync_controller.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';
import 'package:bowie/features/share/domain/pet_share.dart';
import 'package:bowie/features/share/presentation/share_providers.dart';

/// "Compartilhar ficha do Bowie": a link and a QR code for a hotel, a
/// daycare or a vet, and the links that still work.
class PetSharePage extends ConsumerStatefulWidget {
  const PetSharePage({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<PetSharePage> createState() => _PetSharePageState();
}

class _PetSharePageState extends ConsumerState<PetSharePage> {
  final _label = TextEditingController();
  var _preset = SharePreset.care;
  var _creating = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pet = ref.watch(petDetailsProvider(widget.petId)).asData?.value?.pet;
    final user = ref.watch(currentUserProvider);
    final shares = ref.watch(activeSharesProvider(widget.petId));
    final name = pet == null ? 'do pet' : ofPet(pet);
    return Scaffold(
      appBar: AppBar(title: Text('Ficha $name')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          Text(
            'Crie um link para quem vai cuidar ${pet == null ? 'do pet' : ofPet(pet)}. '
            'Quem abrir vê os dados sempre atualizados, sem precisar do app. '
            'O link vale $shareDays dias e você pode cancelar quando quiser.',
            style: BowieType.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s6),
          Text(
            'Para quem é?',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s3),
          RadioGroup<SharePreset>(
            groupValue: _preset,
            onChanged: (value) {
              if (value != null) setState(() => _preset = value);
            },
            child: Column(
              children: [
                for (final preset in SharePreset.values)
                  RadioListTile<SharePreset>(
                    value: preset,
                    contentPadding: EdgeInsets.zero,
                    title: Text(preset.label, style: BowieType.bodyStrong),
                    subtitle: Text(preset.description),
                  ),
              ],
            ),
          ),
          const SizedBox(height: BowieSpacing.s3),
          TextField(
            controller: _label,
            enabled: !_creating,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do lugar (opcional)',
              hintText: 'Ex.: Hotel Pet Feliz',
              helperText: 'Ajuda a lembrar com quem você compartilhou.',
            ),
          ),
          if (user != null && !user.profileComplete) ...[
            const SizedBox(height: BowieSpacing.s3),
            BowieCard(
              onTap: () => context.push('/conta'),
              child: ListTile(
                leading: Icon(LucideIcons.circleUser, color: colors.info),
                title: const Text('Complete o seu cadastro'),
                subtitle: const Text(
                  'A ficha mostra o nome e o celular do tutor principal.',
                ),
                trailing: const Icon(LucideIcons.chevronRight),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: BowieSpacing.s3),
            Text(
              _error!,
              style: BowieType.callout.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: BowieSpacing.s4),
          FilledButton.icon(
            onPressed: _creating || pet == null ? null : () => _create(pet),
            icon: const Icon(LucideIcons.link),
            label: Text(_creating ? 'Criando o link' : 'Criar link'),
          ),
          const SizedBox(height: BowieSpacing.s8),
          Text(
            'Links ativos',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s3),
          switch (shares) {
            AsyncData(value: final list) when list.isEmpty => Text(
              'Nenhum link ativo.',
              style: BowieType.callout.copyWith(color: colors.textMuted),
            ),
            AsyncData(value: final list) => Column(
              children: [
                for (final share in list) ...[
                  _ShareTile(
                    share: share,
                    onShow: () => _show(share, pet),
                    onRevoke: () => _revoke(share),
                  ),
                  const SizedBox(height: BowieSpacing.s3),
                ],
              ],
            ),
            AsyncError(:final error) => Row(
              children: [
                Expanded(
                  child: Text(
                    error is AppFailure
                        ? error.message
                        : 'Não foi possível ver os links.',
                    style: BowieType.callout.copyWith(color: colors.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(activeSharesProvider(widget.petId)),
                  child: const Text('Tentar de novo'),
                ),
              ],
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }

  Future<void> _create(Pet pet) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      // The sheet is read from the server: send what is only on the phone
      // first, the pet itself included when it was just added.
      await ref.read(syncControllerProvider.notifier).sync();
      final share = await ref
          .read(petShareRepositoryProvider)
          .create(
            petId: widget.petId,
            preset: _preset,
            label: _label.text,
            byUser: user,
          );
      ref.invalidate(activeSharesProvider(widget.petId));
      _label.clear();
      if (mounted) await _show(share, pet);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _show(PetShare share, Pet? pet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ShareSheet(share: share, pet: pet),
    );
  }

  Future<void> _revoke(PetShare share) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar este link?'),
        content: Text(
          'Quem tiver o link ${share.label == null ? '' : 'de ${share.label} '}'
          'deixa de ver a ficha na hora. Você pode criar outro depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: const Text('Cancelar link'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(petShareRepositoryProvider)
          .revoke(share: share, byUser: user);
      ref.invalidate(activeSharesProvider(widget.petId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Link cancelado')));
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({
    required this.share,
    required this.onShow,
    required this.onRevoke,
  });

  final PetShare share;
  final VoidCallback onShow;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final viewed = share.lastViewedAt;
    return BowieCard(
      onTap: onShow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s3,
          BowieSpacing.s1,
          BowieSpacing.s3,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.qrCode, color: colors.text),
            const SizedBox(width: BowieSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    share.label ?? share.preset.label,
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    [
                      if (share.label != null) share.preset.label,
                      'Vale até ${formatDayBr(share.expiresAt.toLocal())}',
                    ].join(' · '),
                    style: BowieType.callout.copyWith(color: colors.textMuted),
                  ),
                  Text(
                    viewed == null
                        ? 'Ainda não foi aberto'
                        : 'Aberto em ${formatDayBr(viewed.toLocal())}',
                    style: BowieType.caption.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Cancelar o link ${share.label ?? share.preset.label}',
              onPressed: onRevoke,
              icon: Icon(LucideIcons.x, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The link of a share, as a QR code to scan at the counter, and buttons to
/// send or copy it.
class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.share, required this.pet});

  final PetShare share;
  final Pet? pet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = pet == null ? 'Ficha do pet' : 'Ficha ${ofPet(pet!)}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        BowieSpacing.s4,
        0,
        BowieSpacing.s4,
        BowieSpacing.s6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: BowieType.title2.copyWith(color: colors.text),
          ),
          Text(
            [
              share.label ?? share.preset.label,
              'vale até ${formatDayBr(share.expiresAt.toLocal())}',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s4),
          Center(
            // White behind the code in both themes, so any camera reads it.
            child: Container(
              padding: const EdgeInsets.all(BowieSpacing.s3),
              decoration: BoxDecoration(
                color: BrandColors.white,
                borderRadius: BorderRadius.circular(BowieRadius.lg),
              ),
              child: QrImageView(
                data: share.url,
                size: 220,
                padding: EdgeInsets.zero,
                semanticsLabel: 'QR code da ficha',
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: BrandColors.night,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: BrandColors.night,
                ),
              ),
            ),
          ),
          const SizedBox(height: BowieSpacing.s3),
          Text(
            'Mostre o QR code para a câmera do celular de quem vai cuidar, '
            'ou envie o link.',
            textAlign: TextAlign.center,
            style: BowieType.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s4),
          Builder(
            builder: (context) => FilledButton.icon(
              onPressed: () {
                final box = context.findRenderObject() as RenderBox?;
                SharePlus.instance.share(
                  ShareParams(
                    text:
                        '$title no Bowie (vale até '
                        '${formatDayBr(share.expiresAt.toLocal())}): '
                        '${share.url}',
                    subject: title,
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  ),
                );
              },
              icon: const Icon(LucideIcons.share2),
              label: const Text('Enviar o link'),
            ),
          ),
          const SizedBox(height: BowieSpacing.s2),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: share.url));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Link copiado')));
              }
            },
            icon: const Icon(LucideIcons.copy),
            label: const Text('Copiar o link'),
          ),
        ],
      ),
    );
  }
}
