import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics.dart';
import '../services/firestore_sync.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'store_provider.dart';

/// Everything the Invite Friends UI needs about the signed-in user's referrals.
class ReferralState {
  /// The user's own shareable code (null until loaded / while signed out).
  final String? code;

  /// The uid of whoever referred this user, if they've redeemed a code.
  final String? referredBy;

  /// How many people have redeemed this user's code.
  final int referralCount;

  /// Whether the one-time referrer reward has already been granted.
  final bool referrerRewarded;

  final bool loading;

  /// True once a load has been attempted, so the UI won't retry forever on error.
  final bool loaded;

  const ReferralState({
    this.code,
    this.referredBy,
    this.referralCount = 0,
    this.referrerRewarded = false,
    this.loading = false,
    this.loaded = false,
  });

  bool get hasRedeemed => referredBy != null;

  ReferralState copyWith({
    String? code,
    String? referredBy,
    int? referralCount,
    bool? referrerRewarded,
    bool? loading,
    bool? loaded,
  }) =>
      ReferralState(
        code: code ?? this.code,
        referredBy: referredBy ?? this.referredBy,
        referralCount: referralCount ?? this.referralCount,
        referrerRewarded: referrerRewarded ?? this.referrerRewarded,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
      );
}

class ReferralController extends Notifier<ReferralState> {
  @override
  ReferralState build() => const ReferralState();

  FirestoreSync get _sync => ref.read(firestoreSyncProvider);
  String? get _uid => ref.read(authServiceProvider).currentUser?.uid;

  /// Loads the user's code, referral count, and redeemed-status, then grants any
  /// earned referrer reward and auto-redeems a pending ?ref= code. Safe to call
  /// repeatedly (e.g. on login and when the Account tab opens).
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) {
      state = const ReferralState(loaded: true);
      return;
    }
    if (state.loading) return;
    state = state.copyWith(loading: true);
    try {
      final info = await _sync.loadReferralInfo(uid);
      state = ReferralState(
        code: info.code,
        referredBy: info.referredBy,
        referralCount: info.referralCount,
        referrerRewarded: info.referrerRewarded,
        loaded: true,
      );
      await _maybeGrantReferrerReward(uid, info.referralCount, info.referrerRewarded);
      await _consumePendingCode();
    } catch (_) {
      state = state.copyWith(loading: false, loaded: true);
    }
  }

  /// Redeems [rawCode] for the signed-in user, granting a free card back on
  /// success. Returns the outcome plus whether a new back was actually unlocked
  /// (false if they already own every card back / are Pro).
  Future<({ReferralRedeemOutcome outcome, bool rewarded})> redeem(String rawCode) async {
    final uid = _uid;
    if (uid == null) return (outcome: ReferralRedeemOutcome.error, rewarded: false);
    final outcome = await _sync.redeemReferral(uid, rawCode);
    var rewarded = false;
    if (outcome == ReferralRedeemOutcome.success) {
      rewarded = _grantRewardBack() != null;
      if (rewarded) Analytics.referralRewardGranted('referee');
      await ref.read(localStoreProvider).clearPendingReferral();
      await refresh();
    }
    Analytics.inviteRedeemed(outcome.name, rewarded: rewarded);
    return (outcome: outcome, rewarded: rewarded);
  }

  /// A pending code captured from a web ?ref= link is redeemed once the user is
  /// signed in and hasn't already been referred. Cleared unless the failure was
  /// transient, so a bad/stale link doesn't keep retrying.
  Future<void> _consumePendingCode() async {
    if (state.hasRedeemed) {
      await ref.read(localStoreProvider).clearPendingReferral();
      return;
    }
    final pending = ref.read(localStoreProvider).loadPendingReferral();
    if (pending == null || pending.isEmpty) return;
    final res = await redeem(pending);
    if (res.outcome != ReferralRedeemOutcome.error) {
      await ref.read(localStoreProvider).clearPendingReferral();
    }
  }

  /// Grants the referrer their one-time reward once someone has used their code.
  /// Guarded by the persisted [referrerRewarded] flag so the "next unowned back"
  /// reward is handed out exactly once, not on every launch.
  Future<void> _maybeGrantReferrerReward(String uid, int count, bool alreadyRewarded) async {
    if (count < 1 || alreadyRewarded) return;
    // Persist the claimed flag BEFORE granting: the "next unowned back" reward
    // isn't idempotent, so if this write failed after granting we'd hand out a
    // fresh back on every launch. If it throws we grant nothing and retry next
    // time — no double reward. (Marked even if they own everything.)
    await _sync.markReferrerRewarded(uid);
    state = state.copyWith(referrerRewarded: true);
    final name = _grantRewardBack();
    if (name != null) {
      Analytics.referralRewardGranted('referrer');
      ref.read(referralRewardProvider.notifier).celebrate(name);
    }
  }

  /// Grants the first catalog card back the user doesn't already own, returning
  /// its display name — or null if they own them all / are Pro (nothing granted).
  String? _grantRewardBack() {
    final ent = ref.read(entitlementsProvider);
    for (final p in cardBackProducts) {
      if (!ent.isCosmeticUnlocked(p.cosmeticId)) {
        final granted = ref.read(entitlementsProvider.notifier).grantFree({p.id});
        return granted ? p.name : null;
      }
    }
    return null;
  }
}

/// A just-earned referrer reward awaiting a celebratory toast — carries the
/// granted card back's name. The app shell shows it and calls [consume].
class ReferralRewardController extends Notifier<String?> {
  @override
  String? build() => null;

  void celebrate(String cardBackName) => state = cardBackName;

  void consume() {
    if (state != null) state = null;
  }
}

final referralRewardProvider =
    NotifierProvider<ReferralRewardController, String?>(ReferralRewardController.new);

final referralProvider =
    NotifierProvider<ReferralController, ReferralState>(ReferralController.new);
