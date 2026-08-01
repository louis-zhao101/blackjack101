import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engine/stats.dart';
import '../services/firestore_sync.dart';
import '../services/local_store.dart';

/// Overridden in main() with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final localStoreProvider =
    Provider<LocalStore>((ref) => LocalStore(ref.watch(sharedPreferencesProvider)));

final firestoreSyncProvider = Provider<FirestoreSync>((ref) => FirestoreSync());

/// The selected bottom-nav tab (0 Play, 1 Learn, 2 Stats, 3 Account). Held here
/// so any screen can navigate between tabs — e.g. tapping accuracy on the table
/// jumps to Stats.
class NavController extends Notifier<int> {
  @override
  int build() => 0;

  void select(int tab) => state = tab;
}

final navTabProvider = NotifierProvider<NavController, int>(NavController.new);

enum SyncPhase { idle, syncing, failed }

class SyncStatus {
  final SyncPhase phase;

  /// How many distinct writes are still waiting to reach the server.
  final int pending;

  const SyncStatus(this.phase, this.pending);
  const SyncStatus.idle()
      : phase = SyncPhase.idle,
        pending = 0;
}

/// Coordinates every background write to Firestore so a dropped connection can
/// never silently lose data. Writes are coalesced per key (latest wins — the
/// upserts are idempotent), retried with backoff, and the resulting [SyncPhase]
/// drives the "sync failed" indicator in the app header. A failed drain leaves
/// its work queued: the next enqueue (e.g. the next hand played) retries it, as
/// does an explicit [retry].
class SyncController extends Notifier<SyncStatus> {
  late final FirestoreSync _sync;
  final Map<String, Future<void> Function()> _pending = {};
  bool _draining = false;

  static const _maxAttempts = 3;
  static const _attemptTimeout = Duration(seconds: 12);

  @override
  SyncStatus build() {
    _sync = ref.read(firestoreSyncProvider);
    return const SyncStatus.idle();
  }

  void session(String uid, Session s) =>
      _enqueue('session:${s.id}', () => _sync.upsertSession(uid, s));

  void ownedProducts(String uid, Set<String> ids) =>
      _enqueue('owned', () => _sync.upsertOwnedProducts(uid, ids));

  void achievements(String uid, Set<String> ids) =>
      _enqueue('achievements', () => _sync.upsertAchievements(uid, ids));

  void strategyCells(String uid, Map<String, (int, int)> cells) =>
      _enqueue('strategyCells', () => _sync.upsertStrategyCells(uid, cells));

  void drill(
    String uid, {
    required int total,
    required int correct,
    required int bestStreak,
    required Set<String> attempted,
    required List<bool> recent,
  }) =>
      _enqueue(
          'drill',
          () => _sync.upsertDrillStats(uid,
              total: total,
              correct: correct,
              bestStreak: bestStreak,
              attempted: attempted,
              recent: recent));

  void learnProgress(String uid, Set<String> ids) =>
      _enqueue('learnProgress', () => _sync.upsertLearnProgress(uid, ids));

  void cosmeticSelection(String uid,
          {String? appearance, String? cardBack}) =>
      _enqueue(
          'cosmeticSel',
          () => _sync.upsertCosmeticSelection(uid,
              appearance: appearance, cardBack: cardBack));

  /// Manually re-attempt a failed queue (e.g. the user tapped the indicator).
  void retry() {
    if (_pending.isNotEmpty) _drain();
  }

  void _enqueue(String key, Future<void> Function() op) {
    _pending[key] = op;
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    state = SyncStatus(SyncPhase.syncing, _pending.length);
    var failed = false;
    while (_pending.isNotEmpty) {
      final key = _pending.keys.first;
      final op = _pending[key]!;
      if (await _run(op)) {
        // Keep any newer write for the same key that arrived mid-flight.
        if (identical(_pending[key], op)) _pending.remove(key);
      } else {
        failed = true;
        break;
      }
    }
    _draining = false;
    state = failed
        ? SyncStatus(SyncPhase.failed, _pending.length)
        : const SyncStatus.idle();
  }

  Future<bool> _run(Future<void> Function() op) async {
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        await op().timeout(_attemptTimeout);
        return true;
      } catch (_) {
        if (attempt < _maxAttempts - 1) {
          await Future<void>.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
    return false;
  }
}

final syncQueueProvider =
    NotifierProvider<SyncController, SyncStatus>(SyncController.new);

/// Whether the first-run onboarding has been completed. Gates [OnboardingPage].
class OnboardingController extends Notifier<bool> {
  @override
  bool build() => ref.read(localStoreProvider).loadOnboarded();

  void complete() {
    if (state) return;
    state = true;
    ref.read(localStoreProvider).saveOnboarded(true);
  }

