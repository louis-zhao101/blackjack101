import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/purchases_service.dart';
import '../ui/theme/appearance.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

/// The default skin every player owns for free.
const String kFreeThemeId = 'classic-green';

/// Internal marker id the app stores in [EntitlementsState.owned] once any
/// all-access entitlement is active — it means "all cosmetics unlocked". This is
/// NOT a real store product; the purchasable lifetime SKU is
/// [kLifetimeAppStoreProductId].
const String kLifetimeProductId = 'lifetime_access';

/// The real App Store / RevenueCat product id the user actually buys for
/// lifetime access. Used to look up its live price for display.
const String kLifetimeAppStoreProductId = 'blackjack_pro_lifetime';

/// Fallback lifetime price, shown only until the live store price loads.
const String kLifetimePrice = '\$34.99';

/// The category of cosmetic a [StoreProduct] unlocks.
enum CosmeticKind { lifetime, theme, cardBack, deck, bundle }

/// A non-consumable product for sale. [cosmeticId] links to the appearance id it
/// unlocks (an [AppearanceTheme] or [CardBack]); the lifetime unlock uses an
/// empty [cosmeticId] and grants everything.
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

  /// For a [CosmeticKind.bundle], the product ids it unlocks when bought. Empty
  /// for single-cosmetic products.
  final List<String> grants;

  const StoreProduct({
    required this.id,
    required this.kind,
    required this.cosmeticId,
    required this.name,
    required this.priceLabel,
    this.grants = const [],
  });

  bool get isLifetime => kind == CosmeticKind.lifetime;
  bool get isBundle => kind == CosmeticKind.bundle;
}

const String _cosmeticPrice = '\$1.99';

/// A full hand-illustrated 52-card deck is a premium tier above single cosmetics.
const String _deckPrice = '\$3.99';

