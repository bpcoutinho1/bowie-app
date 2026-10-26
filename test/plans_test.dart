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
import 'package:bowie/features/health/presentation/card_reading_page.dart';
import 'package:bowie/features/plans/data/plan_repository.dart';
import 'package:bowie/features/plans/data/store_billing.dart';
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

/// The App Store, in memory: annual and monthly, as RevenueCat would offer.
class FakeStore implements StoreBilling {
  FakeStore({this.cancel = false});

  final bool cancel;
  final bought = <StorePeriod>[];
  StorePremium? _premium;

  @override
  bool get available => true;

  @override
  Future<List<StoreOffer>> offers(String userId) async => const [
    StoreOffer(period: StorePeriod.annual, price: 'R\$ 99,90', handle: 'y'),
    StoreOffer(period: StorePeriod.monthly, price: 'R\$ 9,90', handle: 'm'),
  ];

  @override
  Future<StorePremium?> buy(String userId, StoreOffer offer) async {
    if (cancel) return null;
    bought.add(offer.period);
    return _premium = StorePremium(until: DateTime.utc(2026, 11, 19, 12));
  }

  @override
  Future<StorePremium?> restore(String userId) async => _premium;

  @override
  Future<StorePremium?> current(String userId) async => _premium;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

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
    expect(free.petLimit, 2);
    expect(free.canReadCards, isFalse, reason: 'the AI reading is Premium');
    expect(free.diaryFilesLeft, 0);
    final trial = AccountPlan.fromRow(
      row(trialEndsAt: '2026-11-01T00:00:00Z', ai: 9),
      now,
    );
    expect(trial.petLimit, 10);
    expect(trial.canReadCards, isTrue);
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

