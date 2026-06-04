export type BlackjackPayout = '3:2' | '6:5' | '1:1';

export interface RuleSet {
  id: string;
  name: string;
  numDecks: number;
  dealerHitsSoft17: boolean;
  doubleAfterSplit: boolean;
  resplitAces: boolean;
  surrender: 'none' | 'late' | 'early';
  blackjackPays: BlackjackPayout;
  maxSplits: number;
}

export const VEGAS_STRIP: RuleSet = {
  id: 'vegas-strip',
  name: 'Vegas Strip',
  numDecks: 6,
  dealerHitsSoft17: false,
  doubleAfterSplit: true,
  resplitAces: false,
  surrender: 'none',
  blackjackPays: '3:2',
  maxSplits: 3,
};

export const RULE_PRESETS: RuleSet[] = [VEGAS_STRIP];

export function blackjackPayoutMultiplier(payout: BlackjackPayout): number {
  if (payout === '3:2') return 1.5;
  if (payout === '6:5') return 1.2;
  return 1;
}
