import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/theme/appearance.dart';
import 'app_providers.dart';

/// The default skin every player owns for free.
const String kFreeThemeId = 'classic-green';

/// Product id for the one-time lifetime unlock: every theme (current and
/// future) plus any premium features added later.
const String kLifetimeProductId = 'lifetime_access';

/// The lifetime price — the headline offer we push over per-theme purchases.
const String kLifetimePrice = '\$5.99';

/// The category of cosmetic a [StoreProduct] unlocks.
enum CosmeticKind { lifetime, theme, cardBack, chipStyle }

/// A non-consumable product for sale. [cosmeticId] links to the appearance id it
/// unlocks (an [AppearanceTheme], [CardBack], or [ChipStyle]); the lifetime
/// unlock uses an empty [cosmeticId] and grants everything.
///
/// [id] is the store product identifier — keep these in sync with the products
/// configured in App Store Connect / Play Console / RevenueCat.
class StoreProduct {
  final String id;
  final CosmeticKind kind;
  final String cosmeticId;
  final String name;

  /// Fallback display price. When RevenueCat is wired, the live localized price
  /// from the store offering should be shown instead.
  final String priceLabel;

  const StoreProduct({
    required this.id,
    required this.kind,
    required this.cosmeticId,
    required this.name,
    required this.priceLabel,
  });

  bool get isLifetime => kind == CosmeticKind.lifetime;
}

const String _cosmeticPrice = '\$1.99';

/// The catalog. The free defaults (Classic Green felt, Classic Blue card back,
/// Classic chips) are intentionally not listed here.
const List<StoreProduct> storeProducts = [
  StoreProduct(
      id: kLifetimeProductId,
      kind: CosmeticKind.lifetime,
      cosmeticId: '',
      name: 'Lifetime Access',
      priceLabel: kLifetimePrice),
  // Table themes.
  StoreProduct(
      id: 'theme_midnight_blue',
      kind: CosmeticKind.theme,
      cosmeticId: 'midnight-blue',
      name: 'Midnight Blue',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'theme_crimson',
      kind: CosmeticKind.theme,
      cosmeticId: 'crimson',
      name: 'Crimson',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'theme_obsidian',
      kind: CosmeticKind.theme,
      cosmeticId: 'obsidian',
      name: 'Obsidian',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'theme_royal_purple',
      kind: CosmeticKind.theme,
      cosmeticId: 'royal-purple',
      name: 'Royal Purple',
      priceLabel: _cosmeticPrice),
  // Card backs (Royal Blue is the free default, intentionally not listed).
  StoreProduct(
      id: 'back_coral',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-coral',
      name: 'Coral Club',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_rose',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-rose',
      name: 'Rose',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_black_gold',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-black-gold',
      name: 'Black & Gold',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_emerald',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-emerald',
      name: 'Emerald',
      priceLabel: _cosmeticPrice),
  // Chip styles.
  StoreProduct(
      id: 'chips_monochrome',
      kind: CosmeticKind.chipStyle,
      cosmeticId: 'chips-monochrome',
      name: 'Ivory & Onyx',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'chips_sunset',
      kind: CosmeticKind.chipStyle,
      cosmeticId: 'chips-sunset',
      name: 'Sunset',
      priceLabel: _cosmeticPrice),
];

/// The headline lifetime product.
StoreProduct get lifetimeProduct => storeProducts.firstWhere((p) => p.isLifetime);

List<StoreProduct> _ofKind(CosmeticKind kind) =>
    storeProducts.where((p) => p.kind == kind).toList();

/// Themes sold individually, in catalog order.
List<StoreProduct> get themeProducts => _ofKind(CosmeticKind.theme);

/// Card backs sold individually, in catalog order.
List<StoreProduct> get cardBackProducts => _ofKind(CosmeticKind.cardBack);

/// Chip styles sold individually, in catalog order.
List<StoreProduct> get chipStyleProducts => _ofKind(CosmeticKind.chipStyle);

StoreProduct? productForCosmeticId(String cosmeticId) {
  for (final p in storeProducts) {
    if (p.cosmeticId == cosmeticId) return p;
  }
  return null;
}

/// Outcome of a purchase attempt, surfaced to the UI for messaging.
enum PurchaseResult { success, cancelled, error }

