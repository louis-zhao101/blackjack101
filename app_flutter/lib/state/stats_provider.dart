import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/stats.dart';
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
      ref.read(firestoreSyncProvider).upsertSession(uid, session);
    }
  }
}

final statsProvider = NotifierProvider<StatsController, StatsState>(StatsController.new);
