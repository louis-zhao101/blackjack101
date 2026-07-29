import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/stats.dart';
import '../engine/strategy.dart';
import 'app_providers.dart';
import 'auth_provider.dart';

class StatsState {
  final List<Session> sessions;
  final Session? currentSession;
  const StatsState({this.sessions = const [], this.currentSession});

  StatsState copyWith({
    List<Session>? sessions,
    Session? currentSession,
    bool clearCurrent = false,
  }) =>
      StatsState(
        sessions: sessions ?? this.sessions,
        currentSession: clearCurrent ? null : (currentSession ?? this.currentSession),
      );
}

class StatsController extends Notifier<StatsState> {
  @override
  StatsState build() {
    final store = ref.read(localStoreProvider);
    final loaded = store.loadStats();
    final deviceId = store.deviceId();
    final sessions = [...loaded.sessions];
    var current = loaded.currentSession;

    // Cold-launch cleanup: a fresh run after a gap is a new sitting, so don't let
    // the previous live session linger as "LIVE" until the next deal.
    if (current != null) {
      if (current.hands.isEmpty) {
        current = null; // never-played sitting — drop
      } else if (DateTime.now().millisecondsSinceEpoch - current.hands.last.timestamp >
          kSittingIdleMs) {
        sessions.insert(0, finalizeSession(current));
        current = null;
      } else if (current.deviceId != deviceId) {
        current = current.copyWith(deviceId: deviceId); // claim it for this install
      }
    }
    if (!identical(current, loaded.currentSession)) {
      store.saveStats(sessions, current);
    }
    return StatsState(sessions: sessions, currentSession: current);
  }

  void startSession(String ruleSetId) {
    final deviceId = ref.read(localStoreProvider).deviceId();
    _set(state.copyWith(
        currentSession: createSession(ruleSetId, deviceId: deviceId)));
  }

  void addHandRecord(HandRecord record) {
    final current = state.currentSession;
    if (current == null) return;
    final updated = recordHand(current, record);
    _set(state.copyWith(currentSession: updated));
    _syncSession(updated);
    _maybeInviteStreakShare(updated);
  }

  static const _streakMilestones = {10, 25, 50, 100};

  /// A run of correct decisions crossing a milestone is a hype moment — invite
  /// the player to share it. Fires only when the trailing streak lands exactly
  /// on a milestone, so it triggers once per crossing rather than every hand.
  void _maybeInviteStreakShare(Session session) {
    var streak = 0;
    for (var i = session.hands.length - 1; i >= 0; i--) {
      if (!session.hands[i].wasCorrect) break;
      streak++;
    }
    if (!_streakMilestones.contains(streak)) return;
    final s = summarizeSession(session);
    ref.read(shareInviteProvider.notifier).push(ShareInvite(
          message: '🔥 $streak correct decisions in a row!',
          accuracy: s.correctPct.round(),
          totalHands: s.handsPlayed,
          bestStreak: streak,
        ));
  }

  void finishSession() {
    final current = state.currentSession;
    if (current == null) return;
    // A sitting that ended without a single hand isn't worth charting — drop it.
    if (current.hands.isEmpty) {
      _set(state.copyWith(clearCurrent: true));
      return;
    }
    final finished = endSession(current);
    _set(StatsState(
      sessions: [finished, ...state.sessions].take(50).toList(),
      currentSession: null,
    ));
    _syncSession(finished);
    _maybeAskForReview(finished);
    _maybeInviteSessionShare(finished);
  }

  /// A well-played session is a genuine feel-good moment — a good time to
  /// (gently, once) ask for a review.
  void _maybeAskForReview(Session session) {
    final s = summarizeSession(session);
    if (s.handsPlayed >= 10 && s.correctPct >= 80) {
      ref.read(reviewPromptProvider.notifier).maybePrompt();
    }
  }

  /// A strong finished session is worth showing off — raise a share invite the
  /// shell can surface. Bar is a notch above the review bar so it stays special.
  void _maybeInviteSessionShare(Session session) {
    final s = summarizeSession(session);
    if (s.handsPlayed >= 15 && s.correctPct >= 85) {
      ref.read(shareInviteProvider.notifier).push(ShareInvite(
            message: 'Great session — ${s.correctPct.round()}% strategy accuracy!',
            accuracy: s.correctPct.round(),
            totalHands: s.handsPlayed,
            bestStreak: computeLongestStreak(session.hands),
          ));
    }
  }

  /// Clears the user's stats history: session records and the strategy-cell
  /// heatmap (both shown on the Stats page). Practice drills and earned
  /// achievements are left alone. Clears local *and* cloud so it's permanent.
  void clearHistory() {
    _set(const StatsState(sessions: [], currentSession: null));
    ref.read(strategyStatsProvider.notifier).clearLocal();
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(firestoreSyncProvider).clearStatsHistory(uid).catchError((_) {});
    }
  }

  void loadFromCloud(List<Session> cloudSessions) {
    final deviceId = ref.read(localStoreProvider).deviceId();
    // Keep only this device's still-active sitting as live; every other live
    // session (a foreign device's, or a stale/abandoned one) is finalized rather
    // than dropped — fixing the old bug where extra live sessions vanished.
    final r = reconcileSessions(cloudSessions, deviceId);
    _set(StatsState(sessions: r.sessions, currentSession: r.current));
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      for (final s in r.finalized) {
        ref.read(syncQueueProvider.notifier).session(uid, s);
      }
    }
  }

  void _set(StatsState next) {
    state = next;
    ref.read(localStoreProvider).saveStats(next.sessions, next.currentSession);
  }

  void _syncSession(Session session) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(syncQueueProvider.notifier).session(uid, session);
    }
  }
}

