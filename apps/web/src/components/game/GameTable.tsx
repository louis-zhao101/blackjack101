import { useGameStore } from '../../store/gameStore.js';
import { BlackjackHand } from './BlackjackHand.js';
import { ActionBar } from './ActionBar.js';
import { BetPanel } from './BetPanel.js';
import { StrategyHint } from './StrategyHint.js';
import { StatsBar } from './StatsBar.js';

export function GameTable() {
  const { game, lastHandInfo, lastBet, nextHand, rebetAndDeal, newSession, topUp } = useGameStore();
  const { phase, dealerCards, playerHands, activeHandIndex, pendingBet, bankroll, message } = game;

  const isComplete = phase === 'COMPLETE';
  const isBetting = phase === 'BETTING';

  return (
    <div className="game-table">
      <StatsBar />

      {/* Table felt area */}
      <div className="table-felt">
        {/* Dealer zone */}
        <div className="dealer-zone">
          <div className="zone-label">Dealer</div>
          {dealerCards.length > 0 ? (
            <BlackjackHand cards={dealerCards} />
          ) : (
            <div className="empty-hand-placeholder" aria-hidden="true" />
          )}
        </div>

        {/* Center slot: result message when complete, logo otherwise */}
        {message && isComplete ? (
          <div
            className={`game-message ${
              message.includes('win') || message.includes('Blackjack')
                ? 'game-message--win'
                : message.includes('Push')
                ? 'game-message--push'
                : 'game-message--lose'
            }`}
            role="status"
          >
            {message}
          </div>
        ) : (
          <div className="table-logo" aria-hidden="true">
            <span className="table-logo__text">Blackjack 101</span>
            <span className="table-logo__sub">Pays 3 to 2</span>
          </div>
        )}

        {/* Player zone */}
        <div className="player-zone">
          {playerHands.length > 0 ? (
            <div className="player-hands">
              {playerHands.map((hand, i) => (
                <BlackjackHand
                  key={i}
                  cards={hand.cards}
                  label={playerHands.length > 1 ? `Hand ${i + 1}` : 'Your Hand'}
                  isActive={i === activeHandIndex && phase === 'PLAYER_TURN'}
                  result={hand.result}
                  bet={hand.bet}
                />
              ))}
            </div>
          ) : (
            <div className="empty-hand-placeholder" aria-hidden="true" />
          )}
        </div>

      </div>

      {/* Controls area */}
      <div className="controls-area">
        {lastHandInfo && !isBetting && (
          <div className="controls-hint">
            <StrategyHint info={lastHandInfo} />
          </div>
        )}

        {isBetting && bankroll > 0 && <BetPanel bankroll={bankroll} pendingBet={pendingBet} />}

        {phase === 'PLAYER_TURN' && <ActionBar />}

        {isComplete && (
          <div className="complete-actions">
            {lastBet > 0 ? (
              <>
                <button
                  className="btn btn--primary btn--lg"
                  onClick={rebetAndDeal}
                  aria-label={`Deal again with $${lastBet} bet`}
                >
                  Deal Again (${lastBet})
                </button>
                <button
                  className="btn btn--ghost btn--sm"
                  onClick={nextHand}
                  aria-label="Change bet amount"
                >
                  Change Bet
                </button>
              </>
            ) : (
              <button
                className="btn btn--primary btn--lg"
                onClick={nextHand}
                aria-label="Deal next hand"
              >
                Next Hand
              </button>
            )}
            <button
              className="btn btn--ghost btn--sm btn--tertiary"
              onClick={newSession}
              aria-label="Start a new session"
            >
              New Session
            </button>
          </div>
        )}

        {bankroll === 0 && isBetting && (
          <div className="bust-message">
            <p>Out of chips!</p>
            <div className="bust-message__actions">
              <button className="btn btn--primary" onClick={() => topUp(500)}>
                Add $500
              </button>
              <button className="btn btn--ghost btn--sm btn--tertiary" onClick={newSession}>
                New Session
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
