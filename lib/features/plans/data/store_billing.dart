import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:bowie/core/error/app_failure.dart';

/// The public RevenueCat keys of each store (RevenueCat → API keys). They are
/// meant to be in the app; the secret key never is.
const revenueCatAppleKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
const revenueCatGoogleKey = String.fromEnvironment('REVENUECAT_ANDROID_KEY');

/// The RevenueCat entitlement both products unlock.
const premiumEntitlement = 'premium';

enum StorePeriod { monthly, annual }

/// One way to subscribe, as the store sells it.
class StoreOffer {
  const StoreOffer({
    required this.period,
    required this.price,
    required this.handle,
  });

  final StorePeriod period;

  /// Formatted by the store, in the person's currency: "R$ 9,90".
  final String price;

  /// What the store needs to sell it.
  final Object handle;
}

/// Premium the store says is paid.
class StorePremium {
  const StorePremium({this.until});

  /// Null when it has no end.
  final DateTime? until;
}

/// Subscriptions in the App Store and Google Play. Every call names the
/// account, so a purchase always lands on the person signed in.
abstract interface class StoreBilling {
  bool get available;

  /// Annual first.
  Future<List<StoreOffer>> offers(String userId);

  /// Null when the person cancels the store's sheet.
  Future<StorePremium?> buy(String userId, StoreOffer offer);

  /// Null when there is nothing to restore.
  Future<StorePremium?> restore(String userId);

  /// The Premium the store has for the account, from its cache when offline.
  Future<StorePremium?> current(String userId);
}

/// Without a RevenueCat key (tests, or before the setup): nothing to sell.
class NoStoreBilling implements StoreBilling {
  const NoStoreBilling();

  @override
  bool get available => false;

  @override
  Future<List<StoreOffer>> offers(String userId) async => const [];

  @override
  Future<StorePremium?> buy(String userId, StoreOffer offer) async => null;

  @override
  Future<StorePremium?> restore(String userId) async => null;

  @override
  Future<StorePremium?> current(String userId) async => null;
}

class RevenueCatBilling implements StoreBilling {
  RevenueCatBilling(this._apiKey);

  /// The key of this phone's store, or null when it has none.
  static String? keyForPlatform() {
    if (kIsWeb) return null;
    final key = Platform.isIOS
        ? revenueCatAppleKey
        : Platform.isAndroid
        ? revenueCatGoogleKey
        : '';
    return key.isEmpty ? null : key;
  }

  final String _apiKey;
  String? _userId;
  Future<void>? _configuring;

  @override
  bool get available => true;

  /// Configures once with the account and switches when it changes.
  Future<void> _as(String userId) async {
    _configuring ??= Purchases.configure(
      PurchasesConfiguration(_apiKey)..appUserID = userId,
    );
    await _configuring;
    _userId ??= userId;
    if (_userId != userId) {
      await Purchases.logIn(userId);
      _userId = userId;
    }
  }

  @override
  Future<List<StoreOffer>> offers(String userId) async {
    try {
      await _as(userId);
      final offering = (await Purchases.getOfferings()).current;
      return [
        if (offering?.annual case final annual?)
          StoreOffer(
            period: StorePeriod.annual,
            price: annual.storeProduct.priceString,
            handle: annual,
          ),
        if (offering?.monthly case final monthly?)
          StoreOffer(
            period: StorePeriod.monthly,
            price: monthly.storeProduct.priceString,
            handle: monthly,
          ),
      ];
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<StorePremium?> buy(String userId, StoreOffer offer) async {
    try {
      await _as(userId);
      final result = await Purchases.purchase(
        PurchaseParams.package(offer.handle as Package),
      );
      return _premium(result.customerInfo) ??
          (throw const AppFailure(
            'A loja confirmou a compra, mas o Premium ainda não apareceu. '
            'Toque em "Restaurar compras" em alguns minutos.',
          ));
    } on PlatformException catch (error) {
      if (PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      throw _failure(error);
    }
  }

  @override
  Future<StorePremium?> restore(String userId) async {
    try {
      await _as(userId);
      return _premium(await Purchases.restorePurchases());
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  @override
  Future<StorePremium?> current(String userId) async {
    try {
      await _as(userId);
      return _premium(await Purchases.getCustomerInfo());
    } on PlatformException {
      return null;
    }
  }

  StorePremium? _premium(CustomerInfo info) {
    final entitlement = info.entitlements.active[premiumEntitlement];
    if (entitlement == null) return null;
    final until = entitlement.expirationDate;
    return StorePremium(until: until == null ? null : DateTime.parse(until));
  }

  AppFailure _failure(PlatformException error) {
    final code = PurchasesErrorHelper.getErrorCode(error);
    if (kDebugMode) debugPrint('Store failed: $code');
    return switch (code) {
      PurchasesErrorCode.networkError ||
      PurchasesErrorCode.offlineConnectionError => const AppFailure(
        'Sem conexão com a internet. Tente de novo.',
        retryable: true,
      ),
      PurchasesErrorCode.purchaseNotAllowedError => const AppFailure(
        'Este aparelho não permite compras. Confira as restrições nos '
        'Ajustes.',
      ),
      PurchasesErrorCode.paymentPendingError => const AppFailure(
        'O pagamento está pendente. O Premium começa assim que a loja '
        'confirmar.',
      ),
      PurchasesErrorCode.productAlreadyPurchasedError => const AppFailure(
        'Esta conta da loja já tem o Premium. Toque em "Restaurar compras".',
      ),
      PurchasesErrorCode.configurationError ||
      PurchasesErrorCode.productNotAvailableForPurchaseError =>
        const AppFailure(
          'A assinatura ainda não está disponível. Tente mais tarde.',
        ),
      _ => const AppFailure(
        'A loja não conseguiu concluir. Tente de novo.',
        retryable: true,
      ),
    };
  }
}
