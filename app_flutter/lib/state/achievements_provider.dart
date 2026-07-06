import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/achievements.dart';
import '../engine/engine.dart' show HandResult;
import '../engine/stats.dart';
import '../engine/strategy.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'game_provider.dart';
import 'learn_provider.dart';
import 'stats_provider.dart';
import 'store_provider.dart';

AchievementInput _snapshot(Ref ref) {
  final stats = ref.read(statsProvider);
  final sessions = [
    ...stats.sessions,
    if (stats.currentSession != null) stats.currentSession!,
  ];
  final allHands = sessions.expand((s) => s.hands).toList();
  final lifetimePL =
      sessions.fold<int>(0, (a, s) => a + summarizeSession(s).profitLoss);
  final flawless = sessions
      .any((s) => s.hands.length >= 10 && s.hands.every((h) => h.wasCorrect));
  final gotBlackjack = allHands.any((h) => h.outcome == HandResult.blackjack);

  final covered = ref.read(strategyStatsProvider).keys.toSet();
  final canonical = allStrategyCellKeys();
  final cellsCovered = canonical.where(covered.contains).length;

  final badBeat =
      allHands.any((h) => h.wasCorrect && h.outcome == HandResult.lose);
  final luckyWin =
      allHands.any((h) => !h.wasCorrect && h.outcome == HandResult.win);
  final wentBroke = ref.read(gameProvider).game.bankroll <= 0;
  final lostToDealerBlackjack =
      allHands.any((h) => h.dealerBlackjack && h.outcome == HandResult.lose);
  final longestSession =
      sessions.fold<int>(0, (m, s) => s.hands.length > m ? s.hands.length : m);
  final bestWinStreak = computeLongestWinStreak(allHands);
  final bestHandWin =
      allHands.fold<int>(0, (m, h) => (h.payout - h.betAmount) > m ? h.payout - h.betAmount : m);

  final drill = ref.read(drillStatsProvider);

  return AchievementInput(
    totalHands: allHands.length,
    bestCorrectStreak: computeLongestStreak(allHands),
    worstWrongStreak: computeLongestWrongStreak(allHands),
    lifetimePL: lifetimePL,
    lessonsComplete: ref.read(learnProvider).length,
    totalLessons: kLearnLessonCount,
    gotBlackjack: gotBlackjack,
    flawlessSession: flawless,
    cellsCovered: cellsCovered,
    totalCells: canonical.length,
    drillHands: drill.total,
    drillBestStreak: drill.bestStreak,
    drillsTried: drill.attempted.length,
    totalDrills: kDrillCount,
    drillRecentCorrect: drill.recentCorrect,
    drillRecentCount: drill.recentCount,
    badBeat: badBeat,
    luckyWin: luckyWin,
    wentBroke: wentBroke,
    lostToDealerBlackjack: lostToDealerBlackjack,
    isPremium: ref.read(entitlementsProvider).isPremium,
    longestSession: longestSession,
    bestWinStreak: bestWinStreak,
    bestHandWin: bestHandWin,
  );
}

/// Unlocked achievement ids. Local-first (SharedPreferences), union-merged into
/// Firestore when signed in — same pattern as sessions and learn progress.
class AchievementsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.read(localStoreProvider).loadAchievementIds();

  /// Recomputes achievements from the latest stats and unlocks any newly earned.
  /// Cheap and idempotent — call it after every hand, lesson, or cloud load.
  void evaluate() {
    final earned = evaluateAchievements(_snapshot(ref))
        .where((s) => s.unlocked)
        .map((s) => s.achievement.id)
        .toSet();
    final fresh = earned.difference(state);
    if (fresh.isEmpty) return;
    state = {...state, ...fresh};
    _persist();
    final unlocked = kAchievements.where((a) => fresh.contains(a.id)).toList();
    ref.read(achievementCelebrationProvider.notifier).push(unlocked);
  }

  void mergeFromCloud(Set<String> ids) {
    final merged = {...state, ...ids};
    if (merged.length == state.length) return;
    state = merged;
    ref.read(localStoreProvider).saveAchievementIds(state);
  }

  void reset() {
    state = <String>{};
    ref.read(localStoreProvider).saveAchievementIds(state);
  }

  void _persist() {
    ref.read(localStoreProvider).saveAchievementIds(state);
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(syncQueueProvider.notifier).achievements(uid, state);
    }
  }
}

final achievementsProvider =
    NotifierProvider<AchievementsController, Set<String>>(AchievementsController.new);

/// Read-model for the badge grid: every achievement with its live progress.
/// Recomputes whenever the underlying stats change.
final achievementStatusesProvider = Provider<List<AchievementStatus>>((ref) {
  ref.watch(statsProvider);
  ref.watch(strategyStatsProvider);
  ref.watch(drillStatsProvider);
  ref.watch(learnProvider);
  ref.watch(entitlementsProvider);
  ref.watch(gameProvider);
  final earned = ref.watch(achievementsProvider);
  // Unlocking is permanent: an achievement already in the earned set stays
  // shown as complete even if the stats that earned it were later cleared. Live
  // progress still drives the not-yet-earned ones.
  return evaluateAchievements(_snapshot(ref)).map((s) {
    if (!s.unlocked && earned.contains(s.achievement.id)) {
      return AchievementStatus(s.achievement, s.target, s.target);
    }
    return s;
  }).toList();
});

/// A queue of just-unlocked achievements awaiting a celebratory toast. The app
/// shell listens, shows them, and calls [AchievementCelebration.consume].
class AchievementCelebration extends Notifier<List<Achievement>> {
  @override
  List<Achievement> build() => const [];

  void push(List<Achievement> achievements) {
    if (achievements.isEmpty) return;
    state = [...state, ...achievements];
  }

  void consume() {
    if (state.isNotEmpty) state = const [];
  }
}

final achievementCelebrationProvider =
    NotifierProvider<AchievementCelebration, List<Achievement>>(
        AchievementCelebration.new);
