import { describe, it, expect } from 'vitest';
import { getOptimalAction } from '../strategy.js';
import { VEGAS_STRIP } from '../variants.js';
import type { Card } from '../cards.js';

function card(rank: Card['rank']): Card {
  return { rank, suit: '♠', faceDown: false };
}

const rules = VEGAS_STRIP;
const lateRules = { ...VEGAS_STRIP, surrender: 'late' as const };

describe('getOptimalAction — hard totals', () => {
  it('stands hard 17 vs dealer 7', () => {
    const result = getOptimalAction([card('10'), card('7')], card('7'), rules);
    expect(result.action).toBe('S');
  });

  it('hits hard 16 vs dealer A (no surrender)', () => {
    const result = getOptimalAction([card('10'), card('6')], card('A'), rules);
    expect(result.action).toBe('H');
  });

  it('hits hard 12 vs dealer 2', () => {
    const result = getOptimalAction([card('10'), card('2')], card('2'), rules);
    expect(result.action).toBe('H');
  });

  it('stands hard 13 vs dealer 5', () => {
    const result = getOptimalAction([card('10'), card('3')], card('5'), rules);
    expect(result.action).toBe('S');
  });

  it('doubles hard 11 vs dealer 6', () => {
    const result = getOptimalAction([card('6'), card('5')], card('6'), rules);
    expect(result.action).toBe('D');
  });

  it('doubles hard 10 vs dealer 9', () => {
    const result = getOptimalAction([card('6'), card('4')], card('9'), rules);
    expect(result.action).toBe('D');
  });

  it('hits hard 9 vs dealer 2', () => {
    const result = getOptimalAction([card('5'), card('4')], card('2'), rules);
    expect(result.action).toBe('H');
  });

  it('surrenders hard 16 vs dealer 9 (late surrender enabled)', () => {
    const result = getOptimalAction([card('9'), card('7')], card('9'), lateRules);
    expect(result.action).toBe('R');
  });
});

describe('getOptimalAction — soft totals', () => {
  it('stands soft 18 vs dealer 7', () => {
    const result = getOptimalAction([card('A'), card('7')], card('7'), rules);
    expect(result.action).toBe('S');
  });

  it('hits soft 18 vs dealer 9', () => {
    const result = getOptimalAction([card('A'), card('7')], card('9'), rules);
    expect(result.action).toBe('H');
  });

  it('doubles soft 17 vs dealer 3', () => {
    const result = getOptimalAction([card('A'), card('6')], card('3'), rules);
    expect(result.action).toBe('D');
  });

  it('stands soft 19', () => {
    const result = getOptimalAction([card('A'), card('8')], card('6'), rules);
    expect(result.action).toBe('S');
  });

  it('hits soft 13 vs dealer 2', () => {
    const result = getOptimalAction([card('A'), card('2')], card('2'), rules);
    expect(result.action).toBe('H');
  });
});

describe('getOptimalAction — pairs', () => {
  it('always splits aces', () => {
    const result = getOptimalAction([card('A'), card('A')], card('6'), rules);
    expect(result.action).toBe('P');
  });

  it('always splits 8s', () => {
    const result = getOptimalAction([card('8'), card('8')], card('A'), rules);
    expect(result.action).toBe('P');
  });

  it('never splits 10s', () => {
    const result = getOptimalAction([card('10'), card('10')], card('5'), rules);
    expect(result.action).toBe('S');
  });

  it('splits 9s vs dealer 9', () => {
    const result = getOptimalAction([card('9'), card('9')], card('9'), rules);
    expect(result.action).toBe('P');
  });

  it('does not split 9s vs dealer 7', () => {
    const result = getOptimalAction([card('9'), card('9')], card('7'), rules);
    expect(result.action).toBe('S');
  });

  it('treats face cards as 10-pair', () => {
    const result = getOptimalAction([card('K'), card('Q')], card('5'), rules);
    expect(result.action).toBe('S');
  });
});

describe('getOptimalAction — surrender fallback', () => {
  it('returns surrender when late surrender is enabled', () => {
    const result = getOptimalAction([card('10'), card('6')], card('A'), lateRules);
    expect(result.action).toBe('R');
  });

  it('falls back to hit when surrender is none — hard 16 vs A', () => {
    const result = getOptimalAction([card('10'), card('6')], card('A'), rules);
    expect(result.action).toBe('H');
  });

  it('falls back to stand when surrender is none — hard 17 vs A', () => {
    const result = getOptimalAction([card('10'), card('7')], card('A'), rules);
    expect(result.action).toBe('S');
  });
});

describe('getOptimalAction — high totals (21)', () => {
  it('stands on soft 21 vs dealer Ace', () => {
    // A + 7 + 3 = soft 21 — was incorrectly returning Hit
    const result = getOptimalAction([card('A'), card('7'), card('3')], card('A'), rules);
    expect(result.action).toBe('S');
  });

  it('stands on soft 21 vs dealer 10', () => {
    const result = getOptimalAction([card('A'), card('6'), card('4')], card('10'), rules);
    expect(result.action).toBe('S');
  });

  it('stands on hard 21 vs dealer Ace', () => {
    const result = getOptimalAction([card('7'), card('7'), card('7')], card('A'), rules);
    expect(result.action).toBe('S');
  });

  it('stands on soft 20 vs dealer Ace', () => {
    const result = getOptimalAction([card('A'), card('9')], card('A'), rules);
    expect(result.action).toBe('S');
  });
});

describe('explanation text', () => {
  it('returns non-empty explanation', () => {
    const result = getOptimalAction([card('8'), card('8')], card('6'), rules);
    expect(result.explanation.length).toBeGreaterThan(10);
  });
});
