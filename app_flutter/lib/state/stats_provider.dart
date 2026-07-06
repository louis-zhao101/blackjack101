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
    final loaded = ref.read(localStoreProvider).loadStats();
    return StatsState(sessions: loaded.sessions, currentSession: loaded.currentSession);
  }

  void startSession(int bankroll, String ruleSetId) {
    _set(state.copyWith(currentSession: createSession(bankroll, ruleSetId)));
  }

  void addHandRecord(HandRecord record) {
    final current = state.currentSession;
    if (current == null) return;
    final updated = recordHand(current, record);
    _set(state.copyWith(currentSession: updated));
    _syncSession(updated);
  }

  void finishSession(int endBankroll) {
    final current = state.currentSession;
    if (current == null) return;
    final finished = endSession(current, endBankroll);
    _set(StatsState(
      sessions: [finished, ...state.sessions].take(50).toList(),
      currentSession: null,
    ));
    _syncSession(finished);
    _maybeAskForReview(finished);
  }

  /// A well-played, profitable session is a genuine feel-good moment — a good
  /// time to (gently, once) ask for a review.
  void _maybeAskForReview(Session session) {
    final s = summarizeSession(session);
    if (s.handsPlayed >= 10 && s.correctPct >= 80 && s.profitLoss >= 0) {
      ref.read(reviewPromptProvider.notifier).maybePrompt();
    }
  }

  void clearHistory() {
    _set(const StatsState(sessions: [], currentSession: null));
  }

  void loadFromCloud(List<Session> cloudSessions) {
    Session? live;
    final finished = <Session>[];
    for (final s in cloudSessions) {
      if (s.endTime == null) {
        live ??= s;
      } else {
        finished.add(s);
      }
    }
    _set(StatsState(sessions: finished, currentSession: live));
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
