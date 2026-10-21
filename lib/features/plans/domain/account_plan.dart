import 'dart:math';

/// Limits of the plans (docs/produto/planos.md).
const freePetLimit = 1;
const premiumPetLimit = 10;

/// Photos read by the AI, for the life of the account.
const freeAiPhotos = 3;

/// Photos and PDFs sent to the diary, for the life of the account.
const freeDiaryFiles = 5;

enum PlanTier { free, trial, premium }

/// The plan of the person signed in, as the server has it.
class AccountPlan {
  const AccountPlan({
    required this.tier,
    this.trialEndsAt,
    this.premiumUntil,
    this.aiPhotosUsed = 0,
    this.diaryFilesUsed = 0,
    this.known = true,
    this.fromStore = false,
  });

  /// Used when the plan could not be read (no internet, never synced): the
  /// app does not block anyone on a guess.
  const AccountPlan.unknown() : this(tier: PlanTier.premium, known: false);

  factory AccountPlan.fromRow(Map<String, dynamic> row, DateTime now) {
    DateTime? time(String key) {
      final value = row[key];
      return value is String ? DateTime.parse(value).toUtc() : null;
    }

    int count(String key) => (row[key] as num?)?.toInt() ?? 0;

    final premiumUntil = time('premium_until');
    final trialEndsAt = time('trial_ends_at');
    final storeUntil = time('store_premium_until');
    // Set by hand in the dashboard.
    final granted =
        row['plan'] == 'premium' &&
        (premiumUntil == null || premiumUntil.isAfter(now));
    // Bought in the App Store or Google Play (revenuecat-webhook).
    final bought = storeUntil != null && storeUntil.isAfter(now);
    final inTrial = trialEndsAt != null && trialEndsAt.isAfter(now);
    return AccountPlan(
      tier: granted || bought
          ? PlanTier.premium
          : inTrial
          ? PlanTier.trial
          : PlanTier.free,
      trialEndsAt: trialEndsAt,
      premiumUntil: granted ? premiumUntil : (bought ? storeUntil : null),
      fromStore: bought && !granted,
      aiPhotosUsed: count('ai_photos_used'),
      diaryFilesUsed: count('diary_files_used'),
    );
  }

  final PlanTier tier;
  final DateTime? trialEndsAt;
  final DateTime? premiumUntil;
  final int aiPhotosUsed;
  final int diaryFilesUsed;

  /// False when the server could not be read.
  final bool known;

  /// Premium paid through the App Store or Google Play: it renews there, and
  /// "Minha conta" offers to manage it.
  final bool fromStore;

  /// The trial counts as Premium.
  bool get isPremium => tier != PlanTier.free;

  int get petLimit => isPremium ? premiumPetLimit : freePetLimit;

  /// Null means no limit.
  int? get aiPhotosLeft =>
      isPremium ? null : max(0, freeAiPhotos - aiPhotosUsed);

  int? get diaryFilesLeft =>
      isPremium ? null : max(0, freeDiaryFiles - diaryFilesUsed);

  /// The same plan, now Premium bought in the store until [until].
  AccountPlan withStorePremium(DateTime? until) => AccountPlan(
    tier: PlanTier.premium,
    trialEndsAt: trialEndsAt,
    premiumUntil: until,
    aiPhotosUsed: aiPhotosUsed,
    diaryFilesUsed: diaryFilesUsed,
    known: known,
    fromStore: true,
  );

  Map<String, dynamic> toRow() => {
    'plan': tier == PlanTier.premium && !fromStore ? 'premium' : 'free',
    'premium_until': fromStore ? null : premiumUntil?.toIso8601String(),
    'store_premium_until': fromStore ? premiumUntil?.toIso8601String() : null,
    'trial_ends_at': trialEndsAt?.toIso8601String(),
    'ai_photos_used': aiPhotosUsed,
    'diary_files_used': diaryFilesUsed,
  };
}
