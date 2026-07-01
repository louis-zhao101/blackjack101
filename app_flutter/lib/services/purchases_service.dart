import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat entitlement identifier that unlocks Blackjack Pro. Must match the
/// entitlement identifier configured in the RevenueCat dashboard exactly.
const String kProEntitlement = 'blackjack_pro';

/// Publishable RevenueCat SDK key. Publishable keys are safe to embed in the
/// binary, but a --dart-define=RC_API_KEY=... override lets each build/flavor
/// supply its own (e.g. the production appl_… / goog_… platform keys).
const String _rcApiKey = String.fromEnvironment(
  'RC_API_KEY',
  defaultValue: 'test_UhiLxkydXFHZQRnpXzNOLLVsATR',
);

/// Thin wrapper over the RevenueCat SDK. Every method is a no-op on web/desktop
/// so those builds keep compiling and running without a store backend.
class PurchasesService {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Call once at startup, before any purchase or paywall UI.
  static Future<void> configure() async {
    if (!isSupported) return;
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(_rcApiKey));
  }

  /// Ties purchases to the given app user id (the Firebase uid) so entitlements
  /// follow the account across devices. Call on sign-in.
  static Future<void> logIn(String appUserId) async {
    if (!isSupported) return;
    try {
      await Purchases.logIn(appUserId);
    } on PlatformException {
      // Non-fatal: purchases still work against the anonymous id.
    }
  }

  static Future<void> logOut() async {
    if (!isSupported) return;
    try {
      await Purchases.logOut();
    } on PlatformException {
      // Already anonymous — nothing to do.
    }
  }

  static Future<CustomerInfo?> currentInfo() async {
    if (!isSupported) return null;
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException {
      return null;
    }
  }

  static bool isProActive(CustomerInfo? info) =>
      info?.entitlements.active.containsKey(kProEntitlement) ?? false;

  /// The current Offering (its packages back the custom Go Pro paywall).
  /// Returns null on web/desktop or if fetching fails / none is configured.
  static Future<Offering?> currentOffering() async {
    if (!isSupported) return null;
    try {
      return (await Purchases.getOfferings()).current;
    } on PlatformException {
      return null;
    }
  }

  /// Buys [package] and returns true once Blackjack Pro is active. User
  /// cancellation returns false; genuine failures rethrow so the UI can message.
  static Future<bool> purchasePackage(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return isProActive(result.customerInfo);
  }

  /// Maps a caught purchase error to whether the user simply cancelled.
  static bool isCancellation(Object error) =>
      error is PlatformException &&
      PurchasesErrorHelper.getErrorCode(error) ==
          PurchasesErrorCode.purchaseCancelledError;

  /// Presents the dashboard-designed paywall only when Pro isn't already
  /// active. Returns true once the user has Pro.
  static Future<bool> presentPaywallIfNeeded() async {
    if (!isSupported) return false;
    final result = await RevenueCatUI.presentPaywallIfNeeded(kProEntitlement);
    return result == PaywallResult.purchased || result == PaywallResult.restored;
  }

  /// Always shows the paywall (e.g. from a "Go Pro" button). Returns true if
  /// the user came out of it with Pro.
  static Future<bool> presentPaywall() async {
    if (!isSupported) return false;
    final result = await RevenueCatUI.presentPaywall();
    return result == PaywallResult.purchased || result == PaywallResult.restored;
  }

  /// Self-service subscription management (cancel, refund, restore, plan
  /// changes). Only meaningful once the user has an active/expired purchase.
  static Future<void> presentCustomerCenter() async {
    if (!isSupported) return;
    await RevenueCatUI.presentCustomerCenter();
  }
}