/// A deck + its matching card back, sold together below the à la carte total
/// ($3.99 deck + $1.99 back = $5.98).
const String _bundlePrice = '\$4.99';

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
      id: 'theme_slate',
      kind: CosmeticKind.theme,
      cosmeticId: 'slate',
      name: 'Slate',
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
  StoreProduct(
      id: 'back_sapphire',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-sapphire',
      name: 'Sapphire',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_jade',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-jade',
      name: 'Jade',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_garnet',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-garnet',
      name: 'Garnet',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_platinum',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-platinum',
      name: 'Platinum',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_illuminated',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-illuminated',
      name: 'Illuminated',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_ukiyoe',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-ukiyoe',
      name: 'Ukiyo-e',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_greek',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-greek',
      name: 'Greek Vase',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_egyptian',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-egyptian',
      name: 'Egyptian',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_gyotaku',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-gyotaku',
      name: 'Gyotaku',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_tarot',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-tarot',
      name: 'Tarot',
      priceLabel: _cosmeticPrice),
  StoreProduct(
      id: 'back_audubon',
      kind: CosmeticKind.cardBack,
      cosmeticId: 'back-audubon',
      name: 'Audubon',
      priceLabel: _cosmeticPrice),
  // Card-face decks (Classic is the free default, intentionally not listed).
  StoreProduct(
      id: 'deck_illuminated',
      kind: CosmeticKind.deck,
      cosmeticId: 'deck-illuminated',
      name: 'Illuminated',
      priceLabel: _deckPrice),
  StoreProduct(
      id: 'deck_ukiyoe',
      kind: CosmeticKind.deck,
      cosmeticId: 'deck-ukiyoe',
      name: 'Ukiyo-e',
      priceLabel: _deckPrice),
  StoreProduct(
      id: 'deck_greek',
      kind: CosmeticKind.deck,
      cosmeticId: 'deck-greek',
      name: 'Greek Vase',
      priceLabel: _deckPrice),
  StoreProduct(
      id: 'deck_egyptian',
      kind: CosmeticKind.deck,
      cosmeticId: 'deck-egyptian',
      name: 'Egyptian',
      priceLabel: _deckPrice),
  StoreProduct(
      id: 'deck_gyotaku',
      kind: CosmeticKind.deck,
      cosmeticId: 'deck-gyotaku',
      name: 'Gyotaku',
      priceLabel: _deckPrice),
  StoreProduct(
      id: 'deck_tarot',
      kind: CosmeticKind.deck,
      cosmeticId: 'deck-tarot',
      name: 'Tarot',
      priceLabel: _deckPrice),
  StoreProduct(
      id: 'deck_audubon',
      kind: CosmeticKind.deck,
      cosmeticId: 'deck-audubon',
      name: 'Audubon Birds',
      priceLabel: _deckPrice),
  // Theme sets — a premium deck paired with its matching card back, discounted
  // against buying both separately. Owning a bundle unlocks each granted product.
  StoreProduct(
      id: 'bundle_illuminated',
      kind: CosmeticKind.bundle,
      cosmeticId: 'deck-illuminated',
      name: 'Illuminated Set',
      priceLabel: _bundlePrice,
      grants: ['deck_illuminated', 'back_illuminated']),
  StoreProduct(
      id: 'bundle_ukiyoe',
      kind: CosmeticKind.bundle,
      cosmeticId: 'deck-ukiyoe',
      name: 'Ukiyo-e Set',
      priceLabel: _bundlePrice,
      grants: ['deck_ukiyoe', 'back_ukiyoe']),
  StoreProduct(
      id: 'bundle_greek',
      kind: CosmeticKind.bundle,
      cosmeticId: 'deck-greek',
      name: 'Greek Vase Set',
      priceLabel: _bundlePrice,
      grants: ['deck_greek', 'back_greek']),
  StoreProduct(
      id: 'bundle_egyptian',
      kind: CosmeticKind.bundle,
      cosmeticId: 'deck-egyptian',
      name: 'Egyptian Set',
      priceLabel: _bundlePrice,
      grants: ['deck_egyptian', 'back_egyptian']),
  StoreProduct(
      id: 'bundle_gyotaku',
      kind: CosmeticKind.bundle,
      cosmeticId: 'deck-gyotaku',
      name: 'Gyotaku Set',
      priceLabel: _bundlePrice,
      grants: ['deck_gyotaku', 'back_gyotaku']),
  StoreProduct(
      id: 'bundle_tarot',
      kind: CosmeticKind.bundle,
      cosmeticId: 'deck-tarot',
      name: 'Tarot Set',
      priceLabel: _bundlePrice,
      grants: ['deck_tarot', 'back_tarot']),
  StoreProduct(
      id: 'bundle_audubon',
      kind: CosmeticKind.bundle,
      cosmeticId: 'deck-audubon',
      name: 'Audubon Set',
      priceLabel: _bundlePrice,
      grants: ['deck_audubon', 'back_audubon']),
];

/// The headline lifetime product.
StoreProduct get lifetimeProduct => storeProducts.firstWhere((p) => p.isLifetime);

List<StoreProduct> _ofKind(CosmeticKind kind) =>
    storeProducts.where((p) => p.kind == kind).toList();

/// Themes sold individually, in catalog order.
List<StoreProduct> get themeProducts => _ofKind(CosmeticKind.theme);

/// Card backs sold individually, in catalog order.
List<StoreProduct> get cardBackProducts => _ofKind(CosmeticKind.cardBack);

/// Card-face decks sold individually, in catalog order.
List<StoreProduct> get deckProducts => _ofKind(CosmeticKind.deck);

/// Deck + matching card back sets, in catalog order.
List<StoreProduct> get bundleProducts => _ofKind(CosmeticKind.bundle);

StoreProduct? productById(String id) {
  for (final p in storeProducts) {
    if (p.id == id) return p;
  }
  return null;
}

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

/// RevenueCat adapter for à la carte cosmetics (non-consumables). Pro itself is
/// bought through the hosted paywall (see [PurchasesService]); this backend
/// powers the per-cosmetic "Unlock" buttons in the Shop. Used on iOS/Android;
/// web/desktop stay on [LocalPurchaseBackend].
class RevenueCatPurchaseBackend implements PurchaseBackend {
  @override
  Future<PurchaseResult> purchase(String productId) async {
    try {
      final products = await Purchases.getProducts(
        [productId],
        productCategory: ProductCategory.nonSubscription,
      );
      if (products.isEmpty) return PurchaseResult.error;
      // Throws on failure/cancellation; reaching the next line means success.
      await Purchases.purchase(PurchaseParams.storeProduct(products.first));
      return PurchaseResult.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      return code == PurchasesErrorCode.purchaseCancelledError
          ? PurchaseResult.cancelled
          : PurchaseResult.error;
    }
  }

