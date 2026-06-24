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
    case 'lose': return 'Lose';
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

      {/* Total badge — hidden when bust (result badge takes over) */}
      {cards.length > 0 && !hasHiddenCard && !bust && (
        <div className={`bj-hand__total ${soft ? 'bj-hand__total--soft' : ''}`}>
          {soft ? 'Soft ' : ''}{total}
        </div>
      )}

      {/* Bust: single merged badge */}
      {bust && cards.length > 0 && !hasHiddenCard && (
        <div className="result-badge badge--lose">Bust</div>
      )}

      {/* Regular result badge when not bust */}
      {!bust && result && (
        <div className={`result-badge ${resultBadgeClass(result)}`}>
          {resultLabel(result)}
        </div>
      )}
    </div>
  );
}
