import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/stats.dart';
import '../engine/strategy.dart' show Difficulty, difficultyFromId, difficultyId;
import '../engine/variants.dart';

/// Local persistence mirroring the web app's Zustand `persist` keys
/// (`bj101-stats`, `bj101-settings`). Backed by SharedPreferences.
class LocalStore {
  static const _statsKey = 'bj101-stats';
  static const _settingsKey = 'bj101-settings';
  static const _appearanceKey = 'bj101-appearance';
  static const _learnKey = 'bj101-learn';
  static const _strategyCellsKey = 'bj101-strategy-cells';
  static const _cardBackKey = 'bj101-card-back';
  static const _chipStyleKey = 'bj101-chip-style';
  static const _ownedKey = 'bj101-owned-products';
  static const _achievementsKey = 'bj101-achievements';
  static const _drillStatsKey = 'bj101-drill-stats';
  static const _onboardedKey = 'bj101-onboarded';
  static const _reviewRequestedKey = 'bj101-review-requested';

  final SharedPreferences _prefs;
  LocalStore(this._prefs);

  // --- first-run onboarding ---

  bool loadOnboarded() => _prefs.getBool(_onboardedKey) ?? false;

  Future<void> saveOnboarded(bool value) => _prefs.setBool(_onboardedKey, value);

  // --- app-store review nudge (whether we've asked in-app already) ---

  bool loadReviewRequested() => _prefs.getBool(_reviewRequestedKey) ?? false;

  Future<void> saveReviewRequested(bool value) =>
      _prefs.setBool(_reviewRequestedKey, value);

  // --- appearance (selected skin id) ---

  String? loadAppearanceId() => _prefs.getString(_appearanceKey);

  Future<void> saveAppearanceId(String id) => _prefs.setString(_appearanceKey, id);

  // --- learn progress (completed lesson ids) ---

  Set<String> loadLearnProgress() => _prefs.getStringList(_learnKey)?.toSet() ?? <String>{};

  Future<void> saveLearnProgress(Set<String> ids) =>
      _prefs.setStringList(_learnKey, ids.toList());

  // --- achievements (unlocked ids) ---

  Set<String> loadAchievementIds() =>
      _prefs.getStringList(_achievementsKey)?.toSet() ?? <String>{};

  Future<void> saveAchievementIds(Set<String> ids) =>
      _prefs.setStringList(_achievementsKey, ids.toList());

  // --- Test Yourself drill stats (lifetime totals for achievements) ---

  ({int total, int correct, int bestStreak, Set<String> attempted, List<bool> recent})
      loadDrillStats() {
    final raw = _prefs.getString(_drillStatsKey);
    if (raw == null) {
      return (total: 0, correct: 0, bestStreak: 0, attempted: <String>{}, recent: <bool>[]);
    }
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final recentStr = (m['recent'] as String?) ?? '';
    return (
      total: (m['total'] as num?)?.toInt() ?? 0,
      correct: (m['correct'] as num?)?.toInt() ?? 0,
      bestStreak: (m['bestStreak'] as num?)?.toInt() ?? 0,
      attempted: ((m['attempted'] as List?) ?? const []).map((e) => e as String).toSet(),
      recent: recentStr.split('').map((c) => c == '1').toList(),
    );
  }

  Future<void> saveDrillStats(
      int total, int correct, int bestStreak, Set<String> attempted, List<bool> recent) {
    return _prefs.setString(
      _drillStatsKey,
      jsonEncode({
        'total': total,
        'correct': correct,
        'bestStreak': bestStreak,
        'attempted': attempted.toList(),
        'recent': recent.map((b) => b ? '1' : '0').join(),
      }),
    );
  }

  // --- per-cell strategy accuracy (cellKey -> [correct, total]) ---

  Map<String, (int, int)> loadStrategyCellStats() {
    final raw = _prefs.getString(_strategyCellsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) {
      final list = (v as List).cast<num>();
      return MapEntry(k, (list[0].toInt(), list[1].toInt()));
    });
  }

  Future<void> saveStrategyCellStats(Map<String, (int, int)> stats) {
    final encoded =
        jsonEncode(stats.map((k, v) => MapEntry(k, [v.$1, v.$2])));
    return _prefs.setString(_strategyCellsKey, encoded);
  }

  // --- cosmetics (selected card back / chip style) ---

  String? loadCardBackId() => _prefs.getString(_cardBackKey);

  Future<void> saveCardBackId(String id) => _prefs.setString(_cardBackKey, id);

  String? loadChipStyleId() => _prefs.getString(_chipStyleKey);

  Future<void> saveChipStyleId(String id) => _prefs.setString(_chipStyleKey, id);

  // --- store entitlements (owned product ids) ---

  Set<String> loadOwnedProducts() => _prefs.getStringList(_ownedKey)?.toSet() ?? <String>{};

  Future<void> saveOwnedProducts(Set<String> ids) =>
      _prefs.setStringList(_ownedKey, ids.toList());

  // --- stats ---

  ({List<Session> sessions, Session? currentSession}) loadStats() {
    final raw = _prefs.getString(_statsKey);
    if (raw == null) return (sessions: const [], currentSession: null);
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final sessions = ((map['sessions'] as List?) ?? [])
        .map((s) => Session.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList();
    final cur = map['currentSession'];
    return (
      sessions: sessions,
      currentSession:
          cur == null ? null : Session.fromJson(Map<String, dynamic>.from(cur as Map)),
    );
  }

  Future<void> saveStats(List<Session> sessions, Session? currentSession) {
    return _prefs.setString(
      _statsKey,
      jsonEncode({
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'currentSession': currentSession?.toJson(),
      }),
    );
  }

  // --- settings ---

  ({
    RuleSet ruleSet,
    int startingBankroll,
    bool hapticsEnabled,
    bool soundEnabled,
    Difficulty difficulty
  })? loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (
      ruleSet: RuleSet.fromJson(Map<String, dynamic>.from(map['ruleSet'] as Map)),
      startingBankroll: (map['startingBankroll'] as num).toInt(),
      hapticsEnabled: (map['hapticsEnabled'] as bool?) ?? true,
      soundEnabled: (map['soundEnabled'] as bool?) ?? true,
      difficulty: difficultyFromId((map['difficulty'] as String?) ?? 'regular'),
    );
  }

  Future<void> saveSettings(RuleSet ruleSet, int startingBankroll, bool hapticsEnabled,
      bool soundEnabled, Difficulty difficulty) {
    return _prefs.setString(
      _settingsKey,
      jsonEncode({
        'ruleSet': ruleSet.toJson(),
        'startingBankroll': startingBankroll,
        'hapticsEnabled': hapticsEnabled,
        'soundEnabled': soundEnabled,
        'difficulty': difficultyId(difficulty),
      }),
    );
  }
}