  test(
    'Premium bought in the store counts, apart from the one set by hand',
    () {
      final bought = AccountPlan.fromRow({
        ...row(),
        'store_premium_until': '2026-11-19T12:00:00Z',
      }, now);
      expect(bought.tier, PlanTier.premium);
      expect(bought.fromStore, isTrue);
      expect(bought.premiumUntil, DateTime.utc(2026, 11, 19, 12));

      final lapsed = AccountPlan.fromRow({
        ...row(),
        'store_premium_until': '2026-10-01T12:00:00Z',
      }, now);
      expect(lapsed.tier, PlanTier.free);

      final byHand = AccountPlan.fromRow({
        ...row(plan: 'premium'),
        'store_premium_until': '2026-10-01T12:00:00Z',
      }, now);
      expect(byHand.tier, PlanTier.premium);
      expect(byHand.fromStore, isFalse);
    },
  );

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
      diaryFilesReason(0, 2),
      'Você já usou os 5 envios de fotos e PDFs no diário do plano grátis. '
      'Com o Premium, não há limite.',
    );
    expect(
      diaryFilesReason(1, 3),
      'Restam 1 dos 5 envios de fotos e PDFs no diário do plano grátis. '
      'Tire 2 fotos ou arquivos ou assine o Premium, que não tem limite.',
    );
  });

  group('limits on screen', () {
    const bruno = AppUser(id: 'bruno-1', email: 'bruno@example.com');
    late PetLocalStore store;
    late FakePlanApi api;

    Future<void> pump(
      WidgetTester tester,
      Map<String, dynamic> plan, {
      int pets = 1,
    }) async {
      store = (await tester.runAsync(
        () => PetLocalStore.open(databasePath: inMemoryDatabasePath),
      ))!;
      addTearDown(() => tester.runAsync(store.close));
      for (final name in ['Bowie', 'Mia'].take(pets)) {
        await tester.runAsync(
          () => PetRepository(store, now: () => now).createPet(
            profile: PetProfile(
              name: name,
              species: PetSpecies.dog,
              sex: PetSex.male,
              birthDate: DateTime(2021, 5, 4),
            ),
            owner: bruno,
          ),
        );
      }
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
                    TextButton(
                      onPressed: () => ensureQuota(context, Quota.aiPhotos, 1),
                      child: const Text('Ler 1 foto'),
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

    testWidgets('on the free plan, the second pet goes in', (tester) async {
      await pump(tester, row());
      await tapAndSettle(tester, 'Novo pet');
      expect(find.text('Bowie Premium'), findsNothing);
      expect(find.text('Pode cadastrar'), findsOneWidget);
    });

    testWidgets('on the free plan, the third pet shows the Premium', (
      tester,
    ) async {
      await pump(tester, row(), pets: 2);
      await tapAndSettle(tester, 'Novo pet');
      expect(find.text('Bowie Premium'), findsOneWidget);
      expect(find.textContaining('até 2 pets'), findsOneWidget);
      expect(find.text('Pode cadastrar'), findsNothing);
    });

    testWidgets('on the free plan, the AI reading shows the Premium', (
      tester,
    ) async {
      await pump(tester, row());
      await tapAndSettle(tester, 'Ler 1 foto');
      expect(find.text('Bowie Premium'), findsOneWidget);
      expect(find.textContaining('por IA é do Premium'), findsOneWidget);
    });

    testWidgets('with Premium on in the dashboard, the second pet goes in', (
      tester,
    ) async {
      await pump(tester, row(plan: 'premium'));
      await tapAndSettle(tester, 'Novo pet');
      expect(find.text('Bowie Premium'), findsNothing);
      expect(find.text('Pode cadastrar'), findsOneWidget);
    });

    testWidgets('on the free plan, the card page offers Premium or by hand', (
      tester,
    ) async {
      await pump(tester, row());
      final context = tester.element(find.text('Novo pet'));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const CardReadingPage(petId: 'any'),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Leitura da carteirinha por IA'), findsOneWidget);
      expect(find.text('Conhecer o Premium'), findsOneWidget);
      expect(find.text('Registrar à mão'), findsOneWidget);
      expect(find.text('Tirar foto'), findsNothing);
    });

    testWidgets('the diary says how many sends are left', (tester) async {
      await pump(tester, row(diary: 3));
      await tapAndSettle(tester, 'Enviar 3');
      expect(find.text('Bowie Premium'), findsOneWidget);
      expect(find.textContaining('Restam 2 dos 5 envios'), findsOneWidget);
    });

    Future<void> pumpAccount(
      WidgetTester tester,
      PlanApi planApi, {
      int pets = 0,
      StoreBilling billing = const NoStoreBilling(),
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
            storeBillingProvider.overrideWithValue(billing),
            planRepositoryProvider.overrideWithValue(
              PlanRepository(
                planApi,
                MemoryPlanCache(),
                store: billing,
                now: () => now,
              ),
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
      expect(find.text('Só no Premium'), findsOneWidget);
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

    testWidgets(
      'without the store, the sheet says the subscription is coming',
      (tester) async {
        await pumpAccount(tester, FakePlanApi(row()));
        showPremiumSheet(tester.element(find.text('Conta')));
        await tester.pumpAndSettle();
        expect(find.text('Assinatura em breve'), findsOneWidget);
        expect(find.text('Restaurar compras'), findsNothing);
      },
    );

    testWidgets('the sheet sells through the store and turns Premium on', (
      tester,
    ) async {
      final billing = FakeStore();
      await pumpAccount(tester, FakePlanApi(row()), billing: billing);
      expect(find.text('Grátis'), findsOneWidget);
      await tester.tap(find.text('Mudar para Premium'));
      await settle(tester);
      expect(find.text('Assinar por R\$ 99,90 por ano'), findsOneWidget);
      expect(find.text('Assinar por R\$ 9,90 por mês'), findsOneWidget);
      expect(find.textContaining('renova automaticamente'), findsOneWidget);
      expect(find.text('Restaurar compras'), findsOneWidget);
      expect(find.text('Termos de uso'), findsOneWidget);
      expect(find.text('Política de privacidade'), findsOneWidget);

      await tester.tap(find.text('Assinar por R\$ 9,90 por mês'));
      await settle(tester);
      expect(billing.bought, [StorePeriod.monthly]);
      expect(find.text('Bowie Premium'), findsNothing);
      expect(find.textContaining('Premium ativo'), findsOneWidget);
      // The server has not heard yet; the store already says it is paid.
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Gerenciar assinatura'), findsOneWidget);
    });

    testWidgets('a canceled store sheet changes nothing', (tester) async {
      final billing = FakeStore(cancel: true);
      await pumpAccount(tester, FakePlanApi(row()), billing: billing);
      await tester.tap(find.text('Mudar para Premium'));
      await settle(tester);
      await tester.tap(find.text('Assinar por R\$ 99,90 por ano'));
      await settle(tester);
      expect(find.text('Bowie Premium'), findsOneWidget);
      expect(find.text('Grátis'), findsOneWidget);
    });

    testWidgets('restoring with nothing bought says so', (tester) async {
      await pumpAccount(tester, FakePlanApi(row()), billing: FakeStore());
      await tester.tap(find.text('Mudar para Premium'));
      await settle(tester);
      await tester.tap(find.text('Restaurar compras'));
      await settle(tester);
      expect(
        find.textContaining('Nenhuma assinatura encontrada'),
        findsOneWidget,
      );
    });
  });
}
