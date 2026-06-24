import 'cards.dart';
import 'variants.dart';

enum GamePhase { idle, betting, dealing, playerTurn, dealerTurn, complete }

enum HandResult { win, lose, push, blackjack, surrender }

class PlayerHand {
  final List<Card> cards;
  final int bet;
  final bool doubled;
  final bool surrendered;
  final bool splitFromAce;
  final HandResult? result;
  final int payout;

  const PlayerHand({
    required this.cards,
    required this.bet,
    this.doubled = false,
    this.surrendered = false,
    this.splitFromAce = false,
    this.result,
    this.payout = 0,
  });

  PlayerHand copyWith({
    List<Card>? cards,
    int? bet,
    bool? doubled,
    bool? surrendered,
    bool? splitFromAce,
    HandResult? result,
    bool clearResult = false,
    int? payout,
  }) =>
      PlayerHand(
        cards: cards ?? this.cards,
        bet: bet ?? this.bet,
        doubled: doubled ?? this.doubled,
        surrendered: surrendered ?? this.surrendered,
        splitFromAce: splitFromAce ?? this.splitFromAce,
        result: clearResult ? null : (result ?? this.result),
        payout: payout ?? this.payout,
      );
}

class GameState {
  final GamePhase phase;
  final List<Card> deck;
  final List<Card> dealerCards;
  final List<PlayerHand> playerHands;
  final int activeHandIndex;
  final int pendingBet;
  final int bankroll;
  final RuleSet ruleSet;
  final String message;

  const GameState({
    required this.phase,
    required this.deck,
    required this.dealerCards,
    required this.playerHands,
    required this.activeHandIndex,
    required this.pendingBet,
    required this.bankroll,
    required this.ruleSet,
    required this.message,
  });

  GameState copyWith({
    GamePhase? phase,
    List<Card>? deck,
    List<Card>? dealerCards,
    List<PlayerHand>? playerHands,
    int? activeHandIndex,
    int? pendingBet,
    int? bankroll,
    RuleSet? ruleSet,
    String? message,
  }) =>
      GameState(
        phase: phase ?? this.phase,
        deck: deck ?? this.deck,
        dealerCards: dealerCards ?? this.dealerCards,
        playerHands: playerHands ?? this.playerHands,
        activeHandIndex: activeHandIndex ?? this.activeHandIndex,
        pendingBet: pendingBet ?? this.pendingBet,
        bankroll: bankroll ?? this.bankroll,
        ruleSet: ruleSet ?? this.ruleSet,
        message: message ?? this.message,
      );
}

GameState createInitialState({int bankroll = 1000, RuleSet ruleSet = vegasStrip}) {
  return GameState(
    phase: GamePhase.betting,
    deck: shuffle(createDeck(ruleSet.numDecks)),
    dealerCards: const [],
    playerHands: const [],
    activeHandIndex: 0,
    pendingBet: 0,
    bankroll: bankroll,
    ruleSet: ruleSet,
    message: 'Place your bet to begin.',
  );
}

GameState setBet(GameState state, int amount) {
  if (state.phase != GamePhase.betting) return state;
  if (amount < 1 || amount > state.bankroll) return state;
  return state.copyWith(pendingBet: amount);
}

GameState addToBet(GameState state, int chips) {
  if (state.phase != GamePhase.betting) return state;
  final newBet = state.pendingBet + chips;
  if (newBet > state.bankroll) return state;
  return state.copyWith(pendingBet: newBet);
}

GameState clearBet(GameState state) {
  if (state.phase != GamePhase.betting) return state;
  return state.copyWith(pendingBet: 0);
}

GameState _ensureDeck(GameState state) {
  if (state.deck.length < (state.ruleSet.numDecks * 52) / 4) {
    return state.copyWith(deck: shuffle(createDeck(state.ruleSet.numDecks)));
  }
  return state;
}

