import { Card, handValue } from './cards.js';
import { RuleSet } from './variants.js';

export type Action = 'H' | 'S' | 'D' | 'P' | 'R';

export interface OptimalAction {
  action: Action;
  label: string;
  explanation: string;
  // When action is 'D': correct fallback action if doubling is not available
  doubleFallback: 'H' | 'S';
}

// Dealer upcard index: 2,3,4,5,6,7,8,9,10,A  (index 0–9)
type DealerIndex = 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;

function dealerIndex(rank: Card['rank']): DealerIndex {
  if (rank === 'A') return 9;
  if (rank === 'J' || rank === 'Q' || rank === 'K') return 8;
  return (parseInt(rank, 10) - 2) as DealerIndex;
}

// Hard totals: 8–17 vs dealer 2–A (index 0–9)
// R = Surrender (with fallback handled below)
const HARD: Record<number, Action[]> = {
  //         2    3    4    5    6    7    8    9   10    A
   8: ['H', 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H', 'H'],
   9: ['H', 'D', 'D', 'D', 'D', 'H', 'H', 'H', 'H', 'H'],
  10: ['D', 'D', 'D', 'D', 'D', 'D', 'D', 'D', 'H', 'H'],
  11: ['D', 'D', 'D', 'D', 'D', 'D', 'D', 'D', 'D', 'H'],
  12: ['H', 'H', 'S', 'S', 'S', 'H', 'H', 'H', 'H', 'H'],
  13: ['S', 'S', 'S', 'S', 'S', 'H', 'H', 'H', 'H', 'H'],
  14: ['S', 'S', 'S', 'S', 'S', 'H', 'H', 'H', 'H', 'H'],
  15: ['S', 'S', 'S', 'S', 'S', 'H', 'H', 'H', 'R', 'R'],
  16: ['S', 'S', 'S', 'S', 'S', 'H', 'H', 'R', 'R', 'R'],
  17: ['S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'R'],
};

// Soft totals (A + X): totals 13–20 vs dealer 2–A
// 'Ds' = Double or Stand (fallback to stand, not hit)
type SoftEntry = Action | 'Ds';

const SOFT: Record<number, SoftEntry[]> = {
  //          2     3     4     5     6     7     8     9    10     A
  13: [ 'H',  'H',  'H',  'D',  'D',  'H',  'H',  'H',  'H',  'H'],  // A,2
  14: [ 'H',  'H',  'H',  'D',  'D',  'H',  'H',  'H',  'H',  'H'],  // A,3
  15: [ 'H',  'H',  'D',  'D',  'D',  'H',  'H',  'H',  'H',  'H'],  // A,4
  16: [ 'H',  'H',  'D',  'D',  'D',  'H',  'H',  'H',  'H',  'H'],  // A,5
  17: [ 'H',  'D',  'D',  'D',  'D',  'H',  'H',  'H',  'H',  'H'],  // A,6
  18: [ 'S', 'Ds', 'Ds', 'Ds', 'Ds',  'S',  'S',  'H',  'H',  'H'],  // A,7 — vs 3-6: Ds (double or stand)
  19: [ 'S',  'S',  'S',  'S',  'S',  'S',  'S',  'S',  'S',  'S'],  // A,8
  20: [ 'S',  'S',  'S',  'S',  'S',  'S',  'S',  'S',  'S',  'S'],  // A,9
};

// Pairs: pair rank vs dealer 2–A
const PAIRS: Record<string, Action[]> = {
  //         2    3    4    5    6    7    8    9   10    A
   '2': ['P', 'P', 'P', 'P', 'P', 'P', 'H', 'H', 'H', 'H'],
   '3': ['P', 'P', 'P', 'P', 'P', 'P', 'H', 'H', 'H', 'H'],
   '4': ['H', 'H', 'H', 'P', 'P', 'H', 'H', 'H', 'H', 'H'],
   '5': ['D', 'D', 'D', 'D', 'D', 'D', 'D', 'D', 'H', 'H'],
   '6': ['P', 'P', 'P', 'P', 'P', 'H', 'H', 'H', 'H', 'H'],
   '7': ['P', 'P', 'P', 'P', 'P', 'P', 'H', 'H', 'H', 'H'],
   '8': ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P', 'P', 'P'],
   '9': ['P', 'P', 'P', 'P', 'P', 'S', 'P', 'P', 'S', 'S'],
  '10': ['S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S', 'S'],
   'A': ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P', 'P', 'P'],
};

const ACTION_LABELS: Record<Action, string> = {
  H: 'Hit',
  S: 'Stand',
  D: 'Double',
  P: 'Split',
  R: 'Surrender',
};

function pairKey(rank: Card['rank']): string {
  if (rank === 'J' || rank === 'Q' || rank === 'K') return '10';
  return rank;
}

function d(dealerRank: Card['rank']): string {
  return dealerRank === 'A' ? 'Ace' : dealerRank;
}

function hardExplanation(total: number, dealerRank: Card['rank'], action: Action): string {
  const dr = d(dealerRank);
  const bustCards = 'About 31% of cards are 10-value (10, J, Q, K)';

  switch (action) {
    case 'S':
      if (total >= 17) {
        return `Stand on hard ${total} — always stand on hard 17 or higher. Any hit risks busting, and 17 wins or pushes against a large portion of dealer outcomes.`;
      }
      if (total === 12) {
        return `Stand on 12 vs dealer ${dr} — dealer ${dr} is a bust card. Dealers showing 4, 5, or 6 must draw through stiff hands and bust over 40% of the time. Your 12 risks busting on a 10-value hit, so let the dealer take that risk.`;
      }
      return `Stand on ${total} vs dealer ${dr} — dealer ${dr} is a bust card. Dealers showing 2-6 are forced to draw through stiff totals and bust more than 35% of the time. Don't risk busting your own hand when the dealer is already in trouble.`;

    case 'H':
      if (total <= 8) {
        return `Hit on ${total} — you cannot bust with one hit, and any card improves your position. Always draw when you can't bust.`;
      }
      if (total === 9) {
        return `Hit on 9 vs dealer ${dr} — the dealer is too strong to double here. Take a card and aim for a solid total without risking extra money in an unfavorable spot.`;
      }
      if (total === 11) {
        return `Hit on 11 vs dealer Ace — in a multi-deck game, doubling on 11 vs an Ace is not profitable. The dealer's Ace is very strong. Hit and take a free card to reach a competitive total.`;
      }
      if (total === 12) {
        return `Hit on 12 vs dealer ${dr} — 12 is too weak to stand against a strong dealer. ${bustCards} would bust you on a hit, but that leaves 69% of cards that improve your hand. The dealer's ${dr} completes a strong hand most of the time.`;
      }
      if (total <= 16) {
        return `Hit on ${total} vs dealer ${dr} — dealer ${dr} will complete a strong hand most of the time. Standing on ${total} means you'll lose whenever the dealer makes 17 or better. You must draw to compete, even at the risk of busting.`;
      }
      return `Hit — improve your total.`;

    case 'D':
      if (total === 9) {
        return `Double down on 9 vs dealer ${dr} — the dealer is showing a weak bust card. A 10-value card gives you 19, and even smaller cards leave you competitive. Put more money on the table when the odds are in your favor.`;
      }
      if (total === 10) {
        return `Double down on 10 vs dealer ${dr} — 10 is a powerful doubling hand. ${bustCards} gives you 20, and most other cards keep you competitive. The dealer's ${dr} means they're more likely to bust or make a weaker hand.`;
      }
      if (total === 11) {
        return `Double down on 11 vs dealer ${dr} — 11 is the strongest doubling hand in blackjack. ${bustCards} gives you 21, which the dealer can only match with a blackjack. This is the highest expected-value double in the game.`;
      }
      return `Double down on ${total} vs dealer ${dr} — you're in a favorable position and the dealer is weak. Doubling your bet maximizes your return when the odds favor you.`;

    case 'R':
      return `Surrender on ${total} vs dealer ${dr} — your hand is in a very unfavorable position. Giving up half your bet is more profitable than playing out a hand where you're expected to lose more than 50 cents per dollar.`;

    default:
      return '';
  }
}

function softExplanation(total: number, dealerRank: Card['rank'], action: Action, isDs = false): string {
  const dr = d(dealerRank);
  const otherCard = total - 11;
  const handLabel = `soft ${total} (A-${otherCard})`;

  switch (action) {
    case 'S':
      if (total >= 19) {
        return `Stand on ${handLabel} — soft 19 and 20 are strong hands. Always stand and let the dealer try to beat you.`;
      }
      if (dealerRank === '2') {
        return `Stand on ${handLabel} vs dealer 2 — dealer 2 is weak, but not weak enough to profitably double. Your 18 is already a solid hand. Stand and win or push most of the time.`;
      }
      if (dealerRank === '7' || dealerRank === '8') {
        return `Stand on ${handLabel} vs dealer ${dr} — your 18 ties or beats the dealer's most likely total. Dealer 7 makes 17 most often (push or you win), and dealer 8 makes 18 most often (push). Standing is the correct play.`;
      }
      return `Stand on ${handLabel} vs dealer ${dr} — your hand is strong enough to stand. The ace gives you flexibility, but you're already in a good position.`;

    case 'H':
      if (total === 18) {
        return `Hit on ${handLabel} vs dealer ${dr} — even though 18 is a decent total, the dealer's ${dr} completes a hand of 19, 20, or 21 most of the time. You need to improve. Your ace means you can't bust: a 10 turns your A-7 into a hard 17, which you'd then stand on.`;
      }
      return `Hit on ${handLabel} vs dealer ${dr} — your total is too low to stand, and the dealer has a strong upcard. You can't bust on this hit because of the ace — a 10 just converts it to a lower hard total.`;

    case 'D':
      if (total === 18 && isDs) {
        return `Double down on ${handLabel} vs dealer ${dr} — the dealer is showing one of the weakest upcards (${dr} busts over 40% of the time). Even though 18 is solid, doubling is more profitable here. If you can't double, stand — don't hit.`;
      }
      return `Double down on ${handLabel} vs dealer ${dr} — the dealer is weak and likely to bust. Your ace protects you: if you draw a 10, you drop to a hard total instead of busting. Double your bet when the math favors you.`;

    default:
      return '';
  }
}

function pairExplanation(rank: string, dealerRank: Card['rank'], action: Action): string {
  const dr = d(dealerRank);
  const display = rank === 'A' ? 'Aces' : `${rank}s`;
  const total = rank === 'A' ? 12 : Number(rank) * 2;

  switch (action) {
    case 'P':
      if (rank === 'A') {
        return `Always split Aces — paired Aces total 12 (or 2), a weak hand. Each Ace as a starting card gives you a ~31% chance of reaching 21 on just one more card. This is always the right play, regardless of what the dealer shows.`;
      }
      if (rank === '8') {
        return `Always split 8s — a pair of 8s totals 16, the worst possible hand in blackjack. Splitting gives you two fresh starts, each beginning with 8 — a neutral base that can reach a competitive total. Splitting is less costly than playing hard 16 in every situation.`;
      }
      if (rank === '9') {
        return `Split 9s vs dealer ${dr} — your 18 is already good, but two hands starting at 9 can each reach 18 or higher. The dealer's ${dr} is weak enough that two separate bets outperform one hand of 18.`;
      }
      if (rank === '7') {
        return `Split 7s vs dealer ${dr} — hard 14 is a losing hand against most dealers, but two hands starting with 7 can each improve significantly. The dealer's ${dr} is weak enough to justify splitting.`;
      }
      if (rank === '6') {
        return `Split 6s vs dealer ${dr} — hard 12 is a trouble hand. Splitting into two 6-starting hands gives you two chances to build competitive totals against a dealer likely to bust.`;
      }
      if (rank === '4') {
        return `Split 4s vs dealer ${dr} — dealer 5 and 6 are the weakest upcards in the deck, with bust rates over 40%. Splitting 4s into two hands starting at 4 is profitable specifically against these two dealer cards.`;
      }
      return `Split ${display} vs dealer ${dr} — splitting turns a weak combined total into two hands with better starting positions. The dealer's ${dr} is weak enough to make this a profitable split.`;

    case 'S':
      if (rank === '10') {
        return `Never split 10s — a total of 20 wins against almost every dealer outcome. Splitting 10s throws away a near-guaranteed winner to chase two unknowns. No matter what the dealer shows, keep your 20.`;
      }
      if (rank === '9') {
        return `Stand on 9s vs dealer ${dr} — your 18 is already beating the dealer's most likely outcome. Dealer 7 usually makes 17 (you win), and dealer 10 or Ace is strong enough that splitting would just give them two chances to beat you.`;
      }
      return `Don't split ${display} vs dealer ${dr} — the dealer is too strong here. Play the pair as a single hand instead of giving the dealer two chances to beat you.`;

    case 'H':
      if (rank === '2' || rank === '3') {
        return `Don't split ${display} vs dealer ${dr} — the dealer is too strong (${dr}) to justify splitting. Hit the combined total (${total}) instead of creating two weak starting hands against a strong dealer.`;
      }
      if (rank === '6') {
        return `Don't split 6s vs dealer ${dr} — hard 12 with a 6 start isn't worth splitting against a strong dealer. Hit the 12 instead.`;
      }
      return `Don't split ${display} vs dealer ${dr} — hitting the total of ${total} is better than splitting into two weak hands here.`;

    case 'D':
      return `Don't split 5s — treat them as a hard 10 and double down. A pair of 5s split into two hands each starting at 5 is weak. A doubled hard 10 vs dealer ${dr} has a much higher expected value.`;

    default:
      return '';
  }
}

function isPair(cards: Card[]): string | null {
  if (cards.length !== 2) return null;
  const [c1, c2] = cards;
  if (!c1 || !c2) return null;
  const k1 = pairKey(c1.rank);
  const k2 = pairKey(c2.rank);
  return k1 === k2 ? k1 : null;
}

export function getOptimalAction(
  playerCards: Card[],
  dealerUpcard: Card,
  ruleSet: RuleSet
): OptimalAction {
  const di = dealerIndex(dealerUpcard.rank);
  const pairK = isPair(playerCards);
  const { total, soft } = handValue(playerCards);

  let rawAction: Action;
  let explanation: string;
  let doubleFallback: 'H' | 'S' = 'H';

  if (pairK && playerCards.length === 2) {
    const row = PAIRS[pairK];
    rawAction = (row?.[di] ?? 'H') as Action;
    explanation = pairExplanation(pairK, dealerUpcard.rank, rawAction);
    if (rawAction === 'D') doubleFallback = 'H';
  } else if (soft && total >= 13 && total <= 20) {
    const row = SOFT[total];
    const rawSoft = (row?.[di] ?? 'H') as SoftEntry;
    const isDs = rawSoft === 'Ds';
    rawAction = isDs ? 'D' : (rawSoft as Action);
    doubleFallback = isDs ? 'S' : 'H';
    explanation = softExplanation(total, dealerUpcard.rank, rawAction, isDs);
  } else {
    const clampedTotal = Math.min(Math.max(total, 8), 17);
    const row = HARD[clampedTotal];
    rawAction = (row?.[di] ?? (total >= 17 ? 'S' : 'H')) as Action;
    explanation = hardExplanation(total, dealerUpcard.rank, rawAction);
    if (rawAction === 'D') doubleFallback = 'H';
  }

  // Resolve surrender fallback when surrender is not allowed
  let action = rawAction;
  if (action === 'R' && ruleSet.surrender === 'none') {
    // Hard 17 vs A falls back to Stand; 15/16 fall back to Hit
    action = !soft && total >= 17 ? 'S' : 'H';
    explanation = pairK
      ? pairExplanation(pairK, dealerUpcard.rank, action)
      : soft
      ? softExplanation(total, dealerUpcard.rank, action)
      : hardExplanation(total, dealerUpcard.rank, action);
  }

  return { action, label: ACTION_LABELS[action], explanation, doubleFallback };
}

// Returns action for the strategy chart UI. Pass surrenderAllowed=false to apply no-surrender fallbacks.
export function getChartAction(
  handType: 'hard' | 'soft' | 'pair',
  playerValue: number | string,
  dealerRank: Card['rank'],
  surrenderAllowed = true
): Action {
  const di = dealerIndex(dealerRank);
  let action: Action;
  if (handType === 'pair') {
    const key = String(playerValue);
    action = (PAIRS[key]?.[di] ?? 'H') as Action;
  } else if (handType === 'soft') {
    const raw = (SOFT[Number(playerValue)]?.[di] ?? 'H') as SoftEntry;
    action = raw === 'Ds' ? 'D' : (raw as Action);
  } else {
    const clamped = Math.min(Math.max(Number(playerValue), 8), 17);
    action = (HARD[clamped]?.[di] ?? (Number(playerValue) >= 17 ? 'S' : 'H')) as Action;
  }
  if (action === 'R' && !surrenderAllowed) {
    return handType === 'hard' && Number(playerValue) >= 17 ? 'S' : 'H';
  }
  return action;
}
