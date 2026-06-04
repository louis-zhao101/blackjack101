import { describe, it, expect } from 'vitest';
import { handValue, isBlackjack, isBust, createDeck, shuffle, dealCard } from '../cards.js';
import type { Card } from '../cards.js';

function card(rank: Card['rank'], suit: Card['suit'] = '♠'): Card {
  return { rank, suit, faceDown: false };
}

describe('handValue', () => {
  it('sums numeric cards', () => {
    expect(handValue([card('7'), card('8')])).toEqual({ total: 15, soft: false });
  });

  it('counts face cards as 10', () => {
    expect(handValue([card('K'), card('Q')])).toEqual({ total: 20, soft: false });
  });

  it('counts ace as 11 when safe', () => {
    expect(handValue([card('A'), card('7')])).toEqual({ total: 18, soft: true });
  });

  it('demotes ace to 1 to avoid bust', () => {
    expect(handValue([card('A'), card('7'), card('8')])).toEqual({ total: 16, soft: false });
  });

  it('handles two aces', () => {
    expect(handValue([card('A'), card('A')])).toEqual({ total: 12, soft: true });
  });

  it('handles blackjack', () => {
    expect(handValue([card('A'), card('K')])).toEqual({ total: 21, soft: true });
  });

  it('soft 18: A+7', () => {
    expect(handValue([card('A'), card('7')])).toEqual({ total: 18, soft: true });
  });

  it('ignores faceDown cards', () => {
    const hidden: Card = { rank: 'K', suit: '♠', faceDown: true };
    expect(handValue([card('7'), hidden])).toEqual({ total: 7, soft: false });
  });

  it('busted hand', () => {
    expect(handValue([card('10'), card('K'), card('5')])).toEqual({ total: 25, soft: false });
  });
});

describe('isBlackjack', () => {
  it('detects A+10', () => expect(isBlackjack([card('A'), card('10')])).toBe(true));
  it('detects A+K', () => expect(isBlackjack([card('A'), card('K')])).toBe(true));
  it('rejects 21 in 3 cards', () => expect(isBlackjack([card('7'), card('7'), card('7')])).toBe(false));
  it('rejects 20', () => expect(isBlackjack([card('K'), card('Q')])).toBe(false));
});

describe('isBust', () => {
  it('returns true for >21', () => expect(isBust([card('10'), card('K'), card('5')])).toBe(true));
  it('returns false for 21', () => expect(isBust([card('A'), card('K')])).toBe(false));
});

describe('createDeck', () => {
  it('creates correct number of cards', () => {
    expect(createDeck(1).length).toBe(52);
    expect(createDeck(6).length).toBe(312);
  });
});

describe('shuffle', () => {
  it('preserves deck size', () => {
    const deck = createDeck(1);
    expect(shuffle(deck).length).toBe(52);
  });

  it('does not mutate original', () => {
    const deck = createDeck(1);
    const original = [...deck];
    shuffle(deck);
    expect(deck).toEqual(original);
  });
});

describe('dealCard', () => {
  it('removes card from deck', () => {
    const deck = createDeck(1);
    const { remaining } = dealCard(deck);
    expect(remaining.length).toBe(51);
  });

  it('sets faceDown correctly', () => {
    const deck = createDeck(1);
    expect(dealCard(deck, true).card.faceDown).toBe(true);
    expect(dealCard(deck, false).card.faceDown).toBe(false);
  });

  it('throws on empty deck', () => {
    expect(() => dealCard([])).toThrow('Deck is empty');
  });
});