GameState dealHand(GameState state) {
  if (state.phase != GamePhase.betting || state.pendingBet < 1) return state;

  final s = _ensureDeck(state);
  var deck = s.deck;

  Card deal([bool faceDown = false]) {
    final res = dealCard(deck, faceDown);
    deck = res.remaining;
    return res.card;
  }

  final playerCard1 = deal();
  final dealerCard1 = deal();
  final playerCard2 = deal();
  final dealerCard2 = deal(true);

  final playerHand = PlayerHand(
    cards: [playerCard1, playerCard2],
    bet: s.pendingBet,
  );

  final newState = s.copyWith(
    phase: GamePhase.playerTurn,
    deck: deck,
    dealerCards: [dealerCard1, dealerCard2],
    playerHands: [playerHand],
    activeHandIndex: 0,
    bankroll: s.bankroll - s.pendingBet,
    pendingBet: 0,
    message: '',
  );

  final playerHasBlackjack = isBlackjack([playerCard1, playerCard2]);
  if (playerHasBlackjack) {
    final revealedDealer = newState.dealerCards.map((c) => c.copyWith(faceDown: false)).toList();
    return _resolveHands(newState.copyWith(dealerCards: revealedDealer, phase: GamePhase.complete));
  }

  return newState;
}

bool canDouble(GameState state) {
  if (state.phase != GamePhase.playerTurn) return false;
  if (state.activeHandIndex >= state.playerHands.length) return false;
  final hand = state.playerHands[state.activeHandIndex];
  if (hand.splitFromAce) return false;
  if (hand.cards.length != 2) return false;
  if (state.playerHands.length > 1 && !state.ruleSet.doubleAfterSplit) return false;
  return state.bankroll >= hand.bet;
}

bool canSplit(GameState state) {
  if (state.phase != GamePhase.playerTurn) return false;
  if (state.activeHandIndex >= state.playerHands.length) return false;
  final hand = state.playerHands[state.activeHandIndex];
  if (hand.cards.length != 2) return false;
  final c1 = hand.cards[0];
  final c2 = hand.cards[1];
  final v1 = (c1.rank == 'J' || c1.rank == 'Q' || c1.rank == 'K') ? '10' : c1.rank;
  final v2 = (c2.rank == 'J' || c2.rank == 'Q' || c2.rank == 'K') ? '10' : c2.rank;
  if (v1 != v2) return false;
  if (state.playerHands.length >= state.ruleSet.maxSplits + 1) return false;
  if (c1.rank == 'A' && !state.ruleSet.resplitAces && state.playerHands.length > 1) return false;
  return state.bankroll >= hand.bet;
}

bool canSurrender(GameState state) {
  if (state.ruleSet.surrender == Surrender.none) return false;
  if (state.phase != GamePhase.playerTurn) return false;
  if (state.activeHandIndex >= state.playerHands.length) return false;
  final hand = state.playerHands[state.activeHandIndex];
  return hand.cards.length == 2 && state.playerHands.length == 1;
}

GameState hit(GameState state) {
  if (state.phase != GamePhase.playerTurn) return state;
  final handIdx = state.activeHandIndex;
  if (handIdx >= state.playerHands.length) return state;
  final hand = state.playerHands[handIdx];
  if (hand.splitFromAce) return state;

  final res = dealCard(state.deck);
  final updatedHand = hand.copyWith(cards: [...hand.cards, res.card]);
  final playerHands = [
    for (var i = 0; i < state.playerHands.length; i++)
      i == handIdx ? updatedHand : state.playerHands[i]
  ];

  var newState = state.copyWith(deck: res.remaining, playerHands: playerHands);

  // Auto-advance on bust OR on 21 — player cannot hit a completed hand.
  if (handValue(updatedHand.cards).total >= 21) {
    newState = _advanceHand(newState);
  }
  return newState;
}

GameState stand(GameState state) {
  if (state.phase != GamePhase.playerTurn) return state;
  return _advanceHand(state);
}

