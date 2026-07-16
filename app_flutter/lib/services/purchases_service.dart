import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// RevenueCat entitlement identifier that unlocks Blackjack Pro. Must match the
/// entitlement identifier configured in the RevenueCat dashboard exactly.
const String kProEntitlement = 'blackjack_pro';

/// Publishable RevenueCat SDK key, chosen per platform. Publishable keys
/// (appl_… for Apple, goog_… for Google) are safe to embed in the binary; a
/// --dart-define override lets a build/flavor swap them — e.g. a test-store
/// (test_…) key for local QA without a store connection.
///
/// A `test_…` key runs fine in Debug/Simulator, but RevenueCat force-quits any
/// TestFlight/App Store build that ships one (the "Wrong API Key" crash), so
/// release builds must use the appl_/goog_ platform keys below.
const String _rcApiKeyApple = String.fromEnvironment(
  'RC_API_KEY_APPLE',
  defaultValue: 'appl_nKVEeqlKzfEmaidtRFGTEvqVvag',
);
const String _rcApiKeyGoogle = String.fromEnvironment(
  'RC_API_KEY_GOOGLE',
  // TODO: paste the goog_… key here once the Play Store app is added in
  // RevenueCat. Left empty so Android configures with no key (purchases
  // disabled) rather than the wrong platform's key.
  defaultValue: '',
);

/// The publishable key for the current platform.
String get _rcApiKey => defaultTargetPlatform == TargetPlatform.android
    ? _rcApiKeyGoogle
    : _rcApiKeyApple;

/// Thin wrapper over the RevenueCat SDK. Every method is a no-op on web/desktop
/// so those builds keep compiling and running without a store backend.
class PurchasesService {
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool _configured = false;

  /// True once the SDK configured successfully. Runtime RevenueCat calls are
  /// gated on this so a missing/invalid key degrades gracefully (purchases
  /// unavailable) instead of crashing the app at launch.
  static bool get isReady => isSupported && _configured;

  /// Call once at startup, before any purchase or paywall UI. A bad or missing
  /// key is swallowed so the rest of the app still launches.
  static Future<void> configure() async {
    if (!isSupported || _rcApiKey.isEmpty) return;
    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(_rcApiKey));
      _configured = true;
    } catch (e) {
      debugPrint('RevenueCat configure failed — purchases disabled: $e');
    }
  }

  /// Ties purchases to the given app user id (the Firebase uid) so entitlements
  /// follow the account across devices. Call on sign-in.
  static Future<void> logIn(String appUserId) async {
    if (!isReady) return;
    try {
      await Purchases.logIn(appUserId);
    } catch (_) {
      // Non-fatal: purchases still work against the anonymous id.
    }
  }

  static Future<void> logOut() async {
    if (!isReady) return;
    try {
      await Purchases.logOut();
    } on PlatformException {
      // Already anonymous — nothing to do.
    }
  }

  static Future<CustomerInfo?> currentInfo() async {
    if (!isReady) return null;
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
    if (!isReady) return null;
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
    if (!isReady) return false;
    final result = await RevenueCatUI.presentPaywallIfNeeded(kProEntitlement);
    return result == PaywallResult.purchased || result == PaywallResult.restored;
  }

  /// Always shows the paywall (e.g. from a "Go Pro" button). Returns true if
  /// the user came out of it with Pro.
  static Future<bool> presentPaywall() async {
    if (!isReady) return false;
    final result = await RevenueCatUI.presentPaywall();
    return result == PaywallResult.purchased || result == PaywallResult.restored;
  }

  /// Self-service subscription management (cancel, refund, restore, plan
  /// changes). Only meaningful once the user has an active/expired purchase.
  static Future<void> presentCustomerCenter() async {
    if (!isReady) return;
    await RevenueCatUI.presentCustomerCenter();
  }

  /// Dev-only: drops the current identified user for a fresh anonymous customer
  /// with no entitlements, so the locked/free state can be re-tested. Does NOT
  /// delete the real purchase (that's a server-side op) — signing back in
  /// restores Pro. No-op when the user is already anonymous.
  static Future<void> debugResetIdentity() async {
    if (!isReady) return;
    try {
      await Purchases.logOut();
    } on PlatformException {
      // Current user is already anonymous — logOut isn't allowed; nothing to do.
    }
  }
}
