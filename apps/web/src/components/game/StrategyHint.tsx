import { useState } from 'react';
import type { LastHandInfo } from '../../store/gameStore.js';

const ACTION_NAMES: Record<string, string> = {
  H: 'Hit', S: 'Stand', D: 'Double Down', P: 'Split', R: 'Surrender',
};

interface Props {
  info: LastHandInfo;
}

export function StrategyHint({ info }: Props) {
  const [open, setOpen] = useState(false);
  const { optimal, playerAction, wasCorrect } = info;

  return (
    <div
      className="strategy-hint"
      onMouseEnter={() => setOpen(true)}
      onMouseLeave={() => setOpen(false)}
    >
      <button
        className={`strategy-hint__trigger ${wasCorrect ? 'strategy-hint__trigger--correct' : 'strategy-hint__trigger--incorrect'}`}
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        aria-label="View strategy explanation"
      >
        <span className="strategy-hint__icon" aria-hidden="true">
          {wasCorrect ? '✓' : '✕'}
        </span>
        <span>{wasCorrect ? 'Optimal play' : 'See optimal play'}</span>
      </button>

      {open && (
        <div className="strategy-hint__popup animate-fade-in" role="tooltip">
          {!wasCorrect && (
            <div className="hint-comparison">
              <span className="hint-comparison__played">
                You: <strong>{ACTION_NAMES[playerAction] ?? playerAction}</strong>
              </span>
              <span className="hint-comparison__arrow" aria-hidden="true">→</span>
              <span className="hint-comparison__optimal">
                Best: <strong>{ACTION_NAMES[optimal.action] ?? optimal.action}</strong>
              </span>
            </div>
          )}
          <p className="hint-explanation">{optimal.explanation}</p>
        </div>
      )}
    </div>
  );
}
