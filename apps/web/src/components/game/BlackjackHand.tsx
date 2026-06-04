import { handValue, type Card } from '@blackjack101/core';
import { PlayingCard } from './PlayingCard.js';

interface Props {
  cards: Card[];
  label?: string;
  isActive?: boolean;
  result?: string | null;
  bet?: number;
  className?: string;
}

function resultBadgeClass(result: string): string {
  switch (result) {
    case 'blackjack': return 'badge--blackjack';
    case 'win': return 'badge--win';
    case 'push': return 'badge--push';
    case 'lose': return 'badge--lose';
    case 'surrender': return 'badge--surrender';
    default: return 'badge--neutral';
  }
}

function resultLabel(result: string): string {
  switch (result) {
    case 'blackjack': return 'Blackjack!';
    case 'win': return 'Win';
    case 'push': return 'Push';
    case 'lose': return 'Bust' ;
    case 'surrender': return 'Surrender';
    default: return result;
  }
}

export function BlackjackHand({ cards, label, isActive = false, result, bet, className = '' }: Props) {
  const { total, soft } = handValue(cards.filter((c) => !c.faceDown));
  const bust = total > 21;
  const hasHiddenCard = cards.some((c) => c.faceDown);

  return (
    <div className={`bj-hand ${isActive ? 'bj-hand--active' : ''} ${className}`}>
      {isActive && <div className="bj-hand__turn-badge">Your Turn</div>}
      {label && (
        <div className="bj-hand__label">
          {label}
          {bet !== undefined && (
            <span className="bj-hand__bet"> — Bet: ${bet}</span>
          )}
        </div>
      )}

      <div className="bj-hand__cards">
        {cards.map((card, i) => (
          <PlayingCard
            key={`${card.rank}${card.suit}${i}`}
            card={card}
            animateIn={true}
          />
        ))}
      </div>

      {cards.length > 0 && !hasHiddenCard && (
        <div className={`bj-hand__total ${bust ? 'bj-hand__total--bust' : ''} ${soft && !bust ? 'bj-hand__total--soft' : ''}`}>
          {bust ? 'Bust' : `${soft ? 'Soft ' : ''}${total}`}
        </div>
      )}

      {result && (
        <div className={`result-badge ${resultBadgeClass(result)}`}>
          {resultLabel(result)}
        </div>
      )}
    </div>
  );
}
