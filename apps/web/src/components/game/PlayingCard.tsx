import type { Card } from '@blackjack101/core';

interface Props {
  card: Card;
  className?: string;
  animateIn?: boolean;
}

const RED_SUITS = new Set(['♥', '♦']);

export function PlayingCard({ card, className = '', animateIn = false }: Props) {
  const isRed = RED_SUITS.has(card.suit);

  if (card.faceDown) {
    return (
      <div
        className={`playing-card playing-card--back ${animateIn ? 'animate-deal-in' : ''} ${className}`}
        aria-label="Face-down card"
      >
        <div className="card-back-pattern" />
      </div>
    );
  }

  return (
    <div
      className={`playing-card ${isRed ? 'playing-card--red' : 'playing-card--black'} ${animateIn ? 'animate-deal-in' : ''} ${className}`}
      aria-label={`${card.rank} of ${card.suit}`}
    >
      <span className="card-corner card-corner--tl">
        <span className="card-rank">{card.rank}</span>
        <span className="card-suit">{card.suit}</span>
      </span>
      <span className="card-center-suit" aria-hidden="true">
        {card.suit}
      </span>
      <span className="card-corner card-corner--br" aria-hidden="true">
        <span className="card-rank">{card.rank}</span>
        <span className="card-suit">{card.suit}</span>
      </span>
    </div>
  );
}
