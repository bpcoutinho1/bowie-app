import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/app/theme.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/auth/presentation/account_page.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/data/pet_repository.dart';
import 'package:bowie/features/pets/domain/pet.dart';
import 'package:bowie/features/plans/data/plan_repository.dart';
import 'package:bowie/features/plans/domain/account_plan.dart';
import 'package:bowie/features/plans/presentation/plan_providers.dart';
import 'package:bowie/features/plans/presentation/premium_sheet.dart';

/// The account_plans row of the person, in memory.
class FakePlanApi implements PlanApi {
  FakePlanApi(this.row, {this.offline = false});

  Map<String, dynamic>? row;
  bool offline;
  final consumed = <(Quota, int)>[];

  @override
  Future<Map<String, dynamic>?> fetch() async {
    if (offline) throw Exception('offline');
    return row;
  }

  @override
  Future<void> consume(Quota quota, int amount) async =>
      consumed.add((quota, amount));
}

Map<String, dynamic> row({
  String plan = 'free',
  String? premiumUntil,
  String trialEndsAt = '2026-09-01T00:00:00Z',
  int ai = 0,
  int diary = 0,
}) => {
  'plan': plan,
  'premium_until': premiumUntil,
  'trial_ends_at': trialEndsAt,
  'ai_photos_used': ai,
  'diary_files_used': diary,
};

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);

  test('the tier follows the plan, its end and the trial', () {
    expect(AccountPlan.fromRow(row(), now).tier, PlanTier.free);
    expect(
      AccountPlan.fromRow(row(trialEndsAt: '2026-11-01T00:00:00Z'), now).tier,
      PlanTier.trial,
    );
    expect(
      AccountPlan.fromRow(row(plan: 'premium'), now).tier,
      PlanTier.premium,
    );
    expect(
      AccountPlan.fromRow(
        row(plan: 'premium', premiumUntil: '2026-10-01T00:00:00Z'),
        now,
      ).tier,
      PlanTier.free,
      reason: 'a Premium that ended is free again',
    );
  });

  test('the free plan counts; Premium and the trial do not', () {
    final free = AccountPlan.fromRow(row(ai: 2, diary: 12), now);
    expect(free.petLimit, 1);
    expect(free.aiPhotosLeft, 1);
    expect(free.diaryFilesLeft, 0);
    final trial = AccountPlan.fromRow(
      row(trialEndsAt: '2026-11-01T00:00:00Z', ai: 9),
      now,
    );
    expect(trial.petLimit, 5);
    expect(trial.aiPhotosLeft, isNull);
  });

  test('without internet, the last plan read; without it, no block', () async {
    final api = FakePlanApi(row(plan: 'premium'));
    final cache = MemoryPlanCache();
    final plans = PlanRepository(api, cache, now: () => now);
    expect((await plans.current('u1')).tier, PlanTier.premium);
    api.offline = true;
    expect((await plans.current('u1')).tier, PlanTier.premium);
    final unknown = await PlanRepository(
      FakePlanApi(null, offline: true),
      MemoryPlanCache(),
    ).current('u2');
    expect(unknown.known, isFalse);
    expect(unknown.isPremium, isTrue);
  });

  test('an account the server has no row for is on the free plan', () async {
    final plan = await PlanRepository(
      FakePlanApi(null),
      MemoryPlanCache(),
    ).current('u3');
    expect(plan.known, isTrue);
    expect(plan.tier, PlanTier.free);
  });

  test('the messages say what is left and what to do', () {
    expect(
      quotaReason(Quota.aiPhotos, 0, 2),
      'Você já usou as 3 fotos lidas pela IA do plano grátis. Com o Premium, '
      'não há limite.',
    );
    expect(
      quotaReason(Quota.diaryFiles, 1, 3),
      'Restam 1 dos 10 envios de fotos e PDFs no diário do plano grátis. '
      'Tire 2 fotos ou arquivos ou assine o Premium, que não tem limite.',
    );
  });

  group('limits on screen', () {
    const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
    late PetLocalStore store;
    late FakePlanApi api;

    Future<void> pump(WidgetTester tester, Map<String, dynamic> plan) async {
      store = (await tester.runAsync(
        () => PetLocalStore.open(databasePath: inMemoryDatabasePath),
      ))!;
      addTearDown(() => tester.runAsync(store.close));
      await tester.runAsync(
        () => PetRepository(store, now: () => now).createPet(
          profile: PetProfile(
            name: 'Bowie',
            species: PetSpecies.dog,
            sex: PetSex.male,
            birthDate: DateTime(2021, 5, 4),
          ),
          owner: bruno,
        ),
      );
      api = FakePlanApi(plan);
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petLocalStoreProvider.overrideWithValue(store),
            currentUserProvider.overrideWithValue(bruno),
            planRepositoryProvider.overrideWithValue(
              PlanRepository(api, MemoryPlanCache(), now: () => now),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextButton(
                      onPressed: () async {
                        final ok = await ensureCanAddPet(context);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pode cadastrar')),
                          );
                        }
                      },
                      child: const Text('Novo pet'),
                    ),
                    TextButton(
                      onPressed: () =>
                          ensureQuota(context, Quota.diaryFiles, 3),
                      child: const Text('Enviar 3'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> tapAndSettle(WidgetTester tester, String text) async {
      await tester.tap(find.text(text));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    testWidgets('on the free plan, the second pet shows the Premium', (
      tester,
    ) async {
      await pump(tester, row());
      await tapAndSettle(tester, 'Novo pet');
      expect(find.text('Bowie Premium'), findsOneWidget);
      expect(find.textContaining('a conta tem 1 pet'), findsOneWidget);
      expect(find.text('Pode cadastrar'), findsNothing);
    });

    testWidgets('with Premium on in the dashboard, the second pet goes in', (
      tester,
    ) async {
      await pump(tester, row(plan: 'premium'));
      await tapAndSettle(tester, 'Novo pet');
      expect(find.text('Bowie Premium'), findsNothing);
      expect(find.text('Pode cadastrar'), findsOneWidget);
    });

    testWidgets('the diary says how many sends are left', (tester) async {
      await pump(tester, row(diary: 8));
      await tapAndSettle(tester, 'Enviar 3');
      expect(find.text('Bowie Premium'), findsOneWidget);
      expect(find.textContaining('Restam 2 dos 10 envios'), findsOneWidget);
    });

    Future<void> pumpAccount(
      WidgetTester tester,
      PlanApi planApi, {
      int pets = 0,
    }) async {
      store = (await tester.runAsync(
        () => PetLocalStore.open(databasePath: inMemoryDatabasePath),
      ))!;
      addTearDown(() => tester.runAsync(store.close));
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            petLocalStoreProvider.overrideWithValue(store),
            currentUserProvider.overrideWithValue(bruno),
            planRepositoryProvider.overrideWithValue(
              PlanRepository(planApi, MemoryPlanCache(), now: () => now),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const AccountPage(),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('"Minha conta" shows the free plan and the way to Premium', (
      tester,
    ) async {
      await pumpAccount(tester, FakePlanApi(row(ai: 1)));
      expect(find.text('Conta'), findsOneWidget);
      expect(find.text('Grátis'), findsOneWidget);
      expect(find.text('1 de 3'), findsOneWidget);
      expect(find.text('Mudar para Premium'), findsOneWidget);
    });

    testWidgets('"Minha conta" makes the trial plain', (tester) async {
      await pumpAccount(
        tester,
        FakePlanApi(row(trialEndsAt: '2026-11-18T12:00:00Z')),
      );
      expect(find.text('Teste grátis do Premium'), findsOneWidget);
      expect(find.text('Acaba em'), findsOneWidget);
      expect(find.text('18/11/2026'), findsOneWidget);
    });

    testWidgets('"Minha conta" says when the plan could not be read', (
      tester,
    ) async {
      await pumpAccount(tester, FakePlanApi(null, offline: true));
      expect(find.text('Não foi possível ver o plano'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('with a subscription page set, the sheet links to it', (
      tester,
    ) async {
      await pumpAccount(tester, FakePlanApi(row()));
      final context = tester.element(find.text('Conta'));
      showPremiumSheet(context, url: 'https://bowieapp.pet/premium');
      await tester.pumpAndSettle();
      expect(find.text('Mudar para Premium'), findsNWidgets(2));
      expect(find.text('Assinatura em breve'), findsNothing);
    });
  });
}