GameState doubleDown(GameState state) {
  if (!canDouble(state)) return state;
  final handIdx = state.activeHandIndex;
  final hand = state.playerHands[handIdx];

  final res = dealCard(state.deck);
  final updatedHand = hand.copyWith(
    cards: [...hand.cards, res.card],
    bet: hand.bet * 2,
    doubled: true,
  );
  final playerHands = [
    for (var i = 0; i < state.playerHands.length; i++)
      i == handIdx ? updatedHand : state.playerHands[i]
  ];

  return _advanceHand(state.copyWith(
    deck: res.remaining,
    playerHands: playerHands,
    bankroll: state.bankroll - hand.bet,
  ));
}

GameState split(GameState state) {
  if (!canSplit(state)) return state;
  final handIdx = state.activeHandIndex;
  final hand = state.playerHands[handIdx];
  final c1 = hand.cards[0];
  final c2 = hand.cards[1];

  var deck = state.deck;
  final r1 = dealCard(deck);
  deck = r1.remaining;
  final r2 = dealCard(deck);
  deck = r2.remaining;
  final newCard1 = r1.card;
  final newCard2 = r2.card;

  if (c1.rank == 'A') {
    final splitHand1 = hand.copyWith(cards: [c1, newCard1], splitFromAce: true);
    final splitHand2 = hand.copyWith(
        cards: [c2, newCard2], clearResult: true, payout: 0, splitFromAce: true);
    final hands = [
      ...state.playerHands.sublist(0, handIdx),
      splitHand1,
      splitHand2,
      ...state.playerHands.sublist(handIdx + 1),
    ];
    final newState =
        state.copyWith(deck: deck, playerHands: hands, bankroll: state.bankroll - hand.bet);

    final hand1IsAcePair = newCard1.rank == 'A';
    final canResplit = state.ruleSet.resplitAces &&
        hand1IsAcePair &&
        hands.length <= state.ruleSet.maxSplits;
    if (canResplit) return newState;

    return _advanceHand(newState);
  }

  final splitHand1 = hand.copyWith(cards: [c1, newCard1], splitFromAce: false);
  final splitHand2 = hand.copyWith(
      cards: [c2, newCard2], clearResult: true, payout: 0, splitFromAce: false);
  final hands = [
    ...state.playerHands.sublist(0, handIdx),
    splitHand1,
    splitHand2,
    ...state.playerHands.sublist(handIdx + 1),
  ];

  var newState = state.copyWith(
    deck: deck,
    playerHands: hands,
    bankroll: state.bankroll - hand.bet,
  );

  // Auto-advance if the first split hand already totals 21.
  if (handValue(splitHand1.cards).total >= 21) {
    newState = _advanceHand(newState);
  }
  return newState;
}

GameState surrender(GameState state) {
  if (!canSurrender(state)) return state;
  final hand = state.playerHands[0];
  final payout = (hand.bet / 2).floor();
  final updatedHand =
      hand.copyWith(surrendered: true, result: HandResult.surrender, payout: payout);
  return state.copyWith(
    phase: GamePhase.complete,
    playerHands: [updatedHand],
    bankroll: state.bankroll + payout,
    dealerCards: state.dealerCards.map((c) => c.copyWith(faceDown: false)).toList(),
    message: 'Surrendered. Half your bet returned.',
  );
}

GameState _advanceHand(GameState state) {
  var nextIdx = state.activeHandIndex + 1;

  while (nextIdx < state.playerHands.length) {
    final next = state.playerHands[nextIdx];
    if (!next.splitFromAce) break;
    final cards = next.cards;
    final isAcePair =
        cards.length == 2 && cards[0].rank == 'A' && cards[1].rank == 'A';
    final canResplit = state.ruleSet.resplitAces &&
        isAcePair &&
        state.playerHands.length <= state.ruleSet.maxSplits;
    if (canResplit) break;
    nextIdx++;
  }

  if (nextIdx < state.playerHands.length) {
    return state.copyWith(activeHandIndex: nextIdx);
  }
  return _runDealer(state);
}

