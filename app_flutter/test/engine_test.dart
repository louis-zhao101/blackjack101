import 'package:flutter_test/flutter_test.dart';
import 'package:blackjack101/engine/cards.dart';
import 'package:blackjack101/engine/variants.dart';
import 'package:blackjack101/engine/engine.dart';
import 'package:blackjack101/engine/strategy.dart';
import 'package:blackjack101/engine/stats.dart';

Card card(String rank, [String suit = '♠']) => Card(rank: rank, suit: suit);

void main() {
  group('handValue', () {
    test('sums numeric cards', () {
      final v = handValue([card('7'), card('8')]);
      expect(v.total, 15);
      expect(v.soft, false);
    });
    test('counts face cards as 10', () {
      final v = handValue([card('K'), card('Q')]);
      expect(v.total, 20);
      expect(v.soft, false);
    });
    test('counts ace as 11 when safe', () {
      final v = handValue([card('A'), card('7')]);
      expect(v.total, 18);
      expect(v.soft, true);
    });
    test('demotes ace to 1 to avoid bust', () {
      final v = handValue([card('A'), card('7'), card('8')]);
      expect(v.total, 16);
      expect(v.soft, false);
    });
    test('handles two aces', () {
      final v = handValue([card('A'), card('A')]);
      expect(v.total, 12);
      expect(v.soft, true);
    });
    test('handles blackjack', () {
      final v = handValue([card('A'), card('K')]);
      expect(v.total, 21);
      expect(v.soft, true);
    });
    test('ignores faceDown cards', () {
      final hidden = Card(rank: 'K', suit: '♠', faceDown: true);
      final v = handValue([card('7'), hidden]);
      expect(v.total, 7);
      expect(v.soft, false);
    });
    test('busted hand', () {
      final v = handValue([card('10'), card('K'), card('5')]);
      expect(v.total, 25);
      expect(v.soft, false);
    });
  });

  group('isBlackjack / isBust', () {
    test('detects A+10', () => expect(isBlackjack([card('A'), card('10')]), true));
    test('rejects 21 in 3 cards',
        () => expect(isBlackjack([card('7'), card('7'), card('7')]), false));
    test('rejects 20', () => expect(isBlackjack([card('K'), card('Q')]), false));
    test('bust >21', () => expect(isBust([card('10'), card('K'), card('5')]), true));
    test('21 not bust', () => expect(isBust([card('A'), card('K')]), false));
  });

  group('deck', () {
    test('createDeck sizes', () {
      expect(createDeck(1).length, 52);
      expect(createDeck(6).length, 312);
    });
    test('shuffle preserves size and does not mutate', () {
      final deck = createDeck(1);
      final original = List<Card>.from(deck);
      final shuffled = shuffle(deck);
      expect(shuffled.length, 52);
      expect(deck.map((c) => c.toString()).toList(),
          original.map((c) => c.toString()).toList());
    });
    test('dealCard removes card', () {
      final deck = createDeck(1);
      expect(dealCard(deck).remaining.length, 51);
    });
    test('dealCard faceDown flag', () {
      final deck = createDeck(1);
      expect(dealCard(deck, true).card.faceDown, true);
      expect(dealCard(deck, false).card.faceDown, false);
    });
    test('dealCard throws on empty', () {
      expect(() => dealCard([]), throwsStateError);
    });
  });

  group('engine state machine', () {
    test('starts in betting', () {
      final s = createInitialState();
      expect(s.phase, GamePhase.betting);
      expect(s.bankroll, 1000);
      expect(s.pendingBet, 0);
    });
    test('setBet / addToBet / clearBet', () {
      expect(setBet(createInitialState(), 50).pendingBet, 50);
      var s = createInitialState();
      s = addToBet(s, 25);
      s = addToBet(s, 25);
      expect(s.pendingBet, 50);
      expect(clearBet(setBet(createInitialState(), 100)).pendingBet, 0);
    });
    test('bet cannot exceed bankroll', () {
      expect(setBet(createInitialState(bankroll: 100), 200).pendingBet, 0);
    });
    test('does not deal without a bet', () {
      expect(dealHand(createInitialState()).phase, GamePhase.betting);
    });

    GameState getPlayerTurnState() {
      var s = setBet(createInitialState(), 50);
      for (var i = 0; i < 50; i++) {
        final dealt = dealHand(s);
        if (dealt.phase == GamePhase.playerTurn) return dealt;
        s = setBet(newHand(dealt), 50);
      }
      throw StateError('Could not reach playerTurn');
    }

    test('deal yields playerTurn or complete', () {
      final s = dealHand(setBet(createInitialState(), 50));
      expect([GamePhase.playerTurn, GamePhase.complete].contains(s.phase), true);
    });
    test('deal deals 2+2 with hole card down', () {
      final s = getPlayerTurnState();
      expect(s.playerHands[0].cards.length, 2);
      expect(s.dealerCards.length, 2);
      expect(s.dealerCards[1].faceDown, true);
    });
    test('deal deducts bet', () {
      final s = dealHand(setBet(createInitialState(bankroll: 1000), 50));
      expect(s.bankroll <= 1000, true);
    });
    test('stand completes hand', () {
      expect(stand(getPlayerTurnState()).phase, GamePhase.complete);
    });
    test('canDouble true on 2-card hand', () {
      expect(canDouble(getPlayerTurnState()), true);
    });
    test('canSurrender false by default', () {
      expect(canSurrender(getPlayerTurnState()), false);
    });
    test('newHand resets after complete', () {
      var s = dealHand(setBet(createInitialState(), 50));
      if (s.phase == GamePhase.playerTurn) s = stand(s);
      expect(s.phase, GamePhase.complete);
      final next = newHand(s);
      expect(next.phase, GamePhase.betting);
      expect(next.playerHands.length, 0);
      expect(next.dealerCards.length, 0);
    });
  });

  group('strategy — hard totals', () {
    final rules = vegasStrip;
    final lateRules = vegasStrip.copyWith(surrender: Surrender.late);
    test('stands hard 17 vs 7',
        () => expect(getOptimalAction([card('10'), card('7')], card('7'), rules).action, Action.stand));
    test('hits hard 16 vs A (no surrender)',
        () => expect(getOptimalAction([card('10'), card('6')], card('A'), rules).action, Action.hit));
    test('hits hard 12 vs 2',
        () => expect(getOptimalAction([card('10'), card('2')], card('2'), rules).action, Action.hit));
    test('stands hard 13 vs 5',
        () => expect(getOptimalAction([card('10'), card('3')], card('5'), rules).action, Action.stand));
    test('doubles hard 11 vs 6',
        () => expect(getOptimalAction([card('6'), card('5')], card('6'), rules).action, Action.double));
    test('doubles hard 10 vs 9',
        () => expect(getOptimalAction([card('6'), card('4')], card('9'), rules).action, Action.double));
    test('hits hard 9 vs 2',
        () => expect(getOptimalAction([card('5'), card('4')], card('2'), rules).action, Action.hit));
    test('surrenders hard 16 vs 9 (late)',
        () => expect(getOptimalAction([card('9'), card('7')], card('9'), lateRules).action, Action.surrender));
  });

  group('strategy — soft totals', () {
    final rules = vegasStrip;
    test('stands soft 18 vs 7',
        () => expect(getOptimalAction([card('A'), card('7')], card('7'), rules).action, Action.stand));
    test('hits soft 18 vs 9',
        () => expect(getOptimalAction([card('A'), card('7')], card('9'), rules).action, Action.hit));
    test('doubles soft 17 vs 3',
        () => expect(getOptimalAction([card('A'), card('6')], card('3'), rules).action, Action.double));
    test('stands soft 19',
        () => expect(getOptimalAction([card('A'), card('8')], card('6'), rules).action, Action.stand));
    test('hits soft 13 vs 2',
        () => expect(getOptimalAction([card('A'), card('2')], card('2'), rules).action, Action.hit));
  });

  group('strategy — pairs', () {
    final rules = vegasStrip;
    test('splits aces',
        () => expect(getOptimalAction([card('A'), card('A')], card('6'), rules).action, Action.split));
    test('splits 8s',
        () => expect(getOptimalAction([card('8'), card('8')], card('A'), rules).action, Action.split));
    test('never splits 10s',
        () => expect(getOptimalAction([card('10'), card('10')], card('5'), rules).action, Action.stand));
    test('splits 9s vs 9',
        () => expect(getOptimalAction([card('9'), card('9')], card('9'), rules).action, Action.split));
    test('stands 9s vs 7',
        () => expect(getOptimalAction([card('9'), card('9')], card('7'), rules).action, Action.stand));
    test('face cards as 10-pair',
        () => expect(getOptimalAction([card('K'), card('Q')], card('5'), rules).action, Action.stand));
  });

  group('strategy — surrender fallback + 21', () {
    final rules = vegasStrip;
    final lateRules = vegasStrip.copyWith(surrender: Surrender.late);
    test('surrender when late enabled',
        () => expect(getOptimalAction([card('10'), card('6')], card('A'), lateRules).action, Action.surrender));
    test('falls back to hit (16 vs A)',
        () => expect(getOptimalAction([card('10'), card('6')], card('A'), rules).action, Action.hit));
    test('falls back to stand (17 vs A)',
        () => expect(getOptimalAction([card('10'), card('7')], card('A'), rules).action, Action.stand));
    test('soft 21 vs A stands',
        () => expect(getOptimalAction([card('A'), card('7'), card('3')], card('A'), rules).action, Action.stand));
    test('hard 21 vs A stands',
        () => expect(getOptimalAction([card('7'), card('7'), card('7')], card('A'), rules).action, Action.stand));
    test('soft 20 vs A stands',
        () => expect(getOptimalAction([card('A'), card('9')], card('A'), rules).action, Action.stand));
    test('non-empty explanation', () {
      expect(getOptimalAction([card('8'), card('8')], card('6'), rules).explanation.length > 10, true);
    });
  });

  group('stats', () {
    HandRecord mk(Action player, Action optimal, {bool correct = false}) => HandRecord(
          id: 'x',
          timestamp: 0,
          playerAction: player,
          optimalAction: optimal,
          wasCorrect: correct,
          playerTotal: 16,
          soft: false,
          dealerUpcard: '10',
          handType: HandType.hard,
          explanation: 'e',
          betAmount: 10,
          outcome: HandResult.lose,
          payout: 0,
        );

    Session sessionWith(List<HandRecord> hands) => Session(
          id: 's',
          startTime: 0,
          endTime: 1,
          startBankroll: 1000,
          endBankroll: 1100,
          hands: hands,
          ruleSetId: 'vegas-strip',
        );

    test('longest streak', () {
      final hands = [
        mk(Action.hit, Action.hit, correct: true),
        mk(Action.hit, Action.hit, correct: true),
        mk(Action.stand, Action.hit, correct: false),
        mk(Action.hit, Action.hit, correct: true),
      ];
      expect(computeLongestStreak(hands), 2);
    });

    test('summarizeSession', () {
      final s = sessionWith([
        mk(Action.hit, Action.hit, correct: true),
        mk(Action.stand, Action.hit, correct: false),
      ]);
      final sum = summarizeSession(s);
      expect(sum.handsPlayed, 2);
      expect(sum.correctCount, 1);
      expect(sum.correctPct, 50.0);
      expect(sum.profitLoss, 100);
      expect(sum.isLive, false);
    });

    test('mistake categories', () {
      final s = sessionWith([
        mk(Action.stand, Action.hit),
        mk(Action.hit, Action.stand),
        mk(Action.hit, Action.double),
      ]);
      final cats = getMistakeCategories([s]);
      final labels = cats.map((c) => c.label).toSet();
      expect(labels.contains('Stood when should Hit'), true);
      expect(labels.contains('Hit when should Stand'), true);
      expect(labels.contains('Missed Double'), true);
    });

    test('json round-trip', () {
      final s = sessionWith([mk(Action.stand, Action.hit)]);
      final back = Session.fromJson(s.toJson());
      expect(back.hands.length, 1);
      expect(back.hands[0].optimalAction, Action.hit);
      expect(back.startBankroll, 1000);
    });
  });
}
