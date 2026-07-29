import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/cards.dart';
import '../engine/engine.dart' as eng;
import '../engine/stats.dart';
import '../engine/strategy.dart';
import 'achievements_provider.dart';
import 'settings_provider.dart';
import 'stats_provider.dart';

class LastHandInfo {
  final OptimalAction optimal;
  final Action playerAction;
  final bool wasCorrect;
  final int playerTotal;
  final bool soft;
  final String dealerUpcard;
  final HandType handType;
  const LastHandInfo({
    required this.optimal,
    required this.playerAction,
    required this.wasCorrect,
    required this.playerTotal,
    required this.soft,
    required this.dealerUpcard,
    required this.handType,
  });
}

class GameStoreState {
  final eng.GameState game;
  final LastHandInfo? lastHandInfo;
  final bool handHadMistake;
  final LastHandInfo? firstMistakeInfo;
  final bool hasDealtInSession;

  /// Increments on every deal so the card-deal animation replays for a fresh
  /// hand even when an identical card lands in the same position.
  final int roundId;

  const GameStoreState({
    required this.game,
    this.lastHandInfo,
    this.handHadMistake = false,
    this.firstMistakeInfo,
    this.hasDealtInSession = false,
    this.roundId = 0,
  });

  GameStoreState copyWith({
    eng.GameState? game,
    LastHandInfo? lastHandInfo,
    bool clearLastHandInfo = false,
    bool? handHadMistake,
    LastHandInfo? firstMistakeInfo,
    bool clearFirstMistakeInfo = false,
    bool? hasDealtInSession,
    int? roundId,
  }) =>
      GameStoreState(
        game: game ?? this.game,
        lastHandInfo: clearLastHandInfo ? null : (lastHandInfo ?? this.lastHandInfo),
        handHadMistake: handHadMistake ?? this.handHadMistake,
        firstMistakeInfo:
            clearFirstMistakeInfo ? null : (firstMistakeInfo ?? this.firstMistakeInfo),
        hasDealtInSession: hasDealtInSession ?? this.hasDealtInSession,
        roundId: roundId ?? this.roundId,
      );
}


HandType _detectHandType(eng.GameState game) {
  if (game.activeHandIndex >= game.playerHands.length) return HandType.hard;
  final hand = game.playerHands[game.activeHandIndex];
  final hv = handValue(hand.cards);
  if (hand.cards.length == 2) {
    final c1 = hand.cards[0];
    final c2 = hand.cards[1];
    final k1 = (c1.rank == 'J' || c1.rank == 'Q' || c1.rank == 'K') ? '10' : c1.rank;
    final k2 = (c2.rank == 'J' || c2.rank == 'Q' || c2.rank == 'K') ? '10' : c2.rank;
    if (k1 == k2) return HandType.pair;
  }
  if (hv.soft && hv.total >= 13 && hv.total <= 20) return HandType.soft;
  return HandType.hard;
}

class GameController extends Notifier<GameStoreState> {
  @override
  GameStoreState build() {
    final settings = ref.read(settingsProvider);
    return GameStoreState(
      game: eng.createInitialState(ruleSet: settings.ruleSet),
    );
  }

  // Set when a resume wants to end the sitting but a hand is mid-play; the
  // roll-over then happens on the next deal.
  bool _rotatePending = false;

  bool get _inHand {
    final p = state.game.phase;
    return p == eng.GamePhase.dealing ||
        p == eng.GamePhase.playerTurn ||
        p == eng.GamePhase.dealerTurn;
  }

  /// Ends the current sitting when the app returns to the foreground after being
  /// away long enough. Deferred while a hand is in play so no in-progress hand is
  /// stranded — it rolls over on the next deal instead.
  void endSittingIfIdle() {
    final current = ref.read(statsProvider).currentSession;
    if (current == null || current.hands.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - current.hands.last.timestamp <= kSittingIdleMs) return;
    if (_inHand) {
      _rotatePending = true;
      return;
    }
    ref.read(statsProvider.notifier).finishSession();
    // currentSession is now null; the next deal opens a fresh sitting.
  }

  void _maybeRotateSession(eng.GameState game) {
    final settings = ref.read(settingsProvider);
    final statsCtrl = ref.read(statsProvider.notifier);
    final current = ref.read(statsProvider).currentSession;

    final now = DateTime.now().millisecondsSinceEpoch;
    final idle = current != null &&
        current.hands.isNotEmpty &&
        now - current.hands.last.timestamp > kSittingIdleMs;

    if (current != null && current.hands.isNotEmpty && (_rotatePending || idle)) {
      statsCtrl.finishSession();
      state = state.copyWith(
        handHadMistake: false,
        hasDealtInSession: false,
        game: eng.createInitialState(ruleSet: settings.ruleSet),
      );
    }
    _rotatePending = false;
    if (ref.read(statsProvider).currentSession == null) {
      statsCtrl.startSession(settings.ruleSet.id);
    }
  }

