import { Card, HandValue, handValue, isBust, isBlackjack, createDeck, shuffle, dealCard } from './cards.js';
import { RuleSet, VEGAS_STRIP, blackjackPayoutMultiplier } from './variants.js';

export type GamePhase =
  | 'IDLE'
  | 'BETTING'
  | 'DEALING'
  | 'PLAYER_TURN'
  | 'DEALER_TURN'
  | 'COMPLETE';

export type HandResult = 'win' | 'lose' | 'push' | 'blackjack' | 'surrender';

export interface PlayerHand {
  cards: Card[];
  bet: number;
  doubled: boolean;
  surrendered: boolean;
  result: HandResult | null;
  payout: number;
}

export interface GameState {
  phase: GamePhase;
  deck: Card[];
  dealerCards: Card[];
  playerHands: PlayerHand[];
  activeHandIndex: number;
  pendingBet: number;
  bankroll: number;
  ruleSet: RuleSet;
  message: string;
}

export function createInitialState(bankroll = 1000, ruleSet: RuleSet = VEGAS_STRIP): GameState {
  return {
    phase: 'BETTING',
    deck: shuffle(createDeck(ruleSet.numDecks)),
    dealerCards: [],
    playerHands: [],
    activeHandIndex: 0,
    pendingBet: 0,
    bankroll,
    ruleSet,
    message: 'Place your bet to begin.',
  };
}

export function setBet(state: GameState, amount: number): GameState {
  if (state.phase !== 'BETTING') return state;
  if (amount < 1 || amount > state.bankroll) return state;
  return { ...state, pendingBet: amount };
}

export function addToBet(state: GameState, chips: number): GameState {
  if (state.phase !== 'BETTING') return state;
  const newBet = state.pendingBet + chips;
  if (newBet > state.bankroll) return state;
  return { ...state, pendingBet: newBet };
}

export function clearBet(state: GameState): GameState {
  if (state.phase !== 'BETTING') return state;
  return { ...state, pendingBet: 0 };
}

function ensureDeck(state: GameState): GameState {
  // Reshuffle when fewer than 25% of cards remain
  if (state.deck.length < (state.ruleSet.numDecks * 52) / 4) {
    return { ...state, deck: shuffle(createDeck(state.ruleSet.numDecks)) };
  }
  return state;
}

export function dealHand(state: GameState): GameState {
  if (state.phase !== 'BETTING' || state.pendingBet < 1) return state;

  let s = ensureDeck(state);
  let deck = s.deck;

  const deal = (d: Card[], faceDown = false) => {
    const { card, remaining } = dealCard(d, faceDown);
    deck = remaining;
    return card;
  };

  const playerCard1 = deal(deck);
  const dealerCard1 = deal(deck);
  const playerCard2 = deal(deck);
  const dealerCard2 = deal(deck, true);

  const playerHand: PlayerHand = {
    cards: [playerCard1, playerCard2],
    bet: s.pendingBet,
    doubled: false,
    surrendered: false,
    result: null,
    payout: 0,
  };

  const newState: GameState = {
    ...s,
    phase: 'PLAYER_TURN',
    deck,
    dealerCards: [dealerCard1, dealerCard2],
    playerHands: [playerHand],
    activeHandIndex: 0,
    bankroll: s.bankroll - s.pendingBet,
    pendingBet: 0,
    message: '',
  };

  // Check for dealer blackjack / player blackjack immediately
  const dealerFaceUpValue = handValue([dealerCard1]);
  const dealerHasAce = dealerCard1.rank === 'A';
  const playerHasBlackjack = isBlackjack([playerCard1, playerCard2]);

  if (playerHasBlackjack) {
    // Reveal dealer hole card, check for push
    const revealedDealer = newState.dealerCards.map((c) => ({ ...c, faceDown: false }));
    const dealerBJ = isBlackjack(revealedDealer);
    return resolveHands({ ...newState, dealerCards: revealedDealer, phase: 'COMPLETE' });
  }

  void dealerFaceUpValue;
  void dealerHasAce;

  return newState;
}

export function canDouble(state: GameState): boolean {
  if (state.phase !== 'PLAYER_TURN') return false;
  const hand = state.playerHands[state.activeHandIndex];
  if (!hand) return false;
  if (hand.cards.length !== 2) return false;
  // Need enough bankroll to match the bet
  return state.bankroll >= hand.bet;
}