  @override
  Future<Set<String>> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      final owned = {...info.allPurchasedProductIdentifiers};
      // The lifetime (all-access) entitlement unlocks every cosmetic, surfaced
      // to the app as the lifetime product it treats as premium. A subscription
      // (blackjack_pro only) restores its training access via the CustomerInfo
      // listener, not here.
      if (info.entitlements.active.containsKey(kAllAccessEntitlement)) {
        owned.add(kLifetimeProductId);
      }
      return owned;
    } on PlatformException {
      return <String>{};
    }
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
  /// the player bought it individually. Works for themes, card backs, and decks.
  bool isCosmeticUnlocked(String cosmeticId) {
    if (cosmeticId == kFreeThemeId ||
        cosmeticId == kFreeCardBackId ||
        cosmeticId == kFreeCardDeckId) {
      return true;
    }
    if (isPremium) return true;
    final product = productForCosmeticId(cosmeticId);
    if (product == null) return false;
    if (owned.contains(product.id)) return true;
    // A bundle unlocks each product it grants.
    for (final b in bundleProducts) {
      if (owned.contains(b.id) && b.grants.contains(product.id)) return true;
    }
    return false;
  }

  bool ownsProduct(String productId) => owned.contains(productId);

  /// Whether any card back is still unowned — false for Pro or a completionist.
  /// The referral UI uses this so it never promises a reward it can't grant.
  bool get hasUnlockableCardBack =>
      cardBackProducts.any((p) => !isCosmeticUnlocked(p.cosmeticId));

  EntitlementsState copyWith({Set<String>? owned, bool? busy}) =>
      EntitlementsState(owned: owned ?? this.owned, busy: busy ?? this.busy);
}

class EntitlementsController extends Notifier<EntitlementsState> {
  final PurchaseBackend _backend = PurchasesService.isSupported
      ? RevenueCatPurchaseBackend()
      : LocalPurchaseBackend();

  @override
  EntitlementsState build() {
    final owned = {...ref.read(localStoreProvider).loadOwnedProducts()};
    // Only the lifetime purchase unlocks cosmetics — fold it in as the lifetime
    // product the rest of the app treats as premium. A subscription grants
    // training features (via proStatus.isPro) but NOT cosmetics, so it must not
    // add the lifetime id here.
    if (ref.watch(proStatusProvider).hasAllAccess) owned.add(kLifetimeProductId);
    return EntitlementsState(owned: owned);
  }

  Future<PurchaseResult> purchase(StoreProduct product) async {
    if (state.busy) return PurchaseResult.error;
    state = state.copyWith(busy: true);
    await _syncIdentity();
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
    await _syncIdentity();
    final restored = await _backend.restore();
    _grant(restored);
  }

  /// Ensures RevenueCat's identity matches the signed-in Firebase user before a
  /// purchase/restore, so it's never attributed to a stale anonymous id (e.g.
  /// after a dev logOut). No-op for guests and on web.
  Future<void> _syncIdentity() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) await PurchasesService.logIn(uid);
  }

  void _grant(Set<String> productIds) {
    final owned = {...state.owned, ...productIds};
    _persist(owned);
    state = EntitlementsState(owned: owned, busy: false);
  }

  /// Grants products for free — referral rewards, promos. Idempotent: returns
  /// false without writing if everything is already owned, so callers can tell
  /// whether a reward was newly unlocked (e.g. to celebrate it).
  bool grantFree(Set<String> productIds) {
    if (productIds.difference(state.owned).isEmpty) return false;
    _grant(productIds);
    return true;
  }

  /// Merges cosmetics loaded from the user's cloud profile (on login) into the
  /// owned set, so à la carte unlocks follow the account across devices without
  /// needing a Restore tap.
  void mergeOwnedFromCloud(Set<String> cloudOwned) {
    final incoming = cloudOwned.difference(_proOnly);
    if (incoming.isEmpty) return;
    final owned = {...state.owned, ...incoming};
    _persist(owned);
    state = state.copyWith(owned: owned);
  }

  /// Persists cosmetic ownership locally and (if signed in) to the cloud. The
  /// Pro/lifetime id is never persisted — Pro is always resolved live from
  /// RevenueCat, so persisting it would leave a lapsed subscriber looking
  /// premium forever.
  void _persist(Set<String> owned) {
    final cosmetics = owned.difference(_proOnly);
    ref.read(localStoreProvider).saveOwnedProducts(cosmetics);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(syncQueueProvider.notifier).ownedProducts(uid, cosmetics);
    }
  }

  static const Set<String> _proOnly = {kLifetimeProductId};

  /// Debug only: clears all owned products so the locked/free states can be
  /// re-tested. Has no effect on real store receipts (RevenueCat restores those).
  void resetForDebug() {
    ref.read(localStoreProvider).saveOwnedProducts(<String>{});
    state = const EntitlementsState();
  }
}

