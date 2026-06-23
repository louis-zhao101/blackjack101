import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/cards.dart';
import '../engine/engine.dart' as eng;
import '../engine/stats.dart';
import '../engine/strategy.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
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

class PlayStats {
  final int total;
  final int correct;
  const PlayStats({this.total = 0, this.correct = 0});
}

class GameStoreState {
  final eng.GameState game;
  final LastHandInfo? lastHandInfo;
  final int lastBet;
  final PlayStats playStats;
  final bool handHadMistake;
  final LastHandInfo? firstMistakeInfo;

  const GameStoreState({
    required this.game,
    this.lastHandInfo,
    this.lastBet = 0,
    this.playStats = const PlayStats(),
    this.handHadMistake = false,
    this.firstMistakeInfo,
  });

  GameStoreState copyWith({
    eng.GameState? game,
    LastHandInfo? lastHandInfo,
    bool clearLastHandInfo = false,
    int? lastBet,
    PlayStats? playStats,
    bool? handHadMistake,
    LastHandInfo? firstMistakeInfo,
    bool clearFirstMistakeInfo = false,
  }) =>
      GameStoreState(
        game: game ?? this.game,
        lastHandInfo: clearLastHandInfo ? null : (lastHandInfo ?? this.lastHandInfo),
        lastBet: lastBet ?? this.lastBet,
        playStats: playStats ?? this.playStats,
        handHadMistake: handHadMistake ?? this.handHadMistake,
        firstMistakeInfo:
            clearFirstMistakeInfo ? null : (firstMistakeInfo ?? this.firstMistakeInfo),
      );
}

const _sessionTimeoutMs = 60 * 60 * 1000;

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
      game: eng.createInitialState(
        bankroll: settings.startingBankroll,
        ruleSet: settings.ruleSet,
      ),
    );
  }

  void placeBetChip(int amount) {
    state = state.copyWith(game: eng.addToBet(state.game, amount));
  }

  void clearBet() {
    state = state.copyWith(game: eng.clearBet(state.game));
  }

  void _maybeRotateSession(eng.GameState game) {
    final settings = ref.read(settingsProvider);
    final stats = ref.read(statsProvider);
    final statsCtrl = ref.read(statsProvider.notifier);
    final current = stats.currentSession;

    if (current != null && current.hands.isNotEmpty) {
      final lastHand = current.hands.last;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastHand.timestamp > _sessionTimeoutMs) {
        statsCtrl.finishSession(game.bankroll);
        statsCtrl.startSession(game.bankroll, settings.ruleSet.id);
        state = state.copyWith(
            playStats: const PlayStats(), handHadMistake: false);
      }
    }
    if (ref.read(statsProvider).currentSession == null) {
      statsCtrl.startSession(game.bankroll, settings.ruleSet.id);
    }
  }

  void deal() {
    final game = state.game;
    _maybeRotateSession(game);
    final originalBet = game.pendingBet;
    state = state.copyWith(
      game: eng.dealHand(game),
      clearLastHandInfo: true,
      handHadMistake: false,
      clearFirstMistakeInfo: true,
      lastBet: originalBet,
    );
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
    final next = eng.newHand(state.game);
    final autobet = state.lastBet < next.bankroll ? state.lastBet : next.bankroll;
    state = state.copyWith(
      game: autobet > 0 ? next.copyWith(pendingBet: autobet) : next,
      clearLastHandInfo: true,
      handHadMistake: false,
      clearFirstMistakeInfo: true,
    );
  }

  void forfeitHand() {
    final game = state.game;
    final refund = game.playerHands.fold<int>(0, (sum, h) => sum + h.bet);
    final newBankroll = game.bankroll + refund;
    final autobet = state.lastBet < newBankroll ? state.lastBet : newBankroll;
    state = state.copyWith(
      game: game.copyWith(
        phase: eng.GamePhase.betting,
        dealerCards: const [],
        playerHands: const [],
        activeHandIndex: 0,
        pendingBet: autobet,
        bankroll: newBankroll,
        message: 'Place your bet to begin.',
      ),
      clearLastHandInfo: true,
      handHadMistake: false,
      clearFirstMistakeInfo: true,
    );
  }

  void rebetAndDeal() {
    final game = state.game;
    _maybeRotateSession(game);
    var next = eng.newHand(game);
    final autobet = state.lastBet < next.bankroll ? state.lastBet : next.bankroll;
    if (autobet > 0) {
      next = eng.dealHand(next.copyWith(pendingBet: autobet));
    }
    state = state.copyWith(
      game: next,
      clearLastHandInfo: true,
      handHadMistake: false,
      clearFirstMistakeInfo: true,
    );
  }

  void topUp(int amount) {
    final newBankroll = state.game.bankroll + amount;
    state = state.copyWith(game: state.game.copyWith(bankroll: newBankroll));
    _syncBankroll(newBankroll);
  }

  void loadBankroll(int bankroll) {
    state = state.copyWith(game: state.game.copyWith(bankroll: bankroll));
  }

  void newSession() {
    final game = state.game;
    final settings = ref.read(settingsProvider);
    final statsCtrl = ref.read(statsProvider.notifier);
    statsCtrl.finishSession(game.bankroll);
    statsCtrl.startSession(game.bankroll, settings.ruleSet.id);
    _syncBankroll(game.bankroll);
    state = GameStoreState(
      game: eng.createInitialState(bankroll: game.bankroll, ruleSet: settings.ruleSet),
    );
  }

  bool get canDouble => eng.canDouble(state.game);
  bool get canSplit => eng.canSplit(state.game);
  bool get canSurrender => eng.canSurrender(state.game);

  void _applyPlay(eng.GameState nextGame, LastHandInfo info) {
    final newHadMistake = state.handHadMistake || !info.wasCorrect;
    final newPlayStats = PlayStats(
      total: state.playStats.total + 1,
      correct: state.playStats.correct + (info.wasCorrect ? 1 : 0),
    );
    final newFirstMistakeInfo =
        (!state.handHadMistake && !info.wasCorrect) ? info : state.firstMistakeInfo;

    state = state.copyWith(
      game: nextGame,
      lastHandInfo: info,
      handHadMistake: newHadMistake,
      playStats: newPlayStats,
      firstMistakeInfo: newFirstMistakeInfo,
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
              betAmount: firstHand?.bet ?? 0,
              outcome: firstHand?.result ?? eng.HandResult.lose,
              payout: firstHand?.payout ?? 0,
            ));
      }
    }
  }

  void _syncBankroll(int bankroll) {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid != null) {
      ref.read(firestoreSyncProvider).upsertProfile(uid, bankroll);
    }
  }
}

final gameProvider = NotifierProvider<GameController, GameStoreState>(GameController.new);
