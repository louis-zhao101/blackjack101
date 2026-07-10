import 'package:firebase_analytics/firebase_analytics.dart';

/// Thin wrapper over Firebase Analytics for the growth funnel (shares, invites,
/// referral rewards). Fire-and-forget: telemetry must never break a user flow,
/// so every call swallows its errors.
class Analytics {
  static final FirebaseAnalytics _a = FirebaseAnalytics.instance;

  static void _log(String name, [Map<String, Object>? params]) {
    _a.logEvent(name: name, parameters: params).catchError((_) {});
  }

  /// Forces analytics to initialize (loading gtag on web) and records an
  /// app-open, so a session and "active user" register even if the player never
  /// triggers another event. Call once at startup, after Firebase.initializeApp.
  static Future<void> appOpen() async {
    // Separate try/catch: if enabling collection throws (some web builds), the
    // app-open log must still fire so analytics initializes and a session opens.
    try {
      await _a.setAnalyticsCollectionEnabled(true);
    } catch (_) {}
    try {
      await _a.logAppOpen();
    } catch (_) {}
  }

  /// A result / achievement card was handed to the OS share sheet. [type] is
  /// 'result' or 'achievement'.
  static void shared(String type) => _log('content_shared', {'type': type});

  /// The user tapped "Share invite" to send their referral code.
  static void inviteShared() => _log('invite_shared');

  /// An invite code redemption was attempted. [outcome] is the enum name;
  /// [rewarded] is whether a card back was actually granted.
  static void inviteRedeemed(String outcome, {required bool rewarded}) =>
      _log('invite_redeemed', {'outcome': outcome, 'rewarded': rewarded.toString()});

  /// A referral card back was granted. [role] is 'referrer' or 'referee'.
  static void referralRewardGranted(String role) =>
      _log('referral_reward_granted', {'role': role});
}
