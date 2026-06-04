import { useStatsStore } from '../../store/statsStore.js';
import { useGameStore } from '../../store/gameStore.js';

export function StatsBar() {
  const { currentSession } = useStatsStore();
  const { game, playStats } = useGameStore();
  const bankroll = game.bankroll;

  const handsPlayed = currentSession?.hands?.length ?? 0;
  const hasPlays = playStats.total > 0;
  const pct = hasPlays ? Math.round((playStats.correct / playStats.total) * 100) : null;

  return (
    <div className="stats-bar" role="status" aria-label="Session statistics">
      <div className="stats-bar__item">
        <span className="stats-bar__label">Balance</span>
        <span className="stats-bar__value stats-bar__value--gold">${bankroll}</span>
      </div>

      {hasPlays && (
        <>
          <div className="stats-bar__divider" aria-hidden="true" />
          <div className="stats-bar__item">
            <span className="stats-bar__label">Accuracy</span>
            <span className={`stats-bar__value ${pct! >= 80 ? 'stats-bar__value--good' : pct! >= 60 ? 'stats-bar__value--ok' : 'stats-bar__value--warn'}`}>
              {pct}%
            </span>
          </div>
          <div className="stats-bar__divider" aria-hidden="true" />
          <div className="stats-bar__item">
            <span className="stats-bar__label">Hands</span>
            <span className="stats-bar__value">{handsPlayed}</span>
          </div>
          <div className="stats-bar__divider" aria-hidden="true" />
          <div className="stats-bar__item">
            <span className="stats-bar__label">Correct Plays</span>
            <span className="stats-bar__value">{playStats.correct}/{playStats.total}</span>
          </div>
        </>
      )}
    </div>
  );
}
