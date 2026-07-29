import 'package:flutter_test/flutter_test.dart';

import 'package:blackjack101/engine/engine.dart' show HandResult;
import 'package:blackjack101/engine/stats.dart';
import 'package:blackjack101/engine/strategy.dart';

const _now = 10000000;

HandRecord _hand(int ts) => HandRecord(
      id: 'h$ts',
      timestamp: ts,
      playerAction: Action.stand,
      optimalAction: Action.stand,
      wasCorrect: true,
      playerTotal: 20,
      soft: false,
      dealerUpcard: '6',
      handType: HandType.hard,
      explanation: '',
      outcome: HandResult.win,
    );

Session _sess({
  required String id,
  required String? deviceId,
  required int start,
  int? end,
  List<HandRecord> hands = const [],
}) =>
    Session(
      id: id,
      startTime: start,
      endTime: end,
      hands: hands,
      ruleSetId: 'vegas-strip',
      deviceId: deviceId,
    );

void main() {
  group('reconcileSessions', () {
    test('keeps this device\'s recent live session as current', () {
      final s = _sess(id: 'a', deviceId: 'me', start: _now - 1000, hands: [_hand(_now - 500)]);
      final r = reconcileSessions([s], 'me', now: _now);
      expect(r.current?.id, 'a');
      expect(r.sessions, isEmpty);
      expect(r.finalized, isEmpty);
    });

    test('finalizes a foreign device\'s live session (end = its last hand)', () {
      final s = _sess(id: 'b', deviceId: 'other', start: _now - 1000, hands: [_hand(_now - 500)]);
      final r = reconcileSessions([s], 'me', now: _now);
      expect(r.current, isNull);
      expect(r.sessions.single.id, 'b');
      expect(r.sessions.single.endTime, _now - 500);
      expect(r.finalized.single.id, 'b');
    });

    test('finalizes my own stale live session', () {
      final s = _sess(
          id: 'c',
          deviceId: 'me',
          start: _now - kSittingIdleMs - 5000,
          hands: [_hand(_now - kSittingIdleMs - 1000)]);
      final r = reconcileSessions([s], 'me', now: _now);
      expect(r.current, isNull);
      expect(r.finalized.single.id, 'c');
    });

    test('drops an empty abandoned live session', () {
      final s = _sess(id: 'd', deviceId: 'other', start: _now - 1000);
      final r = reconcileSessions([s], 'me', now: _now);
      expect(r.sessions, isEmpty);
      expect(r.current, isNull);
      expect(r.finalized, isEmpty);
    });

    test('never drops extra live sessions (the old loadFromCloud bug)', () {
      final mine = _sess(id: 'm', deviceId: 'me', start: _now - 500, hands: [_hand(_now - 200)]);
      final o1 = _sess(id: 'o1', deviceId: 'x', start: _now - 2000, hands: [_hand(_now - 1500)]);
      final o2 = _sess(id: 'o2', deviceId: 'y', start: _now - 3000, hands: [_hand(_now - 2500)]);
      final r = reconcileSessions([mine, o1, o2], 'me', now: _now);
      expect(r.current?.id, 'm');
      expect(r.sessions.map((s) => s.id).toSet(), {'o1', 'o2'});
      expect(r.finalized.length, 2);
    });

    test('passes finished sessions through untouched', () {
      final f = _sess(
          id: 'f',
          deviceId: 'me',
          start: _now - 5000,
          end: _now - 4000,
          hands: [_hand(_now - 4500)]);
      final r = reconcileSessions([f], 'me', now: _now);
      expect(r.sessions.single.id, 'f');
      expect(r.current, isNull);
      expect(r.finalized, isEmpty);
    });
  });

  test('finalizeSession derives end time from the last hand', () {
    final s = _sess(
        id: 'e',
        deviceId: 'me',
        start: _now - 1000,
        hands: [_hand(_now - 800), _hand(_now - 400)]);
    final f = finalizeSession(s);
    expect(f.endTime, _now - 400);
  });

  test('finalizeSession falls back to startTime when there are no hands', () {
    final s = _sess(id: 'g', deviceId: 'me', start: _now - 1000);
    final f = finalizeSession(s);
    expect(f.endTime, _now - 1000);
  });
}
