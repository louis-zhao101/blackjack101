import { useEffect, useState } from 'react';
import { GameTable } from '../components/game/GameTable.js';
import { StrategyChart } from '../components/learn/StrategyChart.js';
import { useSettingsStore } from '../store/settingsStore.js';
import { useGameStore } from '../store/gameStore.js';
import { useStatsStore } from '../store/statsStore.js';

export function PlayPage() {
  const [showChart, setShowChart] = useState(false);
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
      <div className="play-toolbar">
        <div className="play-toolbar__left">
          <span className="toolbar-ruleset-badge">{ruleSet.name}</span>
        </div>
        <div className="play-toolbar__right">
          <button
            className={`btn btn--ghost btn--sm ${showChart ? 'btn--active' : ''}`}
            onClick={() => setShowChart((v) => !v)}
            aria-expanded={showChart}
            aria-controls="strategy-chart-panel"
          >
            Strategy Chart
          </button>
        </div>
      </div>

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
