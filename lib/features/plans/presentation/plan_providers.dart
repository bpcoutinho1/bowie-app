import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';
import 'package:bowie/features/plans/data/plan_repository.dart';
import 'package:bowie/features/plans/data/store_billing.dart';
import 'package:bowie/features/plans/domain/account_plan.dart';
import 'package:bowie/features/plans/presentation/premium_sheet.dart';

final planCacheProvider = Provider<PlanCache>((ref) => PrefsPlanCache());

/// The App Store or Google Play, through RevenueCat, when its key is set.
final storeBillingProvider = Provider<StoreBilling>((ref) {
  final key = RevenueCatBilling.keyForPlatform();
  return key == null ? const NoStoreBilling() : RevenueCatBilling(key);
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PlanRepository(
    client == null ? null : SupabasePlanApi(client),
    ref.watch(planCacheProvider),
    store: ref.watch(storeBillingProvider),
  );
});

/// The plan and what the free plan counts, for "Minha conta".
final planUsageProvider =
    FutureProvider.autoDispose<({AccountPlan plan, int pets})>((ref) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return (plan: const AccountPlan.unknown(), pets: 0);
      final plan = await ref.watch(planRepositoryProvider).current(user.id);
      final pets = await ownedPetCount(ref.watch(petLocalStoreProvider), user);
      return (plan: plan, pets: pets);
    });

/// Whether the AI reads the vaccine card for this account (Premium and the
/// trial). True while the plan is unknown: the server has the last word.
final canReadCardsProvider = FutureProvider.autoDispose<bool>((ref) async {
  final usage = await ref.watch(planUsageProvider.future);
  return usage.plan.canReadCards;
});

/// Pets the person is the main tutor of: only these count in their plan.
Future<int> ownedPetCount(PetLocalStore store, AppUser user) async {
  final email = normalizeEmail(user.email);
  var count = 0;
  for (final pet in await store.listPetsFor(email)) {
    final tutors = await store.listTutors(pet.id);
    final owner = tutors.any(
      (tutor) =>
          tutor.role == PetRole.owner &&
          tutor.status == TutorStatus.accepted &&
          tutor.email == email &&
          tutor.deletedAt == null,
    );
    if (owner) count++;
  }
  return count;
}

/// True when the person may add one more pet; otherwise explains the limit
/// (and the Premium, on the free plan) and returns false.
Future<bool> ensureCanAddPet(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final user = container.read(currentUserProvider);
  if (user == null) return false;
  final plan = await container.read(planRepositoryProvider).current(user.id);
  final owned = await ownedPetCount(
    container.read(petLocalStoreProvider),
    user,
  );
  if (owned < plan.petLimit) return true;
  if (!context.mounted) return false;
  if (plan.isPremium) {
    await showLimitNotice(
      context,
      'O Premium tem até $premiumPetLimit pets por conta.',
    );
  } else {
    await showPremiumSheet(
      context,
      reason:
          'No plano grátis, a conta tem até $freePetLimit pets. Com o '
          'Premium, você cadastra até $premiumPetLimit.',
    );
  }
  return false;
}

/// Checks the new pet against the plan before opening the form.
Future<void> openNewPet(BuildContext context, void Function() open) async {
  if (await ensureCanAddPet(context)) open();
}

/// True when the free plan still has room for [amount] more; otherwise
/// explains it and returns false. Premium (and the trial) has no limit. The
/// reading of the vaccine card by the AI is only in Premium.
Future<bool> ensureQuota(BuildContext context, Quota quota, int amount) async {
  if (amount < 1) return true;
  final container = ProviderScope.containerOf(context, listen: false);
  final user = container.read(currentUserProvider);
  if (user == null) return true;
  final plan = await container.read(planRepositoryProvider).current(user.id);
  if (!context.mounted) return false;
  switch (quota) {
    case Quota.aiPhotos:
      if (plan.canReadCards) return true;
      await showPremiumSheet(context, reason: aiReadingPremiumReason);
      return false;
    case Quota.diaryFiles:
      final left = plan.diaryFilesLeft;
      if (left == null || amount <= left) return true;
      await showPremiumSheet(context, reason: diaryFilesReason(left, amount));
      return false;
  }
}

const aiReadingPremiumReason =
    'A leitura da carteirinha por IA é do Premium. No plano grátis, você '
    'registra as vacinas à mão.';

/// Why the free plan stops sending files to the diary, in the person's words.
String diaryFilesReason(int left, int amount) {
  if (left == 0) {
    return 'Você já usou os $freeDiaryFiles envios de fotos e PDFs no diário '
        'do plano grátis. Com o Premium, não há limite.';
  }
  final remove = amount - left == 1
      ? 'Tire 1 foto ou arquivo'
      : 'Tire ${amount - left} fotos ou arquivos';
  return 'Restam $left dos $freeDiaryFiles envios de fotos e PDFs no diário '
      'do plano grátis. $remove ou assine o Premium, que não tem limite.';
}

/// Counts what was used, after it worked.
Future<void> consumeQuota(BuildContext context, Quota quota, int amount) {
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(planRepositoryProvider).consume(quota, amount);
}
