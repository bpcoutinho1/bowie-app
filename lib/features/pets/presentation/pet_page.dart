import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/error/app_failure.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/breeds.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/domain/pet_age.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';

final petDetailsProvider = FutureProvider.autoDispose
    .family<PetDetails?, String>((ref, id) async {
      final repository = ref.watch(petRepositoryProvider);
      final changes = repository.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      return repository.getDetails(id);
    });

class PetPage extends ConsumerStatefulWidget {
  const PetPage({super.key, this.petId});

  final String? petId;

  @override
  ConsumerState<PetPage> createState() => _PetPageState();
}

class _PetPageState extends ConsumerState<PetPage> {
  final _name = TextEditingController();
  final _breed = TextEditingController();
  final _breedFocus = FocusNode();
  final _ageYears = TextEditingController();
  final _weight = TextEditingController();
  final _email = TextEditingController();
  PetSpecies? _species;
  DateTime? _birthDate;
  var _unknownBirthDate = false;
  var _seeded = false;
  var _saving = false;
  var _inviting = false;
  var _deleting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    _breedFocus.dispose();
    _ageYears.dispose();
    _weight.dispose();
    _email.dispose();
    super.dispose();
  }

  void _seed(Pet pet) {
    _seeded = true;
    _name.text = pet.name;
    _species = pet.species;
    _breed.text = pet.breed ?? '';
    _unknownBirthDate = pet.birthDateEstimated;
    final birth = pet.birthDate;
    if (birth != null) {
      if (pet.birthDateEstimated) {
        _ageYears.text = ageInYears(birth, DateTime.now()).toString();
      } else {
        _birthDate = birth;
      }
    }
    final weight = pet.weightKg;
    if (weight != null) _weight.text = formatWeight(weight);
  }

  @override
  Widget build(BuildContext context) {
    final petId = widget.petId;
    final asyncDetails = petId == null
        ? null
        : ref.watch(petDetailsProvider(petId));
    if (asyncDetails case AsyncData(value: final value?) when !_seeded) {
      _seed(value.pet);
    }

    return Scaffold(
      appBar: AppBar(title: Text(petId == null ? 'Novo pet' : 'Pet')),
      body: switch (asyncDetails) {
        null => _form(context, details: null),
        AsyncLoading() => const Center(child: CircularProgressIndicator()),
        AsyncError() => const Center(
          child: Text('Não foi possível ler este pet no celular.'),
        ),
        AsyncData(value: final PetDetails details) => _form(
          context,
          details: details,
        ),
        AsyncData() => const Center(
          child: Text('Este pet não está neste celular.'),
        ),
      },
    );
  }

  Widget _form(BuildContext context, {required PetDetails? details}) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final owner = details != null && user != null && _isOwner(details, user);
    const gap = SizedBox(height: BowieSpacing.s4);

    return ListView(
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
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Nome'),
        ),
        gap,
        Text('Tipo', style: BowieType.bodyStrong.copyWith(color: colors.text)),
        const SizedBox(height: BowieSpacing.s2),
        SegmentedButton<PetSpecies>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final species in PetSpecies.values)
              ButtonSegment(value: species, label: Text(species.label)),
          ],
          selected: {?_species},
          onSelectionChanged: (selection) {
            setState(
              () => _species = selection.isEmpty ? null : selection.first,
            );
          },
        ),
        gap,
        _BreedField(
          controller: _breed,
          focusNode: _breedFocus,
          species: _species,
        ),
        gap,
        Text(
          'Nascimento',
          style: BowieType.bodyStrong.copyWith(color: colors.text),
        ),
        const SizedBox(height: BowieSpacing.s2),
        if (_unknownBirthDate)
          TextField(
            controller: _ageYears,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Idade aproximada (anos)',
            ),
          )
        else
          OutlinedButton(
            onPressed: _pickBirthDate,
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
            child: Text(
              _birthDate == null
                  ? 'Escolher data de nascimento'
                  : '${_formatDate(_birthDate!)} · ${describeAge(_birthDate!, DateTime.now())}',
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Não sei a data exata'),
          value: _unknownBirthDate,
          onChanged: (value) => setState(() => _unknownBirthDate = value),
        ),
        TextField(
          controller: _weight,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: const InputDecoration(
            labelText: 'Peso atual (kg)',
            hintText: 'Ex.: 23,5',
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
          onPressed: _saving ? null : () => _save(details),
          child: Text(
            _saving
                ? 'Salvando'
                : details == null
                ? 'Cadastrar pet'
                : 'Salvar',
          ),
        ),
        if (details != null) ...[
          const SizedBox(height: BowieSpacing.s8),
          Text('Tutores', style: theme.textTheme.titleMedium),
          const SizedBox(height: BowieSpacing.s2),
          for (final tutor in details.tutors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tutor.email),
              subtitle: Text(_label(tutor)),
            ),
          if (owner) ...[
            const SizedBox(height: BowieSpacing.s2),
            TextField(
              controller: _email,
              enabled: !_inviting,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Convidar por email',
              ),
            ),
            const SizedBox(height: BowieSpacing.s3),
            OutlinedButton(
              onPressed: _inviting ? null : () => _invite(details),
              child: Text(_inviting ? 'Convidando' : 'Convidar'),
            ),
            const SizedBox(height: BowieSpacing.s8),
            TextButton.icon(
              onPressed: _deleting ? null : () => _delete(details),
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              icon: const Icon(LucideIcons.trash2),
              label: const Text('Excluir este pet'),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(today.year - 1, today.month, today.day),
      firstDate: DateTime(today.year - 40),
      lastDate: today,
      helpText: 'Data de nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  PetProfile _profile() {
    DateTime? birthDate = _birthDate;
    if (_unknownBirthDate) {
      final years = int.tryParse(_ageYears.text.trim());
      if (years == null) {
        throw const AppFailure('Informe a idade aproximada em anos.');
      }
      if (years > 40) throw const AppFailure('Confira a idade aproximada.');
      birthDate = estimatedBirthDate(years, DateTime.now());
    }
    return PetProfile(
      name: _name.text,
      species: _species,
      breed: _breed.text,
      birthDate: birthDate,
      birthDateEstimated: _unknownBirthDate,
      weightKg: parseWeight(_weight.text),
    );
  }

  Future<void> _save(PetDetails? details) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(petRepositoryProvider);
    try {
      final profile = _profile();
      if (details == null) {
        final pet = await repository.createPet(profile: profile, owner: user);
        if (!mounted) return;
        context.go('/pets/${pet.id}');
      } else {
        await repository.updatePet(
          petId: details.pet.id,
          profile: profile,
          byUser: user,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dados salvos')));
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _invite(PetDetails details) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() {
      _inviting = true;
      _error = null;
    });
    try {
      await ref
          .read(petRepositoryProvider)
          .inviteTutor(petId: details.pet.id, email: _email.text, byUser: user);
      _email.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Convite registrado')));
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _delete(PetDetails details) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final name = details.pet.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir $name?'),
        content: Text(
          'Todos os dados de $name serão apagados para todos os tutores. '
          'Isso não pode ser desfeito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.colors.danger),
            child: Text('Excluir $name'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(petRepositoryProvider)
          .deletePet(petId: details.pet.id, byUser: user);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/pets');
      messenger.showSnackBar(SnackBar(content: Text('$name foi excluído')));
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  bool _isOwner(PetDetails details, AppUser user) {
    final email = normalizeEmail(user.email);
    return details.tutors.any(
      (tutor) =>
          tutor.role == PetRole.owner &&
          tutor.status == TutorStatus.accepted &&
          tutor.email == email &&
          tutor.deletedAt == null,
    );
  }

  String _label(PetTutor tutor) {
    if (tutor.role == PetRole.owner) return 'Tutor principal';
    if (tutor.status == TutorStatus.pending) return 'Convite pendente';
    return 'Tutor';
  }
}

/// Breed with suggestions for the chosen species. Free text is allowed.
class _BreedField extends StatelessWidget {
  const _BreedField({
    required this.controller,
    required this.focusNode,
    required this.species,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final PetSpecies? species;

  @override
  Widget build(BuildContext context) {
    final species = this.species;
    if (species == null) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Raça',
          helperText: 'Escolha cão ou gato para ver as raças.',
        ),
      );
    }
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) => searchBreeds(species, value.text),
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Raça',
            helperText: 'Escolha da lista ou digite outra.',
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final colors = context.colors;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: colors.surface,
            elevation: 4,
            borderRadius: BorderRadius.circular(BowieRadius.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
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
    );
  }
}

/// "23,5" or "23.5" in kg. Empty means no weight.
double? parseWeight(String text) {
  final value = text.trim().replaceAll(',', '.');
  if (value.isEmpty) return null;
  final weight = double.tryParse(value);
  if (weight == null) {
    throw const AppFailure('Digite o peso em kg, por exemplo 23,5.');
  }
  return weight;
}

/// 23.0 → "23"; 23.5 → "23,5".
String formatWeight(double kg) {
  final rounded = (kg * 10).round() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return text.replaceAll('.', ',');
}

String _formatDate(DateTime day) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(day.day)}/${two(day.month)}/${day.year}';
}
