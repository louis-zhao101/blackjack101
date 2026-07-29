// Achievement catalog and evaluation — pure logic over a snapshot of the
// player's lifetime stats. The UI maps ids to badges; nothing here touches
// Flutter, storage, or providers.

class AchievementInput {
  final int totalHands;
  final int bestCorrectStreak;
  final int worstWrongStreak;
  final int lessonsComplete;
  final int totalLessons;
  final bool gotBlackjack;
  final bool flawlessSession;
  final int cellsCovered;
  final int totalCells;
  final int drillHands;
  final int drillBestStreak;
  final int drillsTried;
  final int totalDrills;

  /// Correct answers within, and size of, the rolling last-100-hands window —
  /// the self-healing accuracy metric behind "Straight A's".
  final int drillRecentCorrect;
  final int drillRecentCount;

  /// One-off "moment" flags: lost a hand played perfectly, won a hand misplayed,
  /// and whether Pro is unlocked.
  final bool badBeat;
  final bool luckyWin;
  final bool lostToDealerBlackjack;
  final bool isPro;

  /// Hands in the longest single session, and longest run of consecutive wins
  /// by outcome.
  final int longestSession;
  final int bestWinStreak;

  const AchievementInput({
    required this.totalHands,
    required this.bestCorrectStreak,
    required this.worstWrongStreak,
    required this.lessonsComplete,
    required this.totalLessons,
    required this.gotBlackjack,
    required this.flawlessSession,
    required this.cellsCovered,
    required this.totalCells,
    required this.drillHands,
    required this.drillBestStreak,
    required this.drillsTried,
    required this.totalDrills,
    required this.drillRecentCorrect,
    required this.drillRecentCount,
    required this.badBeat,
    required this.luckyWin,
    required this.lostToDealerBlackjack,
    required this.isPro,
    required this.longestSession,
    required this.bestWinStreak,
  });
}

class Achievement {
  final String id;
  final String emoji;
  final String title;
  final String description;

  /// (current, target) for the given snapshot. Unlocked once current >= target.
  final (int, int) Function(AchievementInput input) progress;

  const Achievement({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.progress,
  });
}

class AchievementStatus {
  final Achievement achievement;
  final int current;
  final int target;
  const AchievementStatus(this.achievement, this.current, this.target);

