import { useRef, useState, useEffect } from 'react';
import { useStatsStore } from '../../store/statsStore.js';
import { useGameStore } from '../../store/gameStore.js';

export function StatsBar() {
  const { currentSession } = useStatsStore();
  const { game, playStats, topUp } = useGameStore();
  const bankroll = game.bankroll;

  const [showInput, setShowInput] = useState(false);
  const [inputVal, setInputVal] = useState('');
  const [popupPos, setPopupPos] = useState({ top: 0, left: 0 });
  const btnRef = useRef<HTMLButtonElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const popupRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (showInput) inputRef.current?.focus();
  }, [showInput]);

  useEffect(() => {
    if (!showInput) return;
    function handleClick(e: MouseEvent) {
      if (
        popupRef.current && !popupRef.current.contains(e.target as Node) &&
        btnRef.current && !btnRef.current.contains(e.target as Node)
      ) {
        setShowInput(false);
        setInputVal('');
      }
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, [showInput]);

  function openPopup() {
    if (btnRef.current) {
      const rect = btnRef.current.getBoundingClientRect();
      setPopupPos({ top: rect.bottom + 6, left: rect.left });
    }
    setShowInput(v => !v);
    setInputVal('');
  }

  function handleAdd() {
    const n = parseInt(inputVal, 10);
    if (n > 0) {
      topUp(n);
      setInputVal('');
      setShowInput(false);
    }
  }

  const handsPlayed = currentSession?.hands?.length ?? 0;
  const hasPlays = playStats.total > 0;
  const pct = hasPlays ? Math.round((playStats.correct / playStats.total) * 100) : null;

  return (
    <div className="stats-bar" role="status" aria-label="Session statistics">
      <div className="stats-bar__item">
        <span className="stats-bar__label">Balance</span>
        <span className="stats-bar__value stats-bar__value--gold">${bankroll}</span>
        <button
          ref={btnRef}
          className="balance-add-btn"
          onClick={openPopup}
          aria-label="Add chips to bankroll"
        >
          +
        </button>
      </div>

      {showInput && (
        <div
          className="balance-add-popup"
          ref={popupRef}
          style={{ top: popupPos.top, left: popupPos.left }}
        >
          <span className="balance-add-popup__label">$</span>
          <input
            ref={inputRef}
            className="balance-add-popup__input"
            type="number"
            min="1"
            placeholder="Amount"
            value={inputVal}
            onChange={e => setInputVal(e.target.value)}
            onKeyDown={e => {
              if (e.key === 'Enter') handleAdd();
              if (e.key === 'Escape') { setShowInput(false); setInputVal(''); }
            }}
          />
          <button
            className="btn btn--primary btn--sm"
            onClick={handleAdd}
            disabled={!inputVal || parseInt(inputVal) < 1}
          >
            Add
          </button>
        </div>
      )}

      {hasPlays && (
        <>
          <div className="stats-bar__divider" aria-hidden="true" />
          <div className="stats-bar__item">
            <span className="stats-bar__label">Hands</span>
            <span className="stats-bar__value">{handsPlayed}</span>
          </div>
          <div className="stats-bar__divider" aria-hidden="true" />
          <div className="stats-bar__item">
            <span className="stats-bar__label">Correct Plays</span>
            <span className="stats-bar__value">
              {playStats.correct}/{playStats.total}
            </span>
            <span className={`stats-bar__value ${pct! >= 80 ? 'stats-bar__value--good' : pct! >= 60 ? 'stats-bar__value--ok' : 'stats-bar__value--warn'}`}>
              {pct}%
            </span>
          </div>
        </>
      )}
    </div>
  );
}
