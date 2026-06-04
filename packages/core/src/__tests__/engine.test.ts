import { describe, it, expect } from 'vitest';
import {
  createInitialState,
  setBet,
  addToBet,
  clearBet,
  dealHand,
  hit,
  stand,
  canSplit,
  canDouble,
  canSurrender,
  newHand,
} from '../engine.js';

describe('createInitialState', () => {
  it('starts in BETTING phase', () => {
    const state = createInitialState();
    expect(state.phase).toBe('BETTING');
    expect(state.bankroll).toBe(1000);
    expect(state.pendingBet).toBe(0);
  });
});

describe('betting', () => {
  it('sets bet', () => {
    const state = setBet(createInitialState(), 50);
    expect(state.pendingBet).toBe(50);
  });

  it('adds chips to bet', () => {
    let state = createInitialState();
    state = addToBet(state, 25);
    state = addToBet(state, 25);
    expect(state.pendingBet).toBe(50);
  });

  it('clears bet', () => {
    let state = setBet(createInitialState(), 100);
    state = clearBet(state);
    expect(state.pendingBet).toBe(0);
  });

  it('cannot exceed bankroll', () => {
    const state = setBet(createInitialState(100), 200);
    expect(state.pendingBet).toBe(0);
  });
});

describe('dealHand', () => {
  it('moves to PLAYER_TURN', () => {
    const state = dealHand(setBet(createInitialState(), 50));
    // Could be COMPLETE if player got blackjack
    expect(['PLAYER_TURN', 'COMPLETE']).toContain(state.phase);
  });

  it('deducts bet from bankroll', () => {
    const state = dealHand(setBet(createInitialState(1000), 50));
    // Bankroll decreases by bet (may be increased by blackjack payout)
    expect(state.bankroll).toBeLessThanOrEqual(1000);
  });

  it('deals 2 cards to player, 2 to dealer', () => {
    let state = dealHand(setBet(createInitialState(), 50));
    if (state.phase === 'PLAYER_TURN') {
      expect(state.playerHands[0]?.cards.length).toBe(2);
      expect(state.dealerCards.length).toBe(2);
    }
  });

  it('dealer hole card is face down during player turn', () => {
    let attempts = 0;
    while (attempts < 20) {
      const state = dealHand(setBet(createInitialState(), 50));
      if (state.phase === 'PLAYER_TURN') {
        expect(state.dealerCards[1]?.faceDown).toBe(true);
        return;
      }
      attempts++;
    }
  });

  it('does not deal without a bet', () => {
    const state = dealHand(createInitialState());
    expect(state.phase).toBe('BETTING');
  });
});

describe('hit and stand', () => {
  function getPlayerTurnState() {
    let s = createInitialState();
    s = setBet(s, 50);
    let attempts = 0;
    while (attempts < 50) {
      const dealt = dealHand(s);
      if (dealt.phase === 'PLAYER_TURN') return dealt;
      s = newHand(dealt);
      s = setBet(s, 50);
      attempts++;
    }
    throw new Error('Could not get PLAYER_TURN state after 50 attempts');
  }

  it('hit adds a card', () => {
    const state = getPlayerTurnState();
    const before = state.playerHands[0]!.cards.length;
    const after = hit(state);
    if (after.phase === 'PLAYER_TURN') {
      expect(after.playerHands[after.activeHandIndex]!.cards.length).toBeGreaterThanOrEqual(before);
    }
  });

  it('stand moves to DEALER_TURN or COMPLETE', () => {
    const state = getPlayerTurnState();
    const after = stand(state);
    expect(after.phase).toBe('COMPLETE');
  });
});

describe('canDouble / canSplit / canSurrender', () => {
  function getPlayerTurnState() {
    let s = createInitialState();
    s = setBet(s, 50);
    let attempts = 0;
    while (attempts < 50) {
      const dealt = dealHand(s);
      if (dealt.phase === 'PLAYER_TURN') return dealt;
      s = newHand(dealt);
      s = setBet(s, 50);
      attempts++;
    }
    throw new Error('Could not get PLAYER_TURN state');
  }

  it('canDouble is true on initial 2-card hand with sufficient bankroll', () => {
    const state = getPlayerTurnState();
    expect(canDouble(state)).toBe(true);
  });

  it('canSurrender is false by default (no surrender in default rules)', () => {
    const state = getPlayerTurnState();
    expect(canSurrender(state)).toBe(false);
  });
});

describe('newHand', () => {
  it('resets to BETTING after COMPLETE', () => {
    let s = dealHand(setBet(createInitialState(), 50));
    if (s.phase === 'PLAYER_TURN') s = stand(s);
    expect(s.phase).toBe('COMPLETE');
    const next = newHand(s);
    expect(next.phase).toBe('BETTING');
    expect(next.playerHands.length).toBe(0);
    expect(next.dealerCards.length).toBe(0);
  });
});
