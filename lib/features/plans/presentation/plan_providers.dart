import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bowie/app/providers.dart';
import 'package:bowie/features/auth/domain/app_user.dart';
import 'package:bowie/features/pets/data/pet_local_store.dart';
import 'package:bowie/features/pets/domain/pet_tutor.dart';
import 'package:bowie/features/plans/data/plan_repository.dart';
import 'package:bowie/features/plans/domain/account_plan.dart';
import 'package:bowie/features/plans/presentation/premium_sheet.dart';

final planCacheProvider = Provider<PlanCache>((ref) => PrefsPlanCache());

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PlanRepository(
    client == null ? null : SupabasePlanApi(client),
    ref.watch(planCacheProvider),
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
          'No plano grátis, a conta tem $freePetLimit pet. Com o Premium, '
          'você cadastra até $premiumPetLimit.',
    );
  }
  return false;
}

/// Checks the new pet against the plan before opening the form.
Future<void> openNewPet(BuildContext context, void Function() open) async {
  if (await ensureCanAddPet(context)) open();
}

/// True when the free plan still has room for [amount] more; otherwise
/// explains it and returns false. Premium (and the trial) has no limit.
Future<bool> ensureQuota(BuildContext context, Quota quota, int amount) async {
  if (amount < 1) return true;
  final container = ProviderScope.containerOf(context, listen: false);
  final user = container.read(currentUserProvider);
  if (user == null) return true;
  final plan = await container.read(planRepositoryProvider).current(user.id);
  final left = switch (quota) {
    Quota.aiPhotos => plan.aiPhotosLeft,
    Quota.diaryFiles => plan.diaryFilesLeft,
  };
  if (left == null || amount <= left) return true;
  if (!context.mounted) return false;
  await showPremiumSheet(context, reason: quotaReason(quota, left, amount));
  return false;
}

/// Why the free plan stops here, in the person's words.
String quotaReason(Quota quota, int left, int amount) {
  // "as 3 fotos" / "os 10 envios": the article follows the word.
  final (total, what, the, ofThe, remove) = switch (quota) {
    Quota.aiPhotos => (
      freeAiPhotos,
      'fotos lidas pela IA',
      'as',
      'das',
      amount - left == 1 ? 'Remova 1 foto' : 'Remova ${amount - left} fotos',
    ),
    Quota.diaryFiles => (
      freeDiaryFiles,
      'envios de fotos e PDFs no diário',
      'os',
      'dos',
      amount - left == 1
          ? 'Tire 1 foto ou arquivo'
          : 'Tire ${amount - left} fotos ou arquivos',
    ),
  };
  if (left == 0) {
    return 'Você já usou $the $total $what do plano grátis. Com o Premium, '
        'não há limite.';
  }
  return 'Restam $left $ofThe $total $what do plano grátis. $remove ou '
      'assine o Premium, que não tem limite.';
}

/// Counts what was used, after it worked.
Future<void> consumeQuota(BuildContext context, Quota quota, int amount) {
  final container = ProviderScope.containerOf(context, listen: false);
  return container.read(planRepositoryProvider).consume(quota, amount);
}