export function canSplit(state: GameState): boolean {
  if (state.phase !== 'PLAYER_TURN') return false;
  const hand = state.playerHands[state.activeHandIndex];
  if (!hand) return false;
  if (hand.cards.length !== 2) return false;
  const [c1, c2] = hand.cards;
  if (!c1 || !c2) return false;
  // Ranks must match (10-value cards are all splittable against each other in some rules,
  // but strict split requires same rank)
  const v1 = c1.rank === 'J' || c1.rank === 'Q' || c1.rank === 'K' ? '10' : c1.rank;
  const v2 = c2.rank === 'J' || c2.rank === 'Q' || c2.rank === 'K' ? '10' : c2.rank;
  if (v1 !== v2) return false;
  if (state.playerHands.length >= state.ruleSet.maxSplits + 1) return false;
  // Aces: only one split allowed unless resplitAces
  if (c1.rank === 'A' && !state.ruleSet.resplitAces && state.playerHands.length > 1) return false;
  return state.bankroll >= hand.bet;
}

export function canSurrender(state: GameState): boolean {
  if (state.ruleSet.surrender === 'none') return false;
  if (state.phase !== 'PLAYER_TURN') return false;
  const hand = state.playerHands[state.activeHandIndex];
  if (!hand) return false;
  return hand.cards.length === 2 && state.playerHands.length === 1;
}

export function hit(state: GameState): GameState {
  if (state.phase !== 'PLAYER_TURN') return state;
  const handIdx = state.activeHandIndex;
  const hand = state.playerHands[handIdx];
  if (!hand) return state;

  const { card, remaining } = dealCard(state.deck);
  const updatedHand: PlayerHand = { ...hand, cards: [...hand.cards, card] };
  const playerHands = state.playerHands.map((h, i) => (i === handIdx ? updatedHand : h));

  let newState = { ...state, deck: remaining, playerHands };

  if (isBust(updatedHand.cards)) {
    newState = advanceHand(newState);
  }

  return newState;
}

export function stand(state: GameState): GameState {
  if (state.phase !== 'PLAYER_TURN') return state;
  return advanceHand(state);
}

export function doubleDown(state: GameState): GameState {
  if (!canDouble(state)) return state;
  const handIdx = state.activeHandIndex;
  const hand = state.playerHands[handIdx]!;

  const { card, remaining } = dealCard(state.deck);
  const updatedHand: PlayerHand = {
    ...hand,
    cards: [...hand.cards, card],
    bet: hand.bet * 2,
    doubled: true,
  };
  const playerHands = state.playerHands.map((h, i) => (i === handIdx ? updatedHand : h));

  return advanceHand({
    ...state,
    deck: remaining,
    playerHands,
    bankroll: state.bankroll - hand.bet,
  });
}

export function split(state: GameState): GameState {
  if (!canSplit(state)) return state;
  const handIdx = state.activeHandIndex;
  const hand = state.playerHands[handIdx]!;
  const [c1, c2] = hand.cards as [Card, Card];

  let deck = state.deck;
  const { card: newCard1, remaining: r1 } = dealCard(deck);
  deck = r1;
  const { card: newCard2, remaining: r2 } = dealCard(deck);
  deck = r2;

  const splitHand1: PlayerHand = { ...hand, cards: [c1, newCard1] };
  const splitHand2: PlayerHand = {
    ...hand,
    cards: [c2, newCard2],
    result: null,
    payout: 0,
  };

  // For split aces, only one card each (stand automatically)
  if (c1.rank === 'A') {
    const hands = [
      ...state.playerHands.slice(0, handIdx),
      splitHand1,
      splitHand2,
      ...state.playerHands.slice(handIdx + 1),
    ];
    return advanceHand({ ...state, deck, playerHands: hands, bankroll: state.bankroll - hand.bet });
  }

  const hands = [
    ...state.playerHands.slice(0, handIdx),
    splitHand1,
    splitHand2,
    ...state.playerHands.slice(handIdx + 1),
  ];

  return {
    ...state,
    deck,
    playerHands: hands,
    bankroll: state.bankroll - hand.bet,
  };
}