  void deal() {
    final game = state.game;
    _maybeRotateSession(game);
    final difficulty = ref.read(settingsProvider).difficulty;
    state = state.copyWith(
      game: eng.dealHand(state.game, difficulty: difficulty),
      clearLastHandInfo: true,
      handHadMistake: false,
      hasDealtInSession: true,
      clearFirstMistakeInfo: true,
      roundId: state.roundId + 1,
    );
    _maybeRecordDealtHand(state.game);
  }

  void hit() {
    final game = state.game;
    if (game.activeHandIndex >= game.playerHands.length) return;
    final hand = game.playerHands[game.activeHandIndex];
    if (game.dealerCards.isEmpty) return;
    final dealerUpcard = game.dealerCards[0];

    final optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    final wasCorrect = optimal.action == Action.hit ||
        (optimal.action == Action.double &&
            optimal.doubleFallback == 'H' &&
            !eng.canDouble(game));
    final hv = handValue(hand.cards);
    final info = LastHandInfo(
      optimal: optimal,
      playerAction: Action.hit,
      wasCorrect: wasCorrect,
      playerTotal: hv.total,
      soft: hv.soft,
      dealerUpcard: dealerUpcard.rank,
      handType: _detectHandType(game),
    );
    _applyPlay(eng.hit(game), info);
  }

  void stand() {
    final game = state.game;
    if (game.activeHandIndex >= game.playerHands.length) return;
    final hand = game.playerHands[game.activeHandIndex];
    if (game.dealerCards.isEmpty) return;
    final dealerUpcard = game.dealerCards[0];

    final optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    final wasCorrect = optimal.action == Action.stand ||
        (optimal.action == Action.double &&
            optimal.doubleFallback == 'S' &&
            !eng.canDouble(game));
    final hv = handValue(hand.cards);
    final info = LastHandInfo(
      optimal: optimal,
      playerAction: Action.stand,
      wasCorrect: wasCorrect,
      playerTotal: hv.total,
      soft: hv.soft,
      dealerUpcard: dealerUpcard.rank,
      handType: _detectHandType(game),
    );
    _applyPlay(eng.stand(game), info);
  }

  void double() {
    final game = state.game;
    if (game.activeHandIndex >= game.playerHands.length) return;
    final hand = game.playerHands[game.activeHandIndex];
    if (game.dealerCards.isEmpty) return;
    final dealerUpcard = game.dealerCards[0];

    final optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    final hv = handValue(hand.cards);
    final info = LastHandInfo(
      optimal: optimal,
      playerAction: Action.double,
      wasCorrect: optimal.action == Action.double,
      playerTotal: hv.total,
      soft: hv.soft,
      dealerUpcard: dealerUpcard.rank,
      handType: _detectHandType(game),
    );
    _applyPlay(eng.doubleDown(game), info);
  }

  void split() {
    final game = state.game;
    if (game.activeHandIndex >= game.playerHands.length) return;
    final hand = game.playerHands[game.activeHandIndex];
    if (game.dealerCards.isEmpty) return;
    final dealerUpcard = game.dealerCards[0];

    final optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    final hv = handValue(hand.cards);
    final info = LastHandInfo(
      optimal: optimal,
      playerAction: Action.split,
      wasCorrect: optimal.action == Action.split,
      playerTotal: hv.total,
      soft: hv.soft,
      dealerUpcard: dealerUpcard.rank,
      handType: HandType.pair,
    );
    _applyPlay(eng.split(game), info);
  }

  void surrender() {
    final game = state.game;
    if (game.activeHandIndex >= game.playerHands.length) return;
    final hand = game.playerHands[game.activeHandIndex];
    if (game.dealerCards.isEmpty) return;
    final dealerUpcard = game.dealerCards[0];

    final optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    final hv = handValue(hand.cards);
    final info = LastHandInfo(
      optimal: optimal,
      playerAction: Action.surrender,
      wasCorrect: optimal.action == Action.surrender,
      playerTotal: hv.total,
      soft: hv.soft,
      dealerUpcard: dealerUpcard.rank,
      handType: _detectHandType(game),
    );
    _applyPlay(eng.surrender(game), info);
  }

  void nextHand() {
    state = state.copyWith(
      game: eng.newHand(state.game),
      clearLastHandInfo: true,
      handHadMistake: false,
      clearFirstMistakeInfo: true,
    );
  }

