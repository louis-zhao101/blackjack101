import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/stats.dart';
import '../engine/variants.dart';

/// Local persistence mirroring the web app's Zustand `persist` keys
/// (`bj101-stats`, `bj101-settings`). Backed by SharedPreferences.
class LocalStore {
  static const _statsKey = 'bj101-stats';
  static const _settingsKey = 'bj101-settings';

  final SharedPreferences _prefs;
  LocalStore(this._prefs);

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

  ({RuleSet ruleSet, int startingBankroll})? loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (
      ruleSet: RuleSet.fromJson(Map<String, dynamic>.from(map['ruleSet'] as Map)),
      startingBankroll: (map['startingBankroll'] as num).toInt(),
    );
  }

  Future<void> saveSettings(RuleSet ruleSet, int startingBankroll) {
    return _prefs.setString(
      _settingsKey,
      jsonEncode({'ruleSet': ruleSet.toJson(), 'startingBankroll': startingBankroll}),
    );
  }
}