final entitlementsProvider =
    NotifierProvider<EntitlementsController, EntitlementsState>(EntitlementsController.new);

/// Live Blackjack Pro entitlement state, sourced from RevenueCat's CustomerInfo
/// update listener (the single source of truth — it fires on purchase, restore,
/// renewal, expiry, and cross-device changes).
class ProStatus {
  /// Training features (drill, lessons, stats, difficulty). True for any plan —
  /// subscription or lifetime.
  final bool isPro;

  /// All cosmetics unlocked. True only for the lifetime purchase, never a
  /// subscription.
  final bool hasAllAccess;
  final CustomerInfo? info;
  const ProStatus({this.isPro = false, this.hasAllAccess = false, this.info});

  /// The store product id currently granting Pro (the active subscription, or
  /// the lifetime product). Null when not Pro. Lets the paywall mark the plan
  /// the user is already on.
  String? get activeProductId => info?.entitlements.active[kProEntitlement]?.productIdentifier;

  static ProStatus of(CustomerInfo? info) => ProStatus(
        isPro: PurchasesService.isProActive(info),
        hasAllAccess: PurchasesService.isAllAccessActive(info),
        info: info,
      );
}

class ProStatusController extends Notifier<ProStatus> {
  @override
  ProStatus build() {
    if (PurchasesService.isReady) {
      void listener(CustomerInfo info) => state = ProStatus.of(info);

      Purchases.addCustomerInfoUpdateListener(listener);
      ref.onDispose(() => Purchases.removeCustomerInfoUpdateListener(listener));
      _hydrate();
    }
    return const ProStatus();
  }

  Future<void> _hydrate() async {
    state = ProStatus.of(await PurchasesService.currentInfo());
  }

  Future<void> refresh() => _hydrate();
}

final proStatusProvider =
    NotifierProvider<ProStatusController, ProStatus>(ProStatusController.new);

/// Live localized store prices (productId → priceString) for the à la carte
/// cosmetics and the lifetime unlock. Empty until RevenueCat loads them (web, or
/// products not yet live in the store), so callers fall back to the built-in
/// [StoreProduct.priceLabel] / [kLifetimePrice].
final livePricesProvider = FutureProvider<Map<String, String>>((ref) async {
  // Re-run once Pro status hydrates, i.e. after RevenueCat finishes configuring,
  // so prices still load if this was first read before the SDK was ready.
  ref.watch(proStatusProvider);
  final ids = <String>[
    for (final p in storeProducts)
      if (!p.isLifetime) p.id,
    kLifetimeAppStoreProductId,
  ];
  return PurchasesService.fetchPrices(ids);
});

/// The price to display for [product]: the live localized store price when
/// loaded, else the built-in fallback label. Null for products with no store
/// entry (the free defaults).
String? livePriceLabel(WidgetRef ref, StoreProduct? product) {
  if (product == null) return null;
  return ref.watch(livePricesProvider).value?[product.id] ?? product.priceLabel;
}

/// The lifetime unlock's live price, falling back to [kLifetimePrice].
String lifetimePriceLabel(WidgetRef ref) =>
    ref.watch(livePricesProvider).value?[kLifetimeAppStoreProductId] ?? kLifetimePrice;
