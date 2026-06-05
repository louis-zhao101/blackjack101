import { useGameStore } from '../../store/gameStore.js';

const CHIP_DENOMINATIONS = [5, 25, 100, 500] as const;

const CHIP_COLORS: Record<number, string> = {
  5: 'chip-5',
  25: 'chip-25',
  100: 'chip-100',
  500: 'chip-500',
};

interface Props {
  bankroll: number;
  pendingBet: number;
}

export function BetPanel({ bankroll, pendingBet }: Props) {
  const { placeBetChip, clearBet: doClearBet, deal, topUp } = useGameStore();

  return (
    <div className="bet-panel">
      <div className="bet-panel__chips">
        {CHIP_DENOMINATIONS.map((denom) => (
          <button
            key={denom}
            className={`chip ${CHIP_COLORS[denom]}`}
            onClick={() => placeBetChip(denom)}
            disabled={bankroll < denom || pendingBet + denom > bankroll}
            aria-label={`Add $${denom} chip`}
          >
            ${denom}
          </button>
        ))}
      </div>

      <div className="bet-panel__info">
        <div className="bet-display">
          <span className="bet-display__label">Bet</span>
          <span className="bet-display__amount">${pendingBet}</span>
        </div>
        <div className="bankroll-display">
          <span className="bankroll-display__label">Bankroll</span>
          <span className="bankroll-display__amount">${bankroll}</span>
        </div>
      </div>

      <div className="bet-panel__actions">
        <button
          className="btn btn--ghost btn--sm"
          onClick={doClearBet}
          disabled={pendingBet === 0}
          aria-label="Clear bet"
        >
          Clear
        </button>
        <button
          className="btn btn--primary btn--lg"
          onClick={deal}
          disabled={pendingBet < 1}
          aria-label="Deal cards"
        >
          Deal
        </button>
      </div>

      <button
        className="btn btn--ghost btn--sm"
        onClick={() => topUp(500)}
        aria-label="Add $500 to bankroll"
      >
        + Add $500
      </button>
    </div>
  );
}
