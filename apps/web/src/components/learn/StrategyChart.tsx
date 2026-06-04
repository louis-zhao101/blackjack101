import { useState } from 'react';
import { getChartAction, type Action } from '@blackjack101/core';
import type { Card } from '@blackjack101/core';
import { useSettingsStore } from '../../store/settingsStore.js';

type DealerRank = Card['rank'];

const DEALER_RANKS: DealerRank[] = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];
const HARD_TOTALS = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
const SOFT_TOTALS = [13, 14, 15, 16, 17, 18, 19, 20];
const PAIR_RANKS: DealerRank[] = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'A'];

const ACTION_COLORS: Record<Action, string> = {
  H: 'chart-cell--hit',
  S: 'chart-cell--stand',
  D: 'chart-cell--double',
  P: 'chart-cell--split',
  R: 'chart-cell--surrender',
};

const ACTION_LABELS: Record<Action, string> = {
  H: 'H',
  S: 'S',
  D: 'D',
  P: 'P',
  R: 'R',
};

const ACTION_FULL: Record<Action, string> = {
  H: 'Hit',
  S: 'Stand',
  D: 'Double',
  P: 'Split',
  R: 'Surrender',
};

function softLabel(total: number): string {
  const other = total - 11;
  return `A,${other}`;
}

function pairLabel(rank: DealerRank): string {
  return `${rank},${rank}`;
}

type ChartTab = 'hard' | 'soft' | 'pair';

interface CellInfo {
  tab: ChartTab;
  playerValue: number | string;
  dealerRank: DealerRank;
  action: Action;
}

export function StrategyChart() {
  const [activeTab, setActiveTab] = useState<ChartTab>('hard');
  const [selectedCell, setSelectedCell] = useState<CellInfo | null>(null);
  const { ruleSet } = useSettingsStore();
  const surrenderAllowed = ruleSet.surrender !== 'none';

  function handleCellClick(tab: ChartTab, playerValue: number | string, dealerRank: DealerRank) {
    const action = getChartAction(tab, playerValue, dealerRank, surrenderAllowed);
    setSelectedCell({ tab, playerValue, dealerRank, action });
  }

  return (
    <div className="strategy-chart">
      <div className="chart-tabs" role="tablist">
        {(['hard', 'soft', 'pair'] as ChartTab[]).map((tab) => (
          <button
            key={tab}
            role="tab"
            aria-selected={activeTab === tab}
            className={`chart-tab ${activeTab === tab ? 'chart-tab--active' : ''}`}
            onClick={() => setActiveTab(tab)}
          >
            {tab === 'hard' ? 'Hard Totals' : tab === 'soft' ? 'Soft Totals' : 'Pairs'}
          </button>
        ))}
      </div>

      <div className="chart-legend">
        {(Object.entries(ACTION_FULL) as [Action, string][])
          .filter(([a]) => a !== 'R' || surrenderAllowed)
          .map(([a, label]) => (
            <div key={a} className="legend-item">
              <span className={`legend-swatch legend-swatch--${a === 'H' ? 'hit' : a === 'S' ? 'stand' : a === 'D' ? 'double' : a === 'P' ? 'split' : 'surrender'}`} />
              <span>{a} = {label}</span>
            </div>
          ))}
      </div>

      <div className="chart-scroll-wrapper">
        <table className="strategy-table" role="grid" aria-label={`${activeTab} strategy chart`}>
          <thead>
            <tr>
              <th scope="col" className="chart-header-cell chart-header-cell--corner">
                {activeTab === 'pair' ? 'Pair' : activeTab === 'soft' ? 'Soft' : 'Hard'}
              </th>
              {DEALER_RANKS.map((r) => (
                <th scope="col" key={r} className="chart-header-cell">
                  {r}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {activeTab === 'hard' &&
              HARD_TOTALS.map((total) => (
                <tr key={total}>
                  <th scope="row" className="chart-row-header">{total}</th>
                  {DEALER_RANKS.map((dr) => {
                    const action = getChartAction('hard', total, dr, surrenderAllowed);
                    return (
                      <td
                        key={dr}
                        className={`chart-cell ${ACTION_COLORS[action]} ${selectedCell?.playerValue === total && selectedCell.dealerRank === dr ? 'chart-cell--selected' : ''}`}
                        onClick={() => handleCellClick('hard', total, dr)}
                        role="button"
                        tabIndex={0}
                        onKeyDown={(e) => e.key === 'Enter' && handleCellClick('hard', total, dr)}
                        aria-label={`Hard ${total} vs dealer ${dr}: ${ACTION_FULL[action]}`}
                      >
                        {ACTION_LABELS[action]}
                      </td>
                    );
                  })}
                </tr>
              ))}

            {activeTab === 'soft' &&
              SOFT_TOTALS.map((total) => (
                <tr key={total}>
                  <th scope="row" className="chart-row-header">{softLabel(total)}</th>
                  {DEALER_RANKS.map((dr) => {
                    const action = getChartAction('soft', total, dr, surrenderAllowed);
                    return (
                      <td
                        key={dr}
                        className={`chart-cell ${ACTION_COLORS[action]} ${selectedCell?.playerValue === total && selectedCell.dealerRank === dr ? 'chart-cell--selected' : ''}`}
                        onClick={() => handleCellClick('soft', total, dr)}
                        role="button"
                        tabIndex={0}
                        onKeyDown={(e) => e.key === 'Enter' && handleCellClick('soft', total, dr)}
                        aria-label={`Soft ${total} vs dealer ${dr}: ${ACTION_FULL[action]}`}
                      >
                        {ACTION_LABELS[action]}
                      </td>
                    );
                  })}
                </tr>
              ))}

            {activeTab === 'pair' &&
              PAIR_RANKS.map((rank) => (
                <tr key={rank}>
                  <th scope="row" className="chart-row-header">{pairLabel(rank)}</th>
                  {DEALER_RANKS.map((dr) => {
                    const action = getChartAction('pair', rank, dr, surrenderAllowed);
                    return (
                      <td
                        key={dr}
                        className={`chart-cell ${ACTION_COLORS[action]} ${selectedCell?.playerValue === rank && selectedCell.dealerRank === dr ? 'chart-cell--selected' : ''}`}
                        onClick={() => handleCellClick('pair', rank, dr)}
                        role="button"
                        tabIndex={0}
                        onKeyDown={(e) => e.key === 'Enter' && handleCellClick('pair', rank, dr)}
                        aria-label={`Pair of ${rank}s vs dealer ${dr}: ${ACTION_FULL[action]}`}
                      >
                        {ACTION_LABELS[action]}
                      </td>
                    );
                  })}
                </tr>
              ))}
          </tbody>
        </table>
      </div>

      {selectedCell && (
        <div className="chart-tooltip animate-fade-in" role="status">
          <button
            className="chart-tooltip__close"
            onClick={() => setSelectedCell(null)}
            aria-label="Close explanation"
          >
            ✕
          </button>
          <div className="chart-tooltip__header">
            <span className={`chart-cell chart-cell--mini ${ACTION_COLORS[selectedCell.action]}`}>
              {ACTION_LABELS[selectedCell.action]}
            </span>
            <strong>
              {ACTION_FULL[selectedCell.action]}
              {' — '}
              {selectedCell.tab === 'pair'
                ? `Pair of ${selectedCell.playerValue}s`
                : selectedCell.tab === 'soft'
                ? `Soft ${selectedCell.playerValue}`
                : `Hard ${selectedCell.playerValue}`}
              {' vs dealer '}
              {selectedCell.dealerRank}
            </strong>
          </div>
        </div>
      )}
    </div>
  );
}