  void reset() {
    state = false;
    ref.read(localStoreProvider).saveOnboarded(false);
  }
}

final onboardingSeenProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

/// Whether the visitor has stepped past the web marketing landing page into the
/// app. Web-only: on mobile there's no landing page, so it's always "seen" and
/// never gates. Persisted so a returning web visitor boots straight into play.
class LandingController extends Notifier<bool> {
  @override
  bool build() =>
      !kIsWeb || ref.read(localStoreProvider).loadLandingSeen();

  void enter() {
    if (state) return;
    state = true;
    ref.read(localStoreProvider).saveLandingSeen(true);
  }

  /// Return to the landing page from inside the app (web only). Re-showing it
  /// doesn't replay the splash or onboarding — those flags stay set — so
  /// tapping "Play" again drops straight back into the game.
  void exit() {
    state = false;
    ref.read(localStoreProvider).saveLandingSeen(false);
  }
}

final landingSeenProvider =
    NotifierProvider<LandingController, bool>(LandingController.new);

/// The app's public web address — the custom domain, served by Firebase Hosting.
/// Single source of truth for every user-facing link; change it here only.
const String kAppBaseUrl = 'https://blackjack101.app';

/// Canonical hosted address of the privacy policy, used for the in-app link on
/// native platforms (where there's no same-origin `/privacy.html` to resolve).
const String kPrivacyPolicyUrl = '$kAppBaseUrl/privacy.html';

/// Public URL included in shared result cards / invites so recipients can open
/// the (instantly playable) web app.
const String kAppShareUrl = kAppBaseUrl;

/// Opens the privacy policy. On web the page ships alongside the app at the same
/// origin, so a relative path resolves; on mobile it opens the hosted copy.
Future<void> openPrivacyPolicy() async {
  final target = kIsWeb ? '/privacy.html' : kPrivacyPolicyUrl;
  await launchUrl(Uri.base.resolve(target),
      webOnlyWindowName: '_self', mode: LaunchMode.externalApplication);
}

/// Apple's standard Terms of Use (EULA) — the subscription paywall links to this
/// to satisfy App Review guideline 3.1.2 (functional Terms of Use in the binary).
const String kTermsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// Opens the Terms of Use (EULA).
Future<void> openTermsOfUse() async {
  await launchUrl(Uri.parse(kTermsOfUseUrl),
      webOnlyWindowName: '_blank', mode: LaunchMode.externalApplication);
}

/// True once startup work is done — the initial Firebase load finished, or the
/// user is a guest with nothing to load. The splash watches this to know when it
/// may begin its exit; visual timing (minimum deal cycles) is owned by the
/// splash itself.
class AppBootstrapController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Safe to call more than once.
  void dataLoaded() {
    if (!state) state = true;
  }
}

final appReadyProvider =
    NotifierProvider<AppBootstrapController, bool>(AppBootstrapController.new);

/// Flipped by the launch splash after it has played its exit animation. The app
/// stays on the splash until this is true, so the splash controls its own
/// dismissal (deal in, then fly the cards off) rather than being cut mid-frame.
class SplashController extends Notifier<bool> {
  @override
  bool build() => false;

  void markDone() {
    if (!state) state = true;
  }
}

final splashDoneProvider =
    NotifierProvider<SplashController, bool>(SplashController.new);

/// Whether we've already surfaced an in-app App Store review request. Lets us
/// nudge for a review at positive moments (a strong session, finishing the
/// lessons) without nagging. The native prompt is further throttled by the OS
/// and silently no-ops for users who already rated. Disabled on web, where
/// there is no store review flow.
class ReviewController extends Notifier<bool> {
  @override
  bool build() => ref.read(localStoreProvider).loadReviewRequested();

  /// Requests a review at a positive moment, at most once in-app. Safe to call
  /// from several "review points" — later calls no-op once one has fired.
  Future<void> maybePrompt() async {
    if (kIsWeb || state) return;
    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      await review.requestReview();
    } catch (_) {
      return;
    }
    state = true;
    ref.read(localStoreProvider).saveReviewRequested(true);
  }

  void reset() {
    state = false;
    ref.read(localStoreProvider).saveReviewRequested(false);
  }
}

final reviewPromptProvider =
    NotifierProvider<ReviewController, bool>(ReviewController.new);

/// A one-shot nudge to share a result, raised at a positive moment (a strong
/// session, a hot streak). The app shell listens and surfaces a snackbar with a
/// "Share" action; [carries] the numbers a results card needs so the shell
/// doesn't have to recompute them. Kept separate from the achievement toast,
/// which shares the specific badge instead.
class ShareInvite {
  final String message;
  final int accuracy;
  final int totalHands;
  final int bestStreak;
  const ShareInvite({
    required this.message,
    required this.accuracy,
    required this.totalHands,
    required this.bestStreak,
  });
}

class ShareInviteController extends Notifier<ShareInvite?> {
  @override
  ShareInvite? build() => null;

  void push(ShareInvite invite) => state = invite;

  void consume() {
    if (state != null) state = null;
  }
}

final shareInviteProvider =
    NotifierProvider<ShareInviteController, ShareInvite?>(ShareInviteController.new);