  void forfeitHand() {
    final game = state.game;
    state = state.copyWith(
      game: game.copyWith(
        phase: eng.GamePhase.betting,
        dealerCards: const [],
        playerHands: const [],
        activeHandIndex: 0,
        message: 'Tap Deal to start.',
      ),
      clearLastHandInfo: true,
      handHadMistake: false,
      clearFirstMistakeInfo: true,
    );
  }

  void rebetAndDeal() {
    final game = state.game;
    _maybeRotateSession(game);
    final difficulty = ref.read(settingsProvider).difficulty;
    final next = eng.newHand(state.game);
    state = state.copyWith(
      game: eng.dealHand(next, difficulty: difficulty),
      clearLastHandInfo: true,
      handHadMistake: false,
      clearFirstMistakeInfo: true,
      hasDealtInSession: true,
      roundId: state.roundId + 1,
    );
    _maybeRecordDealtHand(state.game);
  }

  void newSession() {
    final settings = ref.read(settingsProvider);
    final statsCtrl = ref.read(statsProvider.notifier);
    statsCtrl.finishSession();
    statsCtrl.startSession(settings.ruleSet.id);
    state = GameStoreState(
      game: eng.createInitialState(ruleSet: settings.ruleSet),
      hasDealtInSession: false,
    );
  }

  bool get canDouble => eng.canDouble(state.game);
  bool get canSplit => eng.canSplit(state.game);
  bool get canSurrender => eng.canSurrender(state.game);

  void _applyPlay(eng.GameState nextGame, LastHandInfo info) {
    final newHadMistake = state.handHadMistake || !info.wasCorrect;
    final newFirstMistakeInfo =
        (!state.handHadMistake && !info.wasCorrect) ? info : state.firstMistakeInfo;

    state = state.copyWith(
      game: nextGame,
      lastHandInfo: info,
      handHadMistake: newHadMistake,
      firstMistakeInfo: newFirstMistakeInfo,
    );

    // Per-cell strategy accuracy: log every decision against its chart cell.
    ref.read(strategyStatsProvider.notifier).record(
          handType: info.handType,
          playerTotal: info.playerTotal,
          soft: info.soft,
          dealerUpcard: info.dealerUpcard,
          wasCorrect: info.wasCorrect,
        );

    if (nextGame.phase == eng.GamePhase.complete) {
      final stats = ref.read(statsProvider);
      if (stats.currentSession != null) {
        final recordInfo =
            (newHadMistake && newFirstMistakeInfo != null) ? newFirstMistakeInfo : info;
        final firstHand = nextGame.playerHands.isNotEmpty ? nextGame.playerHands[0] : null;
        ref.read(statsProvider.notifier).addHandRecord(HandRecord(
              id: '',
              timestamp: 0,
              playerAction: recordInfo.playerAction,
              optimalAction: recordInfo.optimal.action,
              wasCorrect: !newHadMistake,
              playerTotal: recordInfo.playerTotal,
              soft: recordInfo.soft,
              dealerUpcard: recordInfo.dealerUpcard,
              handType: recordInfo.handType,
              explanation: recordInfo.optimal.explanation,
              outcome: firstHand?.result ?? eng.HandResult.lose,
            ));
      }
    }

    ref.read(achievementsProvider.notifier).evaluate();
  }

  /// Records a hand that resolves the moment it's dealt — a player or dealer
  /// blackjack — since those never pass through [_applyPlay] (there's no
  /// decision to make). Marked correct because there's no play to misgrade.
  void _maybeRecordDealtHand(eng.GameState game) {
    if (game.phase != eng.GamePhase.complete) return;
    if (ref.read(statsProvider).currentSession == null) return;
    if (game.playerHands.isEmpty || game.dealerCards.isEmpty) return;
    final firstHand = game.playerHands[0];
    final hv = handValue(firstHand.cards);
    ref.read(statsProvider.notifier).addHandRecord(HandRecord(
          id: '',
          timestamp: 0,
          playerAction: Action.stand,
          optimalAction: Action.stand,
          wasCorrect: true,
          playerTotal: hv.total,
          soft: hv.soft,
          dealerUpcard: game.dealerCards[0].rank,
          handType: hv.soft ? HandType.soft : HandType.hard,
          explanation: '',
          outcome: firstHand.result ?? eng.HandResult.lose,
          dealerBlackjack: isBlackjack(game.dealerCards),
        ));
    ref.read(achievementsProvider.notifier).evaluate();
  }
}

final gameProvider = NotifierProvider<GameController, GameStoreState>(GameController.new);