GameState _runDealer(GameState state) {
  final allBust = state.playerHands.every((h) => isBust(h.cards) || h.surrendered);
  if (allBust) {
    final revealedDealer = state.dealerCards.map((c) => c.copyWith(faceDown: false)).toList();
    return _resolveHands(state.copyWith(dealerCards: revealedDealer, phase: GamePhase.complete));
  }

  var dealerCards = state.dealerCards.map((c) => c.copyWith(faceDown: false)).toList();
  var deck = state.deck;

  while (true) {
    final v = handValue(dealerCards);
    final shouldHit =
        v.total < 17 || (state.ruleSet.dealerHitsSoft17 && v.soft && v.total == 17);
    if (!shouldHit) break;
    final res = dealCard(deck);
    dealerCards = [...dealerCards, res.card];
    deck = res.remaining;
  }

  return _resolveHands(
      state.copyWith(dealerCards: dealerCards, deck: deck, phase: GamePhase.complete));
}

GameState _resolveHands(GameState state) {
  final dealerVal = handValue(state.dealerCards);
  final dealerBusted = dealerVal.total > 21;
  final dealerBJ = isBlackjack(state.dealerCards);

  final resolvedHands = state.playerHands.map((hand) {
    if (hand.surrendered) return hand;

    final playerVal = handValue(hand.cards);
    final playerBusted = playerVal.total > 21;
    final playerBJ = isBlackjack(hand.cards) && state.playerHands.length == 1;

    HandResult result;
    int payout;

    if (playerBusted) {
      result = HandResult.lose;
      payout = 0;
    } else if (playerBJ && !dealerBJ) {
      result = HandResult.blackjack;
      payout = hand.bet +
          (hand.bet * blackjackPayoutMultiplier(state.ruleSet.blackjackPays)).floor();
    } else if (playerBJ && dealerBJ) {
      result = HandResult.push;
      payout = hand.bet;
    } else if (dealerBJ) {
      result = HandResult.lose;
      payout = 0;
    } else if (dealerBusted) {
      result = HandResult.win;
      payout = hand.bet * 2;
    } else if (playerVal.total > dealerVal.total) {
      result = HandResult.win;
      payout = hand.bet * 2;
    } else if (playerVal.total == dealerVal.total) {
      result = HandResult.push;
      payout = hand.bet;
    } else {
      result = HandResult.lose;
      payout = 0;
    }

    return hand.copyWith(result: result, payout: payout);
  }).toList();

  final totalPayout = resolvedHands.fold<int>(0, (sum, h) => sum + h.payout);
  final resultMessages = resolvedHands.map((h) {
    switch (h.result) {
      case HandResult.blackjack:
        return 'Blackjack!';
      case HandResult.win:
        return 'You win!';
      case HandResult.push:
        return 'Push — bet returned.';
      case HandResult.surrender:
        return 'Surrendered.';
      default:
        return 'Dealer wins.';
    }
  }).toList();

  return state.copyWith(
    phase: GamePhase.complete,
    playerHands: resolvedHands,
    bankroll: state.bankroll + totalPayout,
    message: resultMessages.join(' | '),
  );
}

GameState newHand(GameState state) {
  if (state.phase != GamePhase.complete) return state;
  if (state.bankroll < 1) {
    return state.copyWith(
        phase: GamePhase.betting, message: 'Out of chips! Reload to play again.');
  }
  return state.copyWith(
    phase: GamePhase.betting,
    dealerCards: const [],
    playerHands: const [],
    activeHandIndex: 0,
    pendingBet: 0,
    message: 'Place your bet to begin.',
  );
}

PlayerHand? getActiveHand(GameState state) {
  if (state.activeHandIndex >= state.playerHands.length) return null;
  return state.playerHands[state.activeHandIndex];
}

HandValue getHandValue(PlayerHand hand) => handValue(hand.cards);