export function surrender(state: GameState): GameState {
  if (!canSurrender(state)) return state;
  const hand = state.playerHands[0]!;
  const payout = Math.floor(hand.bet / 2);
  const updatedHand: PlayerHand = { ...hand, surrendered: true, result: 'surrender', payout };
  return {
    ...state,
    phase: 'COMPLETE',
    playerHands: [updatedHand],
    bankroll: state.bankroll + payout,
    dealerCards: state.dealerCards.map((c) => ({ ...c, faceDown: false })),
    message: 'Surrendered. Half your bet returned.',
  };
}

function advanceHand(state: GameState): GameState {
  const nextIdx = state.activeHandIndex + 1;
  if (nextIdx < state.playerHands.length) {
    return { ...state, activeHandIndex: nextIdx };
  }
  return runDealer(state);
}

function runDealer(state: GameState): GameState {
  // All player hands busted? Skip dealer play
  const allBust = state.playerHands.every((h) => isBust(h.cards) || h.surrendered);
  if (allBust) {
    const revealedDealer = state.dealerCards.map((c) => ({ ...c, faceDown: false }));
    return resolveHands({ ...state, dealerCards: revealedDealer, phase: 'COMPLETE' });
  }

  let dealerCards = state.dealerCards.map((c) => ({ ...c, faceDown: false }));
  let deck = state.deck;

  while (true) {
    const { total, soft } = handValue(dealerCards);
    const shouldHit = total < 17 || (state.ruleSet.dealerHitsSoft17 && soft && total === 17);
    if (!shouldHit) break;
    const { card, remaining } = dealCard(deck);
    dealerCards = [...dealerCards, card];
    deck = remaining;
  }

  return resolveHands({ ...state, dealerCards, deck, phase: 'COMPLETE' });
}

function resolveHands(state: GameState): GameState {
  const dealerVal = handValue(state.dealerCards);
  const dealerBusted = dealerVal.total > 21;
  const dealerBJ = isBlackjack(state.dealerCards);

  const resolvedHands = state.playerHands.map((hand): PlayerHand => {
    if (hand.surrendered) return hand;

    const playerVal = handValue(hand.cards);
    const playerBusted = playerVal.total > 21;
    const playerBJ = isBlackjack(hand.cards) && state.playerHands.length === 1;

    let result: HandResult;
    let payout: number;

    if (playerBusted) {
      result = 'lose';
      payout = 0;
    } else if (playerBJ && !dealerBJ) {
      result = 'blackjack';
      payout = hand.bet + Math.floor(hand.bet * blackjackPayoutMultiplier(state.ruleSet.blackjackPays));
    } else if (playerBJ && dealerBJ) {
      result = 'push';
      payout = hand.bet;
    } else if (dealerBJ) {
      result = 'lose';
      payout = 0;
    } else if (dealerBusted) {
      result = 'win';
      payout = hand.bet * 2;
    } else if (playerVal.total > dealerVal.total) {
      result = 'win';
      payout = hand.bet * 2;
    } else if (playerVal.total === dealerVal.total) {
      result = 'push';
      payout = hand.bet;
    } else {
      result = 'lose';
      payout = 0;
    }

    return { ...hand, result, payout };
  });

  const totalPayout = resolvedHands.reduce((sum, h) => sum + h.payout, 0);
  const resultMessages = resolvedHands.map((h) => {
    if (h.result === 'blackjack') return 'Blackjack!';
    if (h.result === 'win') return 'You win!';
    if (h.result === 'push') return 'Push — bet returned.';
    if (h.result === 'surrender') return 'Surrendered.';
    return 'Dealer wins.';
  });

  return {
    ...state,
    phase: 'COMPLETE',
    playerHands: resolvedHands,
    bankroll: state.bankroll + totalPayout,
    message: resultMessages.join(' | '),
  };
}

export function newHand(state: GameState): GameState {
  if (state.phase !== 'COMPLETE') return state;
  if (state.bankroll < 1) {
    return { ...state, phase: 'BETTING', message: "Out of chips! Reload to play again." };
  }
  return {
    ...state,
    phase: 'BETTING',
    dealerCards: [],
    playerHands: [],
    activeHandIndex: 0,
    pendingBet: 0,
    message: 'Place your bet to begin.',
  };
}

export function getActiveHand(state: GameState): PlayerHand | null {
  return state.playerHands[state.activeHandIndex] ?? null;
}

export function getHandValue(hand: PlayerHand): HandValue {
  return handValue(hand.cards);
}