final statsProvider = NotifierProvider<StatsController, StatsState>(StatsController.new);

/// Per-cell strategy accuracy: chart cell key -> (correct, total), accumulated
/// across every decision the player makes. Local-only.
class StrategyStatsController extends Notifier<Map<String, (int, int)>> {
  @override
  Map<String, (int, int)> build() => ref.read(localStoreProvider).loadStrategyCellStats();

  /// Records one decision against its chart cell.
  void record({
    required HandType handType,
    required int playerTotal,
    required bool soft,
    required String dealerUpcard,
    required bool wasCorrect,
  }) {
    final key = strategyCellKey(handType, playerTotal, soft, dealerUpcard);
    final (correct, total) = state[key] ?? (0, 0);
    final next = {
      ...state,
      key: (correct + (wasCorrect ? 1 : 0), total + 1),
    };
    _set(next);
  }

  /// Folds cloud cells into local, keeping whichever device has played a cell
  /// more (greater total) so no device ever regresses.
  void mergeFromCloud(Map<String, (int, int)> cloud) {
    if (cloud.isEmpty) return;
    final merged = {...state};
    var changed = false;
    cloud.forEach((k, v) {
      final cur = merged[k];
      if (cur == null || v.$2 > cur.$2) {
        merged[k] = v;
        changed = true;
      }
    });
    if (changed) _set(merged);
  }

  void reset() => _set(const {});

  /// Clears local cell stats only. The cloud copy is cleared in one shot by
  /// [FirestoreSync.clearStatsHistory], so this must not push an empty map back.
  void clearLocal() {
    state = {};
    ref.read(localStoreProvider).saveStrategyCellStats(const {});
  }

  void _set(Map<String, (int, int)> next) {
    state = next;
    ref.read(localStoreProvider).saveStrategyCellStats(next);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) ref.read(syncQueueProvider.notifier).strategyCells(uid, next);
  }
}

final strategyStatsProvider =
    NotifierProvider<StrategyStatsController, Map<String, (int, int)>>(
        StrategyStatsController.new);

/// Lifetime Test Yourself drill activity, kept apart from real-play stats so
/// practice never touches the session history or bankroll. Feeds the practice
/// achievements. Local-only.
class DrillStats {
  final int total;
  final int correct;
  final int bestStreak;
  final Set<String> attempted;

  /// The correctness of the most recent answers (oldest first), capped at
  /// [_recentCap]. Powers the self-healing "last 100 hands" accuracy metric so
  /// a rough early run washes out instead of permanently sinking the average.
  final List<bool> recent;

  const DrillStats({
    this.total = 0,
    this.correct = 0,
    this.bestStreak = 0,
    this.attempted = const {},
    this.recent = const [],
  });

  int get recentCount => recent.length;
  int get recentCorrect => recent.where((c) => c).length;
}

const int _recentCap = 100;

class DrillStatsController extends Notifier<DrillStats> {
  @override
  DrillStats build() {
    final s = ref.read(localStoreProvider).loadDrillStats();
    return DrillStats(
      total: s.total,
      correct: s.correct,
      bestStreak: s.bestStreak,
      attempted: s.attempted,
      recent: s.recent,
    );
  }

  /// Records one drill decision. [streak] is the current run's correct streak
  /// after this answer, so the lifetime best can only grow.
  void record({required String drillId, required bool wasCorrect, required int streak}) {
    final appended = [...state.recent, wasCorrect];
    final recent =
        appended.length > _recentCap ? appended.sublist(appended.length - _recentCap) : appended;
    _set(DrillStats(
      total: state.total + 1,
      correct: state.correct + (wasCorrect ? 1 : 0),
      bestStreak: streak > state.bestStreak ? streak : state.bestStreak,
      attempted: {...state.attempted, drillId},
      recent: recent,
    ));
  }

  /// Folds cloud drill stats into local. The device with more lifetime hands
  /// owns the correlated totals/recent; streaks and attempted drills union so
  /// nothing regresses.
  void mergeFromCloud(
      ({int total, int correct, int bestStreak, Set<String> attempted, List<bool> recent}) cloud) {
    if (cloud.total <= 0 && cloud.attempted.isEmpty) return;
    final ahead = cloud.total > state.total;
    _set(DrillStats(
      total: ahead ? cloud.total : state.total,
      correct: ahead ? cloud.correct : state.correct,
      recent: ahead ? cloud.recent : state.recent,
      bestStreak: cloud.bestStreak > state.bestStreak ? cloud.bestStreak : state.bestStreak,
      attempted: {...state.attempted, ...cloud.attempted},
    ));
  }

  void reset() => _set(const DrillStats());

  void _set(DrillStats next) {
    state = next;
    ref.read(localStoreProvider).saveDrillStats(
        next.total, next.correct, next.bestStreak, next.attempted, next.recent);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(syncQueueProvider.notifier).drill(uid,
          total: next.total,
          correct: next.correct,
          bestStreak: next.bestStreak,
          attempted: next.attempted,
          recent: next.recent);
    }
  }
}

final drillStatsProvider =
    NotifierProvider<DrillStatsController, DrillStats>(DrillStatsController.new);
