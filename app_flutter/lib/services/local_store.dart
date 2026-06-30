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
  static const _cardBackKey = 'bj101-card-back';
  static const _chipStyleKey = 'bj101-chip-style';
  static const _ownedKey = 'bj101-owned-products';

  final SharedPreferences _prefs;
  LocalStore(this._prefs);

  // --- appearance (selected skin id) ---

  String? loadAppearanceId() => _prefs.getString(_appearanceKey);

  Future<void> saveAppearanceId(String id) => _prefs.setString(_appearanceKey, id);

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