/// Pluggable billing backend. Swap [LocalPurchaseBackend] for
/// [RevenueCatPurchaseBackend] once the store products + RevenueCat dashboard
/// are configured — nothing else in the app needs to change.
abstract class PurchaseBackend {
  /// Attempts to buy [productId]. Returns the owned product ids granted (for a
  /// pack this may be just the pack id; entitlement logic expands it).
  Future<PurchaseResult> purchase(String productId);

  /// Restores previously bought products, returning their ids.
  Future<Set<String>> restore();
}

/// Dev / offline backend: grants the purchase immediately. Persistence is
/// handled by [EntitlementsController], so restore() is a no-op here.
class LocalPurchaseBackend implements PurchaseBackend {
  @override
  Future<PurchaseResult> purchase(String productId) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return PurchaseResult.success;
  }

  @override
  Future<Set<String>> restore() async => <String>{};
}

/// RevenueCat adapter — fill in once `purchases_flutter` is added and products
/// exist. Steps:
///   1. `flutter pub add purchases_flutter`
///   2. At startup: `await Purchases.configure(PurchasesConfiguration(apiKey))`
///      (use `--dart-define=RC_API_KEY=...`; mobile only — web uses RevenueCat's
///      Stripe billing via their JS, so keep the local backend for web).
///   3. purchase(): look up the package in the current `Offering`, call
///      `Purchases.purchasePackage(pkg)`, then read `customerInfo` to confirm.
///   4. restore(): `Purchases.restorePurchases()` and map active entitlements
///      back to product ids.
class RevenueCatPurchaseBackend implements PurchaseBackend {
  @override
  Future<PurchaseResult> purchase(String productId) async {
    throw UnimplementedError('Wire RevenueCat — see RevenueCatPurchaseBackend doc.');
  }

  @override
  Future<Set<String>> restore() async {
    throw UnimplementedError('Wire RevenueCat — see RevenueCatPurchaseBackend doc.');
  }
}

class EntitlementsState {
  /// Owned store product ids (individual themes and/or the pack).
  final Set<String> owned;

  /// True while a purchase / restore is in flight.
  final bool busy;

  const EntitlementsState({this.owned = const {}, this.busy = false});

  bool get isPremium => owned.contains(kLifetimeProductId);

  /// A cosmetic is unlocked if it's one of the free defaults, Pro is owned, or
  /// the player bought it individually. Works for themes, card backs, and chips.
  bool isCosmeticUnlocked(String cosmeticId) {
    if (cosmeticId == kFreeThemeId ||
        cosmeticId == kFreeCardBackId ||
        cosmeticId == kFreeChipStyleId) {
      return true;
    }
    if (isPremium) return true;
    final product = productForCosmeticId(cosmeticId);
    return product != null && owned.contains(product.id);
  }

  bool ownsProduct(String productId) => owned.contains(productId);

  EntitlementsState copyWith({Set<String>? owned, bool? busy}) =>
      EntitlementsState(owned: owned ?? this.owned, busy: busy ?? this.busy);
}

class EntitlementsController extends Notifier<EntitlementsState> {
  // Swap to RevenueCatPurchaseBackend() on mobile once RevenueCat is configured.
  final PurchaseBackend _backend = LocalPurchaseBackend();

  @override
  EntitlementsState build() {
    final owned = ref.read(localStoreProvider).loadOwnedProducts();
    return EntitlementsState(owned: owned);
  }

  Future<PurchaseResult> purchase(StoreProduct product) async {
    if (state.busy) return PurchaseResult.error;
    state = state.copyWith(busy: true);
    final result = await _backend.purchase(product.id);
    if (result == PurchaseResult.success) {
      _grant({product.id});
    } else {
      state = state.copyWith(busy: false);
    }
    return result;
  }

  Future<void> restore() async {
    if (state.busy) return;
    state = state.copyWith(busy: true);
    final restored = await _backend.restore();
    _grant(restored);
  }

  void _grant(Set<String> productIds) {
    final owned = {...state.owned, ...productIds};
    ref.read(localStoreProvider).saveOwnedProducts(owned);
    state = EntitlementsState(owned: owned, busy: false);
  }

  /// Debug only: clears all owned products so the locked/free states can be
  /// re-tested. Has no effect on real store receipts (RevenueCat restores those).
  void resetForDebug() {
    ref.read(localStoreProvider).saveOwnedProducts(<String>{});
    state = const EntitlementsState();
  }
}

final entitlementsProvider =
    NotifierProvider<EntitlementsController, EntitlementsState>(EntitlementsController.new);
