import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:bowie/app/design_tokens.dart';
import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/core/ui/bowie_card.dart';
import 'package:bowie/core/ui/bowie_logo.dart';
import 'package:bowie/features/diary/presentation/event_form_page.dart';
import 'package:bowie/features/health/domain/health_note.dart';
import 'package:bowie/features/health/domain/vaccine_status.dart';
import 'package:bowie/features/health/presentation/card_reading_page.dart';
import 'package:bowie/features/health/presentation/dose_form_page.dart';
import 'package:bowie/features/health/presentation/health_note_form_page.dart';
import 'package:bowie/features/health/presentation/health_providers.dart';
import 'package:bowie/features/health/presentation/medication_form_page.dart';
import 'package:bowie/features/health/presentation/status_badge.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/pets/presentation/pet_page.dart';
import 'package:bowie/features/reminders/presentation/reminder_providers.dart';

/// Steps of the first-use path (docs/produto/primeiro-uso.md).
const onboardingSteps = 3;

/// "Passo 2 de 3" and what the step is for.
class OnboardingStep extends StatelessWidget {
  const OnboardingStep({super.key, required this.step, required this.text});

  final int step;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Passo $step de $onboardingSteps',
          style: BowieType.overline.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: BowieSpacing.s1),
        Text(text, style: BowieType.body.copyWith(color: colors.textMuted)),
      ],
    );
  }
}

/// Opens a screen over the path and comes back to it when that screen
/// closes (it closes itself after saving).
Future<void> _open(BuildContext context, Widget page) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => page));
}

/// Início with no pet yet: what the app does and the way in.
class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget step(int number, IconData icon, String title, String text) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: colors.surfaceMuted,
          foregroundColor: colors.text,
          child: Icon(icon, size: 20),
        ),
        title: Text('$number. $title', style: BowieType.bodyStrong),
        subtitle: Text(text),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        BowieSpacing.s6,
        BowieSpacing.s8,
        BowieSpacing.s6,
        BowieSpacing.s8,
      ),
      children: [
        const Center(child: BowieLogo(height: 120)),
        const SizedBox(height: BowieSpacing.s6),
        Text(
          'Boas-vindas ao Bowie',
          textAlign: TextAlign.center,
          style: BowieType.title1.copyWith(color: colors.text),
        ),
        const SizedBox(height: BowieSpacing.s2),
        Text(
          'Em poucos minutos, a ficha do seu pet fica pronta para você e para '
          'quem cuida dele com você.',
          textAlign: TextAlign.center,
          style: BowieType.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: BowieSpacing.s6),
        step(1, LucideIcons.pawPrint, 'O seu pet', 'Nome, foto e nascimento.'),
        step(
          2,
          LucideIcons.syringe,
          'As vacinas',
          'Fotografe a carteirinha e o app preenche para você.',
        ),
        step(
          3,
          LucideIcons.bellRing,
          'Os avisos',
          'Um lembrete 7 dias antes de cada vacina vencer e do aniversário.',
        ),
        const SizedBox(height: BowieSpacing.s6),
        FilledButton(
          onPressed: () => context.push('/boas-vindas/pet'),
          child: const Text('Cadastrar meu pet'),
        ),
      ],
    );
  }
}

