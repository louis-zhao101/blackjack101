import { useStatsStore } from '../store/statsStore.js';
import { summarizeSession, getCommonMistakes } from '@blackjack101/core';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  BarChart, Bar, Cell,
} from 'recharts';

const ACTION_NAMES: Record<string, string> = {
  H: 'Hit', S: 'Stand', D: 'Double', P: 'Split', R: 'Surrender',
};

export function StatsPage() {
  const { sessions, clearHistory } = useStatsStore();

  if (sessions.length === 0) {
    return (
      <div className="stats-page">
        <div className="stats-empty">
          <h1>Statistics</h1>
          <p>Play some hands to see your stats here.</p>
        </div>
      </div>
    );
  }

  const summaries = sessions.map(summarizeSession).reverse();
  const mistakes = getCommonMistakes(sessions);

  const accuracyData = summaries.map((s, i) => ({
    name: `Session ${i + 1}`,
    accuracy: s.correctPct,
    hands: s.handsPlayed,
  }));

  const mistakeData = mistakes.slice(0, 8).map((m) => ({
    label: `${m.soft ? 'Soft ' : m.handType === 'pair' ? 'Pair ' : ''}${m.playerTotal} vs ${m.dealerUpcard}`,
    count: m.count,
    played: ACTION_NAMES[m.playerAction] ?? m.playerAction,
    should: ACTION_NAMES[m.optimalAction] ?? m.optimalAction,
    explanation: m.explanation,
  }));

  const totalHands = summaries.reduce((a, s) => a + s.handsPlayed, 0);
  const allHandsFlat = sessions.flatMap((s) => s.hands);
  const overallAccuracy =
    allHandsFlat.length > 0
      ? Math.round((allHandsFlat.filter((h) => h.wasCorrect).length / allHandsFlat.length) * 100)
      : 0;
  const totalPL = summaries.reduce((a, s) => a + s.profitLoss, 0);

  return (
    <div className="stats-page">
      <div className="stats-header">
        <h1>Your Statistics</h1>
        <button
          className="btn btn--ghost btn--sm"
          onClick={() => {
            if (confirm('Clear all session history?')) clearHistory();
          }}
          aria-label="Clear session history"
        >
          Clear History
        </button>
      </div>

      {/* Summary cards */}
      <div className="stats-summary-grid">
        <div className="summary-card">
          <span className="summary-card__value">{totalHands}</span>
          <span className="summary-card__label">Total Hands</span>
        </div>
        <div className="summary-card">
          <span className={`summary-card__value ${overallAccuracy >= 80 ? 'text-green-400' : overallAccuracy >= 60 ? 'text-yellow-400' : 'text-red-400'}`}>
            {overallAccuracy}%
          </span>
          <span className="summary-card__label">Overall Accuracy</span>
        </div>
        <div className="summary-card">
          <span className={`summary-card__value ${totalPL >= 0 ? 'text-green-400' : 'text-red-400'}`}>
            {totalPL >= 0 ? '+' : ''}{totalPL}
          </span>
          <span className="summary-card__label">Total P&L</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__value">{sessions.length}</span>
          <span className="summary-card__label">Sessions</span>
        </div>
      </div>

      {/* Accuracy chart */}
      {accuracyData.length > 1 && (
        <div className="stats-chart-section">
          <h2>Accuracy Over Sessions</h2>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height={220}>
              <LineChart data={accuracyData} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2d7a53" />
                <XAxis dataKey="name" stroke="#9ca3af" tick={{ fontSize: 12 }} />
                <YAxis domain={[0, 100]} stroke="#9ca3af" tick={{ fontSize: 12 }} unit="%" />
                <Tooltip
                  contentStyle={{ background: '#122e20', border: '1px solid #2d7a53', borderRadius: 8 }}
                  labelStyle={{ color: '#d4a843' }}
                  formatter={(val: number) => [`${val}%`, 'Accuracy']}
                />
                <Line
                  type="monotone"
                  dataKey="accuracy"
                  stroke="#d4a843"
                  strokeWidth={2}
                  dot={{ fill: '#d4a843', r: 4 }}
                  activeDot={{ r: 6 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* Common mistakes */}
      {mistakeData.length > 0 && (
        <div className="stats-chart-section">
          <h2>Most Common Mistakes</h2>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height={260}>
              <BarChart data={mistakeData} margin={{ top: 10, right: 20, left: 0, bottom: 60 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2d7a53" />
                <XAxis
                  dataKey="label"
                  stroke="#9ca3af"
                  tick={{ fontSize: 11, fill: '#9ca3af' }}
                  angle={-35}
                  textAnchor="end"
                  interval={0}
                />
                <YAxis stroke="#9ca3af" tick={{ fontSize: 12 }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ background: '#122e20', border: '1px solid #2d7a53', borderRadius: 8 }}
                  labelStyle={{ color: '#d4a843' }}
                  formatter={(_val: number, _name: string, props: { payload?: { played: string; should: string } }) => [
                    `Played ${props.payload?.played ?? '?'} → Should ${props.payload?.should ?? '?'}`,
                    'Times',
                  ]}
                />
                <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                  {mistakeData.map((_entry, i) => (
                    <Cell key={i} fill="#e74c3c" opacity={0.85} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          <div className="mistakes-detail-list">
            {mistakes.slice(0, 5).map((m, i) => (
              <div key={i} className="mistake-detail-card">
                <div className="mistake-detail-header">
                  <span className="mistake-detail-count">{m.count}×</span>
                  <span className="mistake-detail-title">
                    {m.soft ? 'Soft ' : m.handType === 'pair' ? 'Pair of ' : 'Hard '}
                    {m.playerTotal} vs dealer {m.dealerUpcard}
                  </span>
                  <span className="mistake-detail-actions">
                    Played <strong>{ACTION_NAMES[m.playerAction]}</strong> → should <strong>{ACTION_NAMES[m.optimalAction]}</strong>
                  </span>
                </div>
                <p className="mistake-detail-explanation">{m.explanation}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Session history table */}
      <div className="stats-chart-section">
        <h2>Session History</h2>
        <div className="sessions-table-wrapper">
          <table className="sessions-table" aria-label="Session history">
            <thead>
              <tr>
                <th>Date</th>
                <th>Hands</th>
                <th>Accuracy</th>
                <th>P&L</th>
                <th>Rules</th>
              </tr>
            </thead>
            <tbody>
              {summaries.map((s) => (
                <tr key={s.id}>
                  <td>{new Date(s.date).toLocaleDateString()}</td>
                  <td>{s.handsPlayed}</td>
                  <td>
                    <span className={`accuracy-badge ${s.correctPct >= 80 ? 'accuracy-badge--good' : s.correctPct >= 60 ? 'accuracy-badge--ok' : 'accuracy-badge--warn'}`}>
                      {s.correctPct}%
                    </span>
                  </td>
                  <td className={s.profitLoss >= 0 ? 'text-green-400' : 'text-red-400'}>
                    {s.profitLoss >= 0 ? '+' : ''}{s.profitLoss}
                  </td>
                  <td>{s.ruleSetId}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
