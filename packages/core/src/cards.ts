export type Rank = '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' | '10' | 'J' | 'Q' | 'K' | 'A';
export type Suit = '♠' | '♥' | '♦' | '♣';

export interface Card {
  rank: Rank;
  suit: Suit;
  faceDown: boolean;
}

export interface HandValue {
  total: number;
  soft: boolean;
}

const RANKS: Rank[] = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K', 'A'];
const SUITS: Suit[] = ['♠', '♥', '♦', '♣'];

export function rankValue(rank: Rank): number {
  if (rank === 'A') return 11;
  if (['J', 'Q', 'K'].includes(rank)) return 10;
  return parseInt(rank, 10);
}

export function handValue(cards: Card[]): HandValue {
  const visibleCards = cards.filter((c) => !c.faceDown);
  let total = 0;
  let aces = 0;

  for (const card of visibleCards) {
    if (card.rank === 'A') {
      aces++;
      total += 11;
    } else {
      total += rankValue(card.rank);
    }
  }

  while (total > 21 && aces > 0) {
    total -= 10;
    aces--;
  }

  return { total, soft: aces > 0 && total <= 21 };
}

export function isBust(cards: Card[]): boolean {
  return handValue(cards).total > 21;
}

export function isBlackjack(cards: Card[]): boolean {
  if (cards.length !== 2) return false;
  const { total } = handValue(cards);
  return total === 21;
}

export function createDeck(numDecks: number): Card[] {
  const deck: Card[] = [];
  for (let d = 0; d < numDecks; d++) {
    for (const suit of SUITS) {
      for (const rank of RANKS) {
        deck.push({ rank, suit, faceDown: false });
      }
    }
  }
  return deck;
}

export function shuffle(deck: Card[]): Card[] {
  const d = [...deck];
  for (let i = d.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    [d[i], d[j]] = [d[j]!, d[i]!];
  }
  return d;
}

export function dealCard(deck: Card[], faceDown = false): { card: Card; remaining: Card[] } {
  if (deck.length === 0) throw new Error('Deck is empty');
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  const card = { ...deck[0]!, faceDown };
  return { card, remaining: deck.slice(1) };
}