/// Step 2: the vaccines, from a photo of the card or by hand.
class OnboardingVaccinesPage extends ConsumerWidget {
  const OnboardingVaccinesPage({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final pet = ref.watch(petDetailsProvider(petId)).asData?.value?.pet;
    final groups =
        ref.watch(vaccineGroupsProvider(petId)).asData?.value ?? const [];
    final today = ref.watch(healthRepositoryProvider).today;
    final name = pet?.name ?? 'seu pet';
    final done = groups.isNotEmpty;
    void next() => context.go('/boas-vindas/pronto?pet=$petId');

    return Scaffold(
      appBar: AppBar(
        title: Text(pet == null ? 'Vacinas' : 'Vacinas ${ofPet(pet)}'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          OnboardingStep(
            step: 2,
            text:
                'Com as vacinas no app, você recebe um aviso antes de cada '
                'uma vencer, e a ficha de $name fica pronta para hotéis e '
                'veterinários.',
          ),
          const SizedBox(height: BowieSpacing.s6),
          if (done) ...[
            BowieCard(
              child: Column(
                children: [
                  for (final group in groups)
                    ListTile(
                      leading: Icon(
                        LucideIcons.circleCheck,
                        color: colors.success,
                      ),
                      title: Text(group.name, style: BowieType.bodyStrong),
                      subtitle: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusBadge(
                          status: group.statusOn(today),
                          text: describeDue(group.latest.nextDueOn, today),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: BowieSpacing.s4),
            FilledButton(onPressed: next, child: const Text('Continuar')),
            const SizedBox(height: BowieSpacing.s2),
            OutlinedButton.icon(
              onPressed: () => _open(context, CardReadingPage(petId: petId)),
              icon: const Icon(LucideIcons.camera),
              label: const Text('Ler mais páginas da carteirinha'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: () => _open(context, CardReadingPage(petId: petId)),
              icon: const Icon(LucideIcons.camera),
              label: const Text('Fotografar a carteirinha'),
            ),
            const SizedBox(height: BowieSpacing.s2),
            OutlinedButton.icon(
              onPressed: () => _open(context, DoseFormPage(petId: petId)),
              icon: const Icon(LucideIcons.pencilLine),
              label: const Text('Registrar à mão'),
            ),
            const SizedBox(height: BowieSpacing.s2),
            TextButton(onPressed: next, child: const Text('Fazer depois')),
          ],
        ],
      ),
    );
  }
}

/// Step 3: the reminders and, for whoever wants more, the extras.
class OnboardingDonePage extends ConsumerWidget {
  const OnboardingDonePage({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final pet = ref.watch(petDetailsProvider(petId)).asData?.value?.pet;
    final name = pet?.name ?? 'seu pet';
    Widget extra(IconData icon, String title, String text, Widget page) {
      return ListTile(
        leading: Icon(icon, color: colors.text),
        title: Text(title, style: BowieType.bodyStrong),
        subtitle: Text(text),
        trailing: Icon(LucideIcons.chevronRight, color: colors.textMuted),
        onTap: () => _open(context, page),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tudo pronto'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BowieSpacing.s4,
          BowieSpacing.s2,
          BowieSpacing.s4,
          BowieSpacing.s8,
        ),
        children: [
          OnboardingStep(
            step: 3,
            text: 'A ficha de $name começou. Falta só decidir sobre os avisos.',
          ),
          const SizedBox(height: BowieSpacing.s4),
          NotificationsPrompt(pet: pet),
          const SizedBox(height: BowieSpacing.s6),
          Text(
            'Quer ir além?',
            style: BowieType.title3.copyWith(color: colors.text),
          ),
          const SizedBox(height: BowieSpacing.s1),
          Text(
            'Opcional. Tudo isso entra na ficha que você compartilhar com o '
            'veterinário.',
            style: BowieType.callout.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: BowieSpacing.s2),
          BowieCard(
            child: Column(
              children: [
                extra(
                  LucideIcons.pill,
                  'Remédios em uso',
                  'Com horários e aviso de dose',
                  MedicationFormPage(petId: petId),
                ),
                extra(
                  LucideIcons.shieldAlert,
                  'Alergias e cuidados especiais',
                  'O que quem cuida precisa saber',
                  HealthNoteFormPage(
                    petId: petId,
                    kind: HealthNoteKind.allergy,
                  ),
                ),
                extra(
                  LucideIcons.fileText,
                  'Exames e consultas',
                  'Com fotos e PDFs dos resultados',
                  EventFormPage(petId: petId),
                ),
              ],
            ),
          ),
          const SizedBox(height: BowieSpacing.s6),
          FilledButton(
            onPressed: () => context.go('/inicio'),
            child: const Text('Ir para o início'),
          ),
        ],
      ),
    );
  }
}

/// Asks to turn on the reminders, explaining what they are first. Shows
/// nothing once they are on.
class NotificationsPrompt extends ConsumerStatefulWidget {
  const NotificationsPrompt({super.key, this.pet, this.onDismiss});

  final Pet? pet;

  /// Shows "Agora não" when given.
  final VoidCallback? onDismiss;

  @override
  ConsumerState<NotificationsPrompt> createState() =>
      _NotificationsPromptState();
}

class _NotificationsPromptState extends ConsumerState<NotificationsPrompt> {
  var _busy = false;
  var _refused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = ref.watch(notificationsEnabledProvider).asData?.value;
    if (enabled == null) return const SizedBox.shrink();
    if (enabled) {
      return BowieCard(
        child: ListTile(
          leading: Icon(LucideIcons.bellRing, color: colors.success),
          title: const Text('Avisos ativados'),
          subtitle: const Text(
            'Você recebe um lembrete 7 dias antes de cada vacina vencer e do '
            'aniversário.',
          ),
        ),
      );
    }
    final pet = widget.pet;
    return BowieCard(
      child: Padding(
        padding: const EdgeInsets.all(BowieSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.bellRing, color: colors.text),
                const SizedBox(width: BowieSpacing.s3),
                Expanded(
                  child: Text(
                    'Receber avisos',
                    style: BowieType.bodyStrong.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BowieSpacing.s2),
            Text(
              pet == null
                  ? 'Um lembrete 7 dias antes de cada vacina vencer e do '
                        'aniversário dos seus pets.'
                  : 'Um lembrete 7 dias antes de cada vacina ${ofPet(pet)} '
                        'vencer e do aniversário.',
              style: BowieType.callout.copyWith(color: colors.textMuted),
            ),
            if (_refused) ...[
              const SizedBox(height: BowieSpacing.s2),
              Text(
                'O celular não deixou. Para ativar, abra Ajustes, toque em '
                'Bowie e ligue as notificações.',
                style: BowieType.callout.copyWith(color: colors.warning),
              ),
            ],
            const SizedBox(height: BowieSpacing.s3),
            FilledButton(
              onPressed: _busy ? null : _enable,
              child: const Text('Ativar avisos'),
            ),
            if (widget.onDismiss != null)
              TextButton(
                onPressed: widget.onDismiss,
                child: const Text('Agora não'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _enable() async {
    setState(() => _busy = true);
    final granted = await ref
        .read(notificationGatewayProvider)
        .requestPermission();
    final user = ref.read(currentUserProvider);
    if (granted && user != null) {
      await ref.read(reminderServiceProvider).reschedule(user);
    }
    if (!mounted) return;
    ref.invalidate(notificationsEnabledProvider);
    setState(() {
      _busy = false;
      _refused = !granted;
    });
  }
}

/// The first-use routes, outside the tabs.
List<RouteBase> onboardingRoutes() => [
  GoRoute(
    path: '/boas-vindas/pet',
    builder: (context, state) => const PetPage(onboarding: true),
  ),
  GoRoute(
    path: '/boas-vindas/vacinas',
    builder: (context, state) =>
        OnboardingVaccinesPage(petId: state.uri.queryParameters['pet'] ?? ''),
  ),
  GoRoute(
    path: '/boas-vindas/pronto',
    builder: (context, state) =>
        OnboardingDonePage(petId: state.uri.queryParameters['pet'] ?? ''),
  ),
];
