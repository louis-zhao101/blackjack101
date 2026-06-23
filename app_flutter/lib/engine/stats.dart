import 'dart:math';
import 'engine.dart' show HandResult;
import 'strategy.dart';

String _uuid([Random? rng]) {
  final r = rng ?? Random();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String handResultId(HandResult r) {
  switch (r) {
    case HandResult.win:
      return 'win';
    case HandResult.lose:
      return 'lose';
    case HandResult.push:
      return 'push';
    case HandResult.blackjack:
      return 'blackjack';
    case HandResult.surrender:
      return 'surrender';
  }
}

HandResult handResultFromId(String id) =>
    HandResult.values.firstWhere((r) => handResultId(r) == id);

class HandRecord {
  final String id;
  final int timestamp;
  final Action playerAction;
  final Action optimalAction;
  final bool wasCorrect;
  final int playerTotal;
  final bool soft;
  final String dealerUpcard;
  final HandType handType;
  final String explanation;
  final int betAmount;
  final HandResult outcome;
  final int payout;

  const HandRecord({
    required this.id,
    required this.timestamp,
    required this.playerAction,
    required this.optimalAction,
    required this.wasCorrect,
    required this.playerTotal,
    required this.soft,
    required this.dealerUpcard,
    required this.handType,
    required this.explanation,
    required this.betAmount,
    required this.outcome,
    required this.payout,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'playerAction': actionCode(playerAction),
        'optimalAction': actionCode(optimalAction),
        'wasCorrect': wasCorrect,
        'playerTotal': playerTotal,
        'soft': soft,
        'dealerUpcard': dealerUpcard,
        'handType': handType.name,
        'explanation': explanation,
        'betAmount': betAmount,
        'outcome': handResultId(outcome),
        'payout': payout,
      };

  factory HandRecord.fromJson(Map<String, dynamic> j) => HandRecord(
        id: j['id'] as String,
        timestamp: (j['timestamp'] as num).toInt(),
        playerAction: actionFromCode(j['playerAction'] as String),
        optimalAction: actionFromCode(j['optimalAction'] as String),
        wasCorrect: j['wasCorrect'] as bool,
        playerTotal: (j['playerTotal'] as num).toInt(),
        soft: j['soft'] as bool,
        dealerUpcard: j['dealerUpcard'] as String,
        handType: HandType.values.byName(j['handType'] as String),
        explanation: j['explanation'] as String? ?? '',
        betAmount: (j['betAmount'] as num).toInt(),
        outcome: handResultFromId(j['outcome'] as String),
        payout: (j['payout'] as num).toInt(),
      );
}

class Session {
  final String id;
  final int startTime;
  final int? endTime;
  final int startBankroll;
  final int? endBankroll;
  final List<HandRecord> hands;
  final String ruleSetId;

  const Session({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.startBankroll,
    required this.endBankroll,
    required this.hands,
    required this.ruleSetId,
  });

  Session copyWith({
    int? endTime,
    bool clearEndTime = false,
    int? endBankroll,
    List<HandRecord>? hands,
  }) =>
      Session(
        id: id,
        startTime: startTime,
        endTime: clearEndTime ? null : (endTime ?? this.endTime),
        startBankroll: startBankroll,
        endBankroll: endBankroll ?? this.endBankroll,
        hands: hands ?? this.hands,
        ruleSetId: ruleSetId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime,
        'endTime': endTime,
        'startBankroll': startBankroll,
        'endBankroll': endBankroll,
        'hands': hands.map((h) => h.toJson()).toList(),
        'ruleSetId': ruleSetId,
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        startTime: (j['startTime'] as num).toInt(),
        endTime: j['endTime'] == null ? null : (j['endTime'] as num).toInt(),
        startBankroll: (j['startBankroll'] as num).toInt(),
        endBankroll: j['endBankroll'] == null ? null : (j['endBankroll'] as num).toInt(),
        hands: ((j['hands'] as List?) ?? [])
            .map((h) => HandRecord.fromJson(Map<String, dynamic>.from(h as Map)))
            .toList(),
        ruleSetId: j['ruleSetId'] as String,
      );
}

class SessionSummary {
  final String id;
  final int date;
  final int handsPlayed;
  final int correctCount;
  final double correctPct;
  final int profitLoss;
  final String ruleSetId;
  final int longestStreak;
  final bool isLive;

  const SessionSummary({
    required this.id,
    required this.date,
    required this.handsPlayed,
    required this.correctCount,
    required this.correctPct,
    required this.profitLoss,
    required this.ruleSetId,
    required this.longestStreak,
    required this.isLive,
  });
}

class MistakeSummary {
  final int playerTotal;
  final bool soft;
  final String dealerUpcard;
  final HandType handType;
  final Action playerAction;
  final Action optimalAction;
  int count;
  final String explanation;

  MistakeSummary({
    required this.playerTotal,
    required this.soft,
    required this.dealerUpcard,
    required this.handType,
    required this.playerAction,
    required this.optimalAction,
    required this.count,
    required this.explanation,
  });
}

class MistakeCategory {
  final String label;
  final int count;
  const MistakeCategory(this.label, this.count);
}

Session createSession(int startBankroll, String ruleSetId, {int? now, Random? rng}) {
  return Session(
    id: _uuid(rng),
    startTime: now ?? DateTime.now().millisecondsSinceEpoch,
    endTime: null,
    startBankroll: startBankroll,
    endBankroll: null,
    hands: const [],
    ruleSetId: ruleSetId,
  );
}

Session recordHand(Session session, HandRecord record, {int? now, Random? rng}) {
  final hand = HandRecord(
    id: _uuid(rng),
    timestamp: now ?? DateTime.now().millisecondsSinceEpoch,
    playerAction: record.playerAction,
    optimalAction: record.optimalAction,
    wasCorrect: record.wasCorrect,
    playerTotal: record.playerTotal,
    soft: record.soft,
    dealerUpcard: record.dealerUpcard,
    handType: record.handType,
    explanation: record.explanation,
    betAmount: record.betAmount,
    outcome: record.outcome,
    payout: record.payout,
  );
  return session.copyWith(hands: [...session.hands, hand]);
}

Session endSession(Session session, int endBankroll, {int? now}) {
  return session.copyWith(
      endTime: now ?? DateTime.now().millisecondsSinceEpoch, endBankroll: endBankroll);
}

int computeLongestStreak(List<HandRecord> hands) {
  int maxStreak = 0;
  int current = 0;
  for (final h in hands) {
    if (h.wasCorrect) {
      current++;
      if (current > maxStreak) maxStreak = current;
    } else {
      current = 0;
    }
  }
  return maxStreak;
}

SessionSummary summarizeSession(Session session) {
  final hands = session.hands;
  final correctCount = hands.where((h) => h.wasCorrect).length;
  final correctPct = hands.isNotEmpty ? (correctCount / hands.length) * 100 : 0.0;
  final endBankroll = session.endBankroll ?? session.startBankroll;

  return SessionSummary(
    id: session.id,
    date: session.startTime,
    handsPlayed: hands.length,
    correctCount: correctCount,
    correctPct: (correctPct * 10).round() / 10,
    profitLoss: endBankroll - session.startBankroll,
    ruleSetId: session.ruleSetId,
    longestStreak: computeLongestStreak(hands),
    isLive: session.endTime == null,
  );
}

String _mistakeCategoryLabel(Action playerAction, Action optimalAction) {
  if (optimalAction == Action.double) return 'Missed Double';
  if (optimalAction == Action.split) return 'Missed Split';
  if (optimalAction == Action.hit && playerAction == Action.stand) {
    return 'Stood when should Hit';
  }
  if (optimalAction == Action.stand && playerAction == Action.hit) {
    return 'Hit when should Stand';
  }
  if (optimalAction == Action.surrender) return 'Missed Surrender';
  const names = {
    Action.hit: 'Hit',
    Action.stand: 'Stand',
    Action.double: 'Double',
    Action.split: 'Split',
    Action.surrender: 'Surrender',
  };
  return '${names[playerAction]} → ${names[optimalAction]}';
}

List<MistakeCategory> getMistakeCategories(List<Session> sessions) {
  final allHands = sessions.expand((s) => s.hands);
  final mistakes =
      allHands.where((h) => !h.wasCorrect && h.playerAction != h.optimalAction);
  final counts = <String, int>{};
  for (final m in mistakes) {
    final label = _mistakeCategoryLabel(m.playerAction, m.optimalAction);
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final list = counts.entries.map((e) => MistakeCategory(e.key, e.value)).toList();
  list.sort((a, b) => b.count - a.count);
  return list;
}

List<MistakeSummary> getCommonMistakes(List<Session> sessions, {int topN = 10}) {
  final allHands = sessions.expand((s) => s.hands);
  final mistakes =
      allHands.where((h) => !h.wasCorrect && h.playerAction != h.optimalAction);

  final counts = <String, MistakeSummary>{};
  for (final m in mistakes) {
    final key =
        '${m.handType.name}-${m.playerTotal}-${m.soft}-${m.dealerUpcard}-${actionCode(m.playerAction)}-${actionCode(m.optimalAction)}';
    final existing = counts[key];
    if (existing != null) {
      existing.count++;
    } else {
      counts[key] = MistakeSummary(
        playerTotal: m.playerTotal,
        soft: m.soft,
        dealerUpcard: m.dealerUpcard,
        handType: m.handType,
        playerAction: m.playerAction,
        optimalAction: m.optimalAction,
        count: 1,
        explanation: m.explanation,
      );
    }
  }

  final list = counts.values.toList();
  list.sort((a, b) => b.count - a.count);
  return list.take(topN).toList();
}