  bool get unlocked => current >= target;
  int get shownCurrent => current > target ? target : current;
  double get fraction => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

/// Ordered so the badge grid reads streaks → milestones → outcomes → chart → misc.
final List<Achievement> kAchievements = [
  Achievement(
    id: 'hot_hand',
    emoji: '🔥',
    title: 'Hot Hand',
    description: 'Make 5 correct decisions in a row.',
    progress: (i) => (i.bestCorrectStreak, 5),
  ),
  Achievement(
    id: 'on_fire',
    emoji: '🚀',
    title: 'On Fire',
    description: 'Make 10 correct decisions in a row.',
    progress: (i) => (i.bestCorrectStreak, 10),
  ),
  Achievement(
    id: 'unstoppable',
    emoji: '⚡',
    title: 'Unstoppable',
    description: 'Make 25 correct decisions in a row.',
    progress: (i) => (i.bestCorrectStreak, 25),
  ),
  Achievement(
    id: 'flawless',
    emoji: '✨',
    title: 'Flawless',
    description: 'Finish a session of 10+ hands with 100% correct play.',
    progress: (i) => (i.flawlessSession ? 1 : 0, 1),
  ),
  Achievement(
    id: 'rough_night',
    emoji: '💀',
    title: 'Rough Night',
    description: 'Miss the optimal play 10 times in a row. It happens.',
    progress: (i) => (i.worstWrongStreak, 10),
  ),
  Achievement(
    id: 'getting_started',
    emoji: '🃏',
    title: 'Getting Started',
    description: 'Play 100 hands.',
    progress: (i) => (i.totalHands, 100),
  ),
  Achievement(
    id: 'regular',
    emoji: '🎯',
    title: 'Regular',
    description: 'Play 1,000 hands.',
    progress: (i) => (i.totalHands, 1000),
  ),
  Achievement(
    id: 'card_shark',
    emoji: '🦈',
    title: 'Card Shark',
    description: 'Play 10,000 hands.',
    progress: (i) => (i.totalHands, 10000),
  ),
  Achievement(
    id: 'marathon',
    emoji: '🏃',
    title: 'Marathon',
    description: 'Play a single session of 50+ hands.',
    progress: (i) => (i.longestSession, 50),
  ),
  Achievement(
    id: 'natural',
    emoji: '♠️',
    title: 'Natural',
    description: 'Get dealt a blackjack.',
    progress: (i) => (i.gotBlackjack ? 1 : 0, 1),
  ),
  Achievement(
    id: 'house_always_wins',
    emoji: '🎩',
    title: 'House Always Wins',
    description: "Lose to the dealer's blackjack.",
    progress: (i) => (i.lostToDealerBlackjack ? 1 : 0, 1),
  ),
  Achievement(
    id: 'ice_cold',
    emoji: '🧊',
    title: 'Ice Cold',
    description: 'Win 5 hands in a row.',
    progress: (i) => (i.bestWinStreak, 5),
  ),
  Achievement(
    id: 'bad_beat',
    emoji: '😤',
    title: 'Bad Beat',
    description: 'Play a hand perfectly and still lose it. Rough.',
    progress: (i) => (i.badBeat ? 1 : 0, 1),
  ),
  Achievement(
    id: 'dumb_luck',
    emoji: '🍀',
    title: 'Dumb Luck',
    description: 'Misplay a hand and win it anyway.',
    progress: (i) => (i.luckyWin ? 1 : 0, 1),
  ),
  Achievement(
    id: 'chart_explorer',
    emoji: '🗺️',
    title: 'Chart Explorer',
    description: 'Face 100 different strategy-chart hands.',
    progress: (i) => (i.cellsCovered, 100),
  ),
  Achievement(
    id: 'chart_master',
    emoji: '📖',
    title: 'Chart Master',
    description: 'Play every hand in the strategy chart at least once.',
    progress: (i) => (i.cellsCovered, i.totalCells),
  ),
  Achievement(
    id: 'scholar',
    emoji: '🎓',
    title: 'Scholar',
    description: 'Complete every Learn lesson.',
    progress: (i) => (i.lessonsComplete, i.totalLessons),
  ),
  Achievement(
    id: 'sharpshooter',
    emoji: '🎯',
    title: 'Sharpshooter',
    description: 'Nail 10 Test Yourself hands in a row.',
    progress: (i) => (i.drillBestStreak, 10),
  ),
  Achievement(
    id: 'locked_in',
    emoji: '🧠',
    title: 'Locked In',
    description: 'Nail 20 Test Yourself hands in a row.',
    progress: (i) => (i.drillBestStreak, 20),
  ),
  Achievement(
    id: 'practice_makes_perfect',
    emoji: '🏋️',
    title: 'Practice Makes Perfect',
    description: 'Answer 250 Test Yourself hands.',
    progress: (i) => (i.drillHands, 250),
  ),
  Achievement(
    id: 'well_rounded',
    emoji: '🧭',
    title: 'Well Rounded',
    description: 'Try every Test Yourself drill.',
    progress: (i) => (i.drillsTried, i.totalDrills),
  ),
  Achievement(
    id: 'straight_as',
    emoji: '💯',
    title: "Straight A's",
    description: 'Get 90 of your last 100 Test Yourself hands right.',
    // Progress shows correct answers in the rolling window toward 90. Held one
    // short of the target until a full 100-hand window exists, so it can't
    // unlock early on a small, lucky sample.
    progress: (i) => (
      i.drillRecentCount >= 100 ? i.drillRecentCorrect : i.drillRecentCorrect.clamp(0, 89),
      90,
    ),
  ),
  Achievement(
    id: 'going_pro',
    emoji: '👑',
    title: 'Going Pro',
    description: 'Unlock Blackjack 101 Pro.',
    progress: (i) => (i.isPro ? 1 : 0, 1),
  ),
];

List<AchievementStatus> evaluateAchievements(AchievementInput input) =>
    kAchievements.map((a) {
      final (current, target) = a.progress(input);
      return AchievementStatus(a, current, target);
    }).toList();
