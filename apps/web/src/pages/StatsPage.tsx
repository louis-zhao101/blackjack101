import { useStatsStore } from '../store/statsStore.js';
import { summarizeSession, getCommonMistakes, computeLongestStreak, getMistakeCategories } from '@blackjack101/core';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer,
  BarChart, Bar, Cell,
} from 'recharts';

const ACTION_NAMES: Record<string, string> = {
  H: 'Hit', S: 'Stand', D: 'Double', P: 'Split', R: 'Surrender',
};

export function StatsPage() {
  const { sessions, currentSession, clearHistory } = useStatsStore();

  // Merge current session (if it has hands) into the view as a live entry
  const allSessions = currentSession && currentSession.hands.length > 0
    ? [...sessions, currentSession]
    : sessions;

  if (allSessions.length === 0) {
    return (
      <div className="stats-page">
        <div className="stats-empty">
          <h1>Statistics</h1>
          <p>Play some hands to see your stats here.</p>
        </div>
      </div>
    );
  }

  const summaries = allSessions.map(summarizeSession);
  const summariesChronological = [...summaries].reverse();
  const mistakes = getCommonMistakes(allSessions);
  const mistakeCategories = getMistakeCategories(allSessions);

  const accuracyData = summariesChronological.map((s, i) => ({
    name: s.isLive ? 'Now' : `S${i + 1}`,
    accuracy: s.correctPct,
    hands: s.handsPlayed,
  }));

  const allHands = allSessions.flatMap((s) => s.hands);
  const totalHands = allHands.length;
  const overallAccuracy = totalHands > 0
    ? Math.round((allHands.filter((h) => h.wasCorrect).length / totalHands) * 100)
    : 0;
  const totalPL = summaries.reduce((a, s) => a + s.profitLoss, 0);
  const globalBestStreak = computeLongestStreak(allHands);
  const bestSessionAccuracy = summaries.length > 0
    ? Math.max(...summaries.filter((s) => s.handsPlayed >= 5).map((s) => s.correctPct))
    : 0;

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
          <span className={`summary-card__value ${overallAccuracy >= 80 ? 'summary-card__value--good' : overallAccuracy >= 60 ? 'summary-card__value--ok' : 'summary-card__value--warn'}`}>
            {overallAccuracy}%
          </span>
          <span className="summary-card__label">Overall Accuracy</span>
        </div>
        <div className="summary-card">
          <span className={`summary-card__value ${globalBestStreak >= 10 ? 'summary-card__value--good' : globalBestStreak >= 5 ? 'summary-card__value--ok' : ''}`}>
            {globalBestStreak}
          </span>
          <span className="summary-card__label">Best Streak</span>
        </div>
        <div className="summary-card">
          <span className={`summary-card__value ${totalPL >= 0 ? 'summary-card__value--good' : 'summary-card__value--warn'}`}>
            {totalPL >= 0 ? '+' : ''}${totalPL}
          </span>
          <span className="summary-card__label">Total P&L</span>
        </div>
        <div className="summary-card">
          <span className="summary-card__value">{sessions.length}</span>
          <span className="summary-card__label">Sessions</span>
        </div>
        {bestSessionAccuracy > 0 && (
          <div className="summary-card">
            <span className={`summary-card__value ${bestSessionAccuracy >= 90 ? 'summary-card__value--good' : 'summary-card__value--ok'}`}>
              {bestSessionAccuracy}%
            </span>
            <span className="summary-card__label">Best Session</span>
          </div>
        )}
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
                <th>Best Streak</th>
                <th>P&L</th>
                <th>Rules</th>
              </tr>
            </thead>
            <tbody>
              {summaries.map((s) => (
                <tr key={s.id} className={s.isLive ? 'session-row--live' : ''}>
                  <td>
                    {s.isLive
                      ? <span className="live-badge">Live</span>
                      : new Date(s.date).toLocaleDateString()}
                  </td>
                  <td>{s.handsPlayed}</td>
                  <td>
                    <span className={`accuracy-badge ${s.correctPct >= 80 ? 'accuracy-badge--good' : s.correctPct >= 60 ? 'accuracy-badge--ok' : 'accuracy-badge--warn'}`}>
                      {s.correctPct}%
                    </span>
                  </td>
                  <td className="streak-cell">
                    <span className="streak-value">{s.longestStreak}</span>
                    {s.longestStreak >= 10 && <span className="streak-fire">🔥</span>}
                  </td>
                  <td className={s.profitLoss >= 0 ? 'stat-positive' : 'stat-negative'}>
                    {s.profitLoss >= 0 ? '+' : ''}${s.profitLoss}
                  </td>
                  <td>{s.ruleSetId}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Common mistakes */}
      {mistakeCategories.length > 0 && (
        <div className="stats-chart-section">
          <h2>Most Common Mistakes</h2>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height={240}>
              <BarChart data={mistakeCategories.slice(0, 6)} margin={{ top: 10, right: 20, left: 0, bottom: 60 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2d7a53" />
                <XAxis
                  dataKey="label"
                  stroke="#9ca3af"
                  tick={{ fontSize: 11, fill: '#9ca3af' }}
                  angle={-30}
                  textAnchor="end"
                  interval={0}
                />
                <YAxis stroke="#9ca3af" tick={{ fontSize: 12 }} allowDecimals={false} />
                <Tooltip
                  contentStyle={{ background: '#122e20', border: '1px solid #2d7a53', borderRadius: 8 }}
                  labelStyle={{ color: '#d4a843' }}
                  formatter={(val: number) => [val, 'Times']}
                />
                <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                  {mistakeCategories.slice(0, 6).map((_entry, i) => (
                    <Cell key={i} fill="#e74c3c" opacity={0.85} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          {mistakes.length > 0 && (
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
          )}
        </div>
      )}
    </div>
  );
}
