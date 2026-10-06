import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/dates.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/features/health/data/card_reader.dart';
import 'package:bowie/features/health/data/health_repository.dart';
import 'package:bowie/core/photo_picker.dart';
import 'package:bowie/features/health/domain/card_reading.dart';
import 'package:bowie/features/health/domain/vaccine_dose.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';

/// Reads photos of the vaccine card in the cloud and lets the person review
/// every dose before saving (docs/produto/carteirinha-de-vacinacao.md).
class CardReadingPage extends ConsumerStatefulWidget {
  const CardReadingPage({super.key, required this.petId});

  final String petId;

  @override
  ConsumerState<CardReadingPage> createState() => _CardReadingPageState();
}

enum _Stage { photos, reading, review }

class _CardReadingPageState extends ConsumerState<CardReadingPage> {
  var _stage = _Stage.photos;
  final _photos = <Uint8List>[];
  String? _error;

  /// Bumped on cancel so a late answer is ignored.
  var _attempt = 0;

  CardReading? _reading;
  List<ReviewItem> _items = const [];
  var _importWeight = false;
  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(petDetailsProvider(widget.petId)).asData?.value?.pet;
    final name = pet?.name ?? 'seu pet';
    return PopScope(
      canPop: _stage == _Stage.photos && _photos.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_stage == _Stage.reading) {
          _cancel();
          return;
        }
        if (await _confirmDiscard() && context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Ler carteirinha')),
        body: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : BowieMotion.base,
          switchInCurve: BowieMotion.easing,
          child: switch (_stage) {
            _Stage.photos => _photosStage(name),
            _Stage.reading => _ReadingProgress(
              key: const ValueKey('reading'),
              petName: name,
              photos: _photos.length,
              onCancel: _cancel,
            ),
            _Stage.review => _reviewStage(pet, name),
          },
        ),
      ),
    );
  }

  // Photos ------------------------------------------------------------------

  Widget _photosStage(String name) {
    final colors = context.colors;
    final room = maxCardPhotos - _photos.length;
    return ListView(
      key: const ValueKey('photos'),
      padding: const EdgeInsets.fromLTRB(
        BowieSpacing.s4,
        BowieSpacing.s2,
        BowieSpacing.s4,
        BowieSpacing.s8,
      ),
      children: [
        Text(
          'Fotografe a carteirinha de $name',
          style: BowieType.title2.copyWith(color: colors.text),
        ),
        const SizedBox(height: BowieSpacing.s2),
        Text(
          'A leitura encontra as vacinas, os vermífugos e o peso. '
          'Você confere tudo antes de salvar.',
          style: BowieType.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: BowieSpacing.s4),
        const _Tips(),
        const SizedBox(height: BowieSpacing.s6),
        if (_photos.isNotEmpty) ...[
          _PhotoGrid(
            photos: _photos,
            onRemove: (index) => setState(() => _photos.removeAt(index)),
          ),
          const SizedBox(height: BowieSpacing.s4),
        ],
        if (room > 0) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(PhotoSource.camera),
                  icon: const Icon(LucideIcons.camera),
                  label: const Text('Tirar foto'),
                ),
              ),
              const SizedBox(width: BowieSpacing.s3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(PhotoSource.gallery),
                  icon: const Icon(LucideIcons.images),
                  label: const Text('Da galeria'),
                ),
              ),
            ],
          ),
          const SizedBox(height: BowieSpacing.s2),
          Text(
            _photos.isEmpty
                ? 'Até $maxCardPhotos fotos por leitura.'
                : room == 1
                ? 'Cabe mais 1 foto nesta leitura.'
                : 'Cabem mais $room fotos nesta leitura.',
            style: BowieType.caption.copyWith(color: colors.textMuted),
          ),
        ] else
          Text(
            'Esta leitura já tem $maxCardPhotos fotos. '
            'Depois de salvar, você pode ler outras páginas.',
            style: BowieType.caption.copyWith(color: colors.textMuted),
          ),
        if (_error != null) ...[
          const SizedBox(height: BowieSpacing.s4),
          _Notice(
            icon: LucideIcons.circleAlert,
            text: _error!,
            foreground: colors.danger,
            background: colors.dangerSoft,
          ),
        ],
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: BowieSpacing.s6),
          FilledButton.icon(
            onPressed: _read,
            icon: const Icon(LucideIcons.scanText),
            label: Text(
              _photos.length == 1
                  ? 'Ler a foto'
                  : 'Ler ${_photos.length} fotos',
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pick(PhotoSource source) async {
    setState(() => _error = null);
    try {
      final picked = await ref
          .read(photoPickerProvider)
          .pick(source, max: maxCardPhotos - _photos.length);
      if (!mounted || picked.isEmpty) return;
      final accepted = picked.where((p) => photoMediaType(p) != null).toList();
      setState(() {
        _photos.addAll(accepted.take(maxCardPhotos - _photos.length));
        if (accepted.length < picked.length) {
          _error =
              'Uma das fotos está em um formato que a leitura não aceita. '
              'Tente tirar a foto pela câmera.';
        }
      });
    } on Exception {
      if (!mounted) return;
      setState(
        () => _error = source == PhotoSource.camera
            ? 'Não foi possível abrir a câmera. Confira se o Bowie tem '
                  'permissão nos Ajustes do celular.'
            : 'Não foi possível abrir as fotos. Confira se o Bowie tem '
                  'permissão nos Ajustes do celular.',
      );
    }
  }

  // Reading -----------------------------------------------------------------

  Future<void> _read() async {
    final reader = ref.read(cardReaderProvider);
    if (reader == null) {
      setState(() => _error = 'Este app ainda não está conectado ao servidor.');
      return;
    }
    if (!await _ensureConsent() || !mounted) return;

    final attempt = ++_attempt;
    setState(() {
      _stage = _Stage.reading;
      _error = null;
    });
    try {
      final reading = await reader.read(List.of(_photos));
      final health = ref.read(healthRepositoryProvider);
      final existing = await health.listDoses(widget.petId);
      final pet =
          (await ref.read(petRepositoryProvider).getDetails(widget.petId))?.pet;
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _reading = reading;
        _items = buildReview(reading, existing, health.today);
        _importWeight = _suggestWeight(reading.latestWeight, pet, health.today);
        _stage = _Stage.review;
      });
    } on AppFailure catch (error) {
      if (!mounted || attempt != _attempt) return;
      setState(() {
        _error = error.message;
        _stage = _Stage.photos;
      });
    }
  }

  void _cancel() {
    setState(() {
      _attempt++;
      _stage = _Stage.photos;
    });
  }

  /// The photo leaves the phone only after the person agrees, once.
  Future<bool> _ensureConsent() async {
    final consent = ref.read(readingConsentProvider);
    if (await consent.given()) return true;
    if (!mounted) return false;
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(LucideIcons.shieldCheck),
        title: const Text('Enviar as fotos para leitura?'),
        content: const Text(
          'Para ler a carteirinha, as fotos vão com segurança para o servidor '
          'do Bowie e são lidas por um serviço de inteligência artificial '
          '(Anthropic). As fotos não ficam guardadas no servidor e não são '
          'usadas para treinar a IA.\n\n'
          'A leitura pode errar. Você confere cada registro antes de salvar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Concordo'),
          ),
        ],
      ),
    );
    if (agreed != true) return false;
    await consent.give();
    return true;
  }

  // Review ------------------------------------------------------------------

  Widget _reviewStage(Pet? pet, String name) {
    final colors = context.colors;
    final reading = _reading!;
    final today = ref.read(healthRepositoryProvider).today;
    final weight = reading.latestWeight;

    if (_items.isEmpty && weight == null) {
      return _NothingFound(
        key: const ValueKey('nothing'),
        isCard: reading.isVaccineCard,
        issues: reading.issues,
        onRetry: _restart,
      );
    }

    final selected = _items.where((item) => item.selected).length;
    final total = selected + (_importWeight ? 1 : 0);
    final saved = _items.where((item) => item.alreadySaved).length;
    final toCheck = _items
        .where(
          (item) =>
              !item.alreadySaved &&
              (item.dose.uncertain.isNotEmpty ||
                  item.dose.problemOn(today) != null),
        )
        .length;

    return Column(
      key: const ValueKey('review'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BowieSpacing.s4,
              BowieSpacing.s2,
              BowieSpacing.s4,
              BowieSpacing.s6,
            ),
            children: [
              Text(
                'Confira o que foi lido',
                style: BowieType.title2.copyWith(color: colors.text),
              ),
              const SizedBox(height: BowieSpacing.s2),
              Text(
                [
                  'Toque em um registro para corrigir. Nada é salvo antes de '
                      'você confirmar.',
                  if (toCheck > 0)
                    toCheck == 1
                        ? '1 registro pede sua atenção.'
                        : '$toCheck registros pedem sua atenção.',
                  if (saved > 0)
                    saved == 1
                        ? '1 dose já estava registrada.'
                        : '$saved doses já estavam registradas.',
                ].join(' '),
                style: BowieType.body.copyWith(color: colors.textMuted),
              ),
              if (reading.issues != null) ...[
                const SizedBox(height: BowieSpacing.s4),
                _Notice(
                  icon: LucideIcons.info,
                  text: reading.issues!,
                  foreground: colors.info,
                  background: colors.infoSoft,
                ),
              ],
              const SizedBox(height: BowieSpacing.s4),
              _PhotoStrip(photos: _photos),
              const SizedBox(height: BowieSpacing.s4),
              for (final item in _items) ...[
                _ReviewCard(
                  item: item,
                  today: today,
                  onToggle: () => _toggle(item, today),
                  onEdit: () => _edit(item),
                ),
                const SizedBox(height: BowieSpacing.s3),
              ],
              if (weight != null) ...[
                const SizedBox(height: BowieSpacing.s2),
                _WeightCard(
                  weight: weight,
                  petName: name,
                  currentKg: pet?.weightKg,
                  selected: _importWeight,
                  onChanged: (value) => setState(() => _importWeight = value),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: BowieSpacing.s4),
                _Notice(
                  icon: LucideIcons.circleAlert,
                  text: _error!,
                  foreground: colors.danger,
                  background: colors.dangerSoft,
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              BowieSpacing.s4,
              BowieSpacing.s2,
              BowieSpacing.s4,
              BowieSpacing.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: total == 0 || _saving ? null : _save,
                  child: Text(
                    _saving
                        ? 'Salvando'
                        : total == 0
                        ? 'Escolha o que salvar'
                        : total == 1
                        ? 'Salvar 1 registro'
                        : 'Salvar $total registros',
                  ),
                ),
                TextButton(
                  onPressed: _saving ? null : _restartAsking,
                  child: const Text('Ler outras fotos'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _toggle(ReviewItem item, DateTime today) {
    if (!item.selected && item.dose.problemOn(today) != null) {
      _edit(item);
      return;
    }
    setState(() => item.selected = !item.selected);
  }

  Future<void> _edit(ReviewItem item) async {
    final today = ref.read(healthRepositoryProvider).today;
    final edited = await showModalBottomSheet<ReadDose>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _DoseEditor(dose: item.dose, today: today),
    );
    if (edited == null || !mounted) return;
    setState(() {
      item.dose = edited;
      item.selected = true;
    });
  }

  Future<void> _save() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final chosen = _items.where((item) => item.selected).toList();
    final weight = _importWeight ? _reading?.latestWeight : null;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(healthRepositoryProvider)
          .saveDoses(
            inputs: [
              for (final item in chosen)
                DoseInput(
                  petId: widget.petId,
                  kind: item.dose.kind,
                  name: item.dose.name,
                  appliedOn: item.dose.appliedOn,
                  nextDueOn: item.dose.nextDueOn,
                  product: item.dose.product,
                  lot: item.dose.lot,
                  veterinarian: item.dose.veterinarian,
                ),
            ],
            byUser: user,
          );
      if (weight != null) {
        await ref
            .read(petRepositoryProvider)
            .updateWeight(
              petId: widget.petId,
              weightKg: weight.weightKg,
              byUser: user,
            );
      }
      if (!mounted) return;
      final parts = [
        if (chosen.length == 1) '1 registro salvo',
        if (chosen.length > 1) '${chosen.length} registros salvos',
        if (weight != null) 'peso atualizado',
      ];
      final text = parts.join(' e ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text[0].toUpperCase() + text.substring(1))),
      );
      // Navigator.pop skips the PopScope that guards unsaved readings.
      Navigator.of(context).pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restartAsking() async {
    if (_items.any((item) => item.selected) || _importWeight) {
      if (!await _confirmDiscard()) return;
    }
    _restart();
  }

  void _restart() {
    setState(() {
      _photos.clear();
      _items = const [];
      _reading = null;
      _error = null;
      _stage = _Stage.photos;
    });
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar esta leitura?'),
        content: const Text('O que foi lido e ainda não foi salvo se perde.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar aqui'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard == true;
  }
}

/// A weight read from the card replaces the profile's only when the profile
/// has none or the reading is from the last 90 days.
bool _suggestWeight(ReadWeight? weight, Pet? pet, DateTime today) {
  if (weight == null) return false;
  final current = pet?.weightKg;
  if (current == null) return true;
  if ((current - weight.weightKg).abs() < 0.05) return false;
  final measured = weight.measuredOn;
  return measured != null && daysBetween(measured, today) <= 90;
}

// Pieces --------------------------------------------------------------------

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget tip(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: BowieSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.textMuted),
          const SizedBox(width: BowieSpacing.s3),
          Expanded(
            child: Text(
              text,
              style: BowieType.callout.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
    return BowieCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s4,
          BowieSpacing.s4,
          BowieSpacing.s2,
        ),
        child: Column(
          children: [
            tip(
              LucideIcons.fileText,
              'Uma página por foto, com a página inteira.',
            ),
            tip(LucideIcons.sun, 'Boa luz e sem reflexo nas etiquetas.'),
            tip(
              LucideIcons.penLine,
              'As datas escritas à mão precisam aparecer com nitidez.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.onRemove});

  final List<Uint8List> photos;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: BowieSpacing.s3,
      crossAxisSpacing: BowieSpacing.s3,
      childAspectRatio: 3 / 4,
      children: [
        for (var i = 0; i < photos.length; i++)
          Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(BowieRadius.md),
                child: Semantics(
                  label: 'Foto ${i + 1}',
                  image: true,
                  child: Image.memory(photos[i], fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: BowieSpacing.s1,
                right: BowieSpacing.s1,
                child: IconButton.filledTonal(
                  tooltip: 'Remover foto ${i + 1}',
                  onPressed: () => onRemove(i),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.text,
                  ),
                  icon: const Icon(LucideIcons.x),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// Small thumbnails on the review screen; a tap opens the photo to compare.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});

  final List<Uint8List> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: BowieSpacing.s2),
        itemBuilder: (context, i) => Semantics(
          button: true,
          label: 'Ver a foto ${i + 1}',
          child: InkWell(
            borderRadius: BorderRadius.circular(BowieRadius.md),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => _PhotoViewer(photo: photos[i], number: i + 1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BowieRadius.md),
              child: Image.memory(
                photos[i],
                width: 66,
                height: 88,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo, required this.number});

  final Uint8List photo;
  final int number;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Foto $number')),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(child: Image.memory(photo)),
      ),
    );
  }
}

class _ReadingProgress extends StatelessWidget {
  const _ReadingProgress({
    super.key,
    required this.petName,
    required this.photos,
    required this.onCancel,
  });

  final String petName;
  final int photos;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BowieSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 48,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: BowieSpacing.s6),
            Semantics(
              liveRegion: true,
              child: Text(
                'Lendo a carteirinha de $petName',
                textAlign: TextAlign.center,
                style: BowieType.title3.copyWith(color: colors.text),
              ),
            ),
            const SizedBox(height: BowieSpacing.s2),
            Text(
              photos == 1
                  ? 'Isso costuma levar até um minuto.'
                  : 'Com $photos fotos, isso pode levar até dois minutos.',
              textAlign: TextAlign.center,
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s6),
            TextButton(onPressed: onCancel, child: const Text('Cancelar')),
          ],
        ),
      ),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound({
    super.key,
    required this.isCard,
    required this.issues,
    required this.onRetry,
  });

  final bool isCard;
  final String? issues;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(BowieSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.scanSearch, size: 48, color: colors.textMuted),
            const SizedBox(height: BowieSpacing.s4),
            Text(
              isCard
                  ? 'Nenhuma dose encontrada'
                  : 'Esta foto não parece ser de uma carteirinha',
              textAlign: TextAlign.center,
              style: BowieType.title3.copyWith(color: colors.text),
            ),
            const SizedBox(height: BowieSpacing.s2),
            Text(
              issues ??
                  'Fotografe uma página com as datas das vacinas, com boa luz.',
              textAlign: TextAlign.center,
              style: BowieType.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: BowieSpacing.s6),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar outras fotos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.item,
    required this.today,
    required this.onToggle,
    required this.onEdit,
  });

  final ReviewItem item;
  final DateTime today;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dose = item.dose;
    final problem = dose.problemOn(today);
    final applied = dose.appliedOn;
    final due = dose.nextDueOn;
    final dueLabel = dose.kind == DoseKind.vaccine ? 'Revacinar em' : 'Próxima';
    final details = [
      ?dose.product,
      if (dose.lot != null) 'Lote ${dose.lot}',
      ?dose.veterinarian,
    ];
    final doubts = [
      for (final field in ReadField.values)
        if (dose.uncertain.contains(field)) _fieldLabel(field),
    ];

    return BowieCard(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s1,
          BowieSpacing.s3,
          BowieSpacing.s3,
          BowieSpacing.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.selected,
              onChanged: (_) => onToggle(),
              semanticLabel:
                  'Salvar ${dose.name.isEmpty ? 'este registro' : dose.name}',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: BowieSpacing.s2),
                  Text(
                    dose.name.isEmpty ? 'Sem nome' : dose.name,
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                  Text(
                    '${dose.kind.label} · Aplicada em '
                    '${applied == null ? '?' : formatDayBr(applied)}',
                    style: BowieType.callout.copyWith(color: colors.text),
                  ),
                  Text(
                    '$dueLabel ${due == null ? '?' : formatDayBr(due)}',
                    style: BowieType.callout.copyWith(color: colors.textMuted),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      style: BowieType.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  if (item.alreadySaved ||
                      problem != null ||
                      doubts.isNotEmpty) ...[
                    const SizedBox(height: BowieSpacing.s2),
                    Wrap(
                      spacing: BowieSpacing.s2,
                      runSpacing: BowieSpacing.s1,
                      children: [
                        if (item.alreadySaved)
                          _Tag(
                            icon: LucideIcons.circleCheck,
                            text: 'Já registrada',
                            foreground: colors.textMuted,
                            background: colors.surfaceMuted,
                          ),
                        if (problem != null)
                          _Tag(
                            icon: LucideIcons.circleAlert,
                            text: problem,
                            foreground: colors.danger,
                            background: colors.dangerSoft,
                          )
                        else if (doubts.isNotEmpty && !item.alreadySaved)
                          _Tag(
                            icon: LucideIcons.eye,
                            text: 'Confira: ${doubts.join(', ')}',
                            foreground: colors.warning,
                            background: colors.warningSoft,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Corrigir',
              onPressed: onEdit,
              icon: Icon(LucideIcons.pencil, size: 18, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

String _fieldLabel(ReadField field) => switch (field) {
  ReadField.kind => 'tipo',
  ReadField.name => 'nome',
  ReadField.appliedOn => 'aplicação',
  ReadField.nextDueOn => 'próxima dose',
  ReadField.product => 'produto',
  ReadField.lot => 'lote',
  ReadField.veterinarian => 'veterinário',
};

class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.weight,
    required this.petName,
    required this.currentKg,
    required this.selected,
    required this.onChanged,
  });

  final ReadWeight weight;
  final String petName;
  final double? currentKg;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final measured = weight.measuredOn;
    final current = currentKg;
    return BowieCard(
      child: CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BowieRadius.lg),
        ),
        secondary: Icon(LucideIcons.scale, color: colors.textMuted),
        title: Text(
          'Atualizar o peso de $petName para ${formatKg(weight.weightKg)}',
          style: BowieType.bodyStrong.copyWith(color: colors.text),
        ),
        subtitle: Text(
          [
            if (measured != null) 'Pesado em ${formatDayBr(measured)}',
            if (current != null) 'No perfil: ${formatKg(current)}',
          ].join(' · '),
          style: BowieType.caption.copyWith(color: colors.textMuted),
        ),
      ),
    );
  }
}

String formatKg(double kg) {
  final rounded = (kg * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1).replaceAll('.', ',');
  return '$text kg';
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BowieRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: BowieSpacing.s2),
            Expanded(
              child: Text(
                text,
                style: BowieType.callout.copyWith(color: context.colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.text,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String text;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(BowieRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BowieSpacing.s2,
          vertical: BowieSpacing.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: BowieSpacing.s1),
            Flexible(
              child: Text(
                text,
                style: BowieType.caption.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corrects one read dose. Returns the dose with its doubts cleared, since
/// the person has now checked it.
class _DoseEditor extends StatefulWidget {
  const _DoseEditor({required this.dose, required this.today});

  final ReadDose dose;
  final DateTime today;

  @override
  State<_DoseEditor> createState() => _DoseEditorState();
}

class _DoseEditorState extends State<_DoseEditor> {
  late final _name = TextEditingController(text: widget.dose.name);
  late final _product = TextEditingController(text: widget.dose.product);
  late final _lot = TextEditingController(text: widget.dose.lot);
  late final _veterinarian = TextEditingController(
    text: widget.dose.veterinarian,
  );
  late DoseKind _kind = widget.dose.kind;
  late DateTime? _appliedOn = widget.dose.appliedOn;
  late DateTime? _nextDueOn = widget.dose.nextDueOn;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _product.dispose();
    _lot.dispose();
    _veterinarian.dispose();
    super.dispose();
  }

  bool _doubt(ReadField field) => widget.dose.uncertain.contains(field);

  String? _helper(ReadField field) =>
      _doubt(field) ? 'Confira com a foto' : null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const gap = SizedBox(height: BowieSpacing.s4);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          0,
          BowieSpacing.s4,
          BowieSpacing.s6,
        ),
        children: [
          Text(
            'Corrigir registro',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
          gap,
          SegmentedButton<DoseKind>(
            showSelectedIcon: false,
            segments: [
              for (final kind in DoseKind.values)
                ButtonSegment(value: kind, label: Text(kind.label)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          gap,
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Nome',
              helperText: _helper(ReadField.name),
            ),
          ),
          gap,
          _DateButton(
            label: 'Aplicada em',
            value: _appliedOn,
            doubt: _doubt(ReadField.appliedOn),
            onTap: () async {
              final picked = await _pick(
                _appliedOn ?? widget.today,
                last: widget.today,
              );
              if (picked != null) setState(() => _appliedOn = picked);
            },
          ),
          gap,
          _DateButton(
            label: _kind == DoseKind.vaccine
                ? 'Revacinar em'
                : 'Próxima dose em',
            value: _nextDueOn,
            doubt: _doubt(ReadField.nextDueOn),
            onTap: () async {
              final base = _appliedOn ?? widget.today;
              final picked = await _pick(
                _nextDueOn ?? addMonths(base, 12),
                last: DateTime(widget.today.year + 5, 12, 31),
              );
              if (picked != null) setState(() => _nextDueOn = picked);
            },
          ),
          gap,
          TextField(
            controller: _product,
            decoration: InputDecoration(
              labelText: 'Produto e fabricante',
              helperText: _helper(ReadField.product),
            ),
          ),
          gap,
          TextField(
            controller: _lot,
            decoration: InputDecoration(
              labelText: 'Lote',
              helperText: _helper(ReadField.lot),
            ),
          ),
          gap,
          TextField(
            controller: _veterinarian,
            decoration: InputDecoration(
              labelText: 'Veterinário',
              helperText: _helper(ReadField.veterinarian),
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
          FilledButton(onPressed: _done, child: const Text('Usar estes dados')),
        ],
      ),
    );
  }

  Future<DateTime?> _pick(DateTime initial, {required DateTime last}) {
    final first = DateTime(2000);
    var date = initial;
    if (date.isBefore(first)) date = first;
    if (date.isAfter(last)) date = last;
    return showDatePicker(
      context: context,
      initialDate: date,
      firstDate: first,
      lastDate: last,
    );
  }

  void _done() {
    String? text(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    final dose = ReadDose(
      kind: _kind,
      name: _name.text.trim(),
      appliedOn: _appliedOn,
      nextDueOn: _nextDueOn,
      product: text(_product),
      lot: text(_lot),
      veterinarian: text(_veterinarian),
    );
    final problem = dose.problemOn(widget.today);
    if (problem != null) {
      setState(() => _error = '$problem.');
      return;
    }
    Navigator.of(context).pop(dose);
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.doubt,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final bool doubt;
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
          helperText: doubt ? 'Confira com a foto' : null,
          suffixIcon: const Icon(LucideIcons.calendar),
        ),
        child: Text(value == null ? 'Escolher data' : formatDayBr(value)),
      ),
    );
  }
}
