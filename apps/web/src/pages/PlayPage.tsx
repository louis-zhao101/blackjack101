import { useEffect } from 'react';
import { useOutletContext } from 'react-router-dom';
import { GameTable } from '../components/game/GameTable.js';
import { StrategyChart } from '../components/learn/StrategyChart.js';
import { useSettingsStore } from '../store/settingsStore.js';
import { useGameStore } from '../store/gameStore.js';
import { useStatsStore } from '../store/statsStore.js';

type PlayOutletContext = { showChart: boolean; setShowChart: (v: boolean | ((p: boolean) => boolean)) => void };

export function PlayPage() {
  const { showChart, setShowChart } = useOutletContext<PlayOutletContext>();
  const { game } = useGameStore();
  const { startSession, currentSession } = useStatsStore();
  const { ruleSet } = useSettingsStore();

  useEffect(() => {
    if (!currentSession) {
      startSession(game.bankroll, ruleSet.id);
    }
  }, []);

  return (
    <div className="play-page">
      <div className="play-layout">
        <GameTable />

        {showChart && (
          <aside
            id="strategy-chart-panel"
            className="chart-sidebar animate-fade-in"
            aria-label="Basic strategy reference chart"
          >
            <div className="chart-sidebar__header">
              <h2>Basic Strategy</h2>
              <button
                className="btn btn--ghost btn--sm"
                onClick={() => setShowChart(false)}
                aria-label="Close strategy chart"
              >
                ✕
              </button>
            </div>
            <StrategyChart />
          </aside>
        )}
      </div>
    </div>
  );
}
