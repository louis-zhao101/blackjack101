import { useState } from 'react';
import { StrategyChart } from '../components/learn/StrategyChart.js';

type LearnTab = 'overview' | 'strategy' | 'mistakes' | 'glossary';

const COMMON_MISTAKES = [
  {
    scenario: 'Standing on 16 vs dealer 7, 8, 9, 10, or Ace',
    correct: 'Hit (or Surrender if late surrender is available)',
    why: "16 is a losing hand against a strong dealer card. Standing hopes the dealer busts, but the dealer makes a hand far more often than they bust vs a strong upcard. Hitting gives you a chance to improve.",
  },
  {
    scenario: 'Splitting 10s',
    correct: 'Stand — never split 10s',
    why: "A pair of 10s totals 20, one of the strongest possible hands. Splitting breaks it into two hands each starting with 10, which is weaker. The only reason to split would be extreme greed that isn't backed by math.",
  },
  {
    scenario: 'Not doubling 11 vs dealer 2–10',
    correct: 'Double down',
    why: "11 is the single best doubling opportunity in blackjack. Any 10-value card (the most common) gives you 21. Always double 11 unless the dealer shows an Ace.",
  },
  {
    scenario: 'Hitting soft 18 vs dealer 2, 7, or 8',
    correct: 'Stand',
    why: "Soft 18 is a strong hand. Against a 2, 7, or 8 you should stand — you're favored to win or push. Only hit soft 18 against dealer 9, 10, or Ace.",
  },
  {
    scenario: 'Not splitting 8s vs dealer 9, 10, or Ace',
    correct: 'Always split 8s',
    why: "A pair of 8s totals 16, the worst hand in blackjack. Splitting gives you two fresh starts with 8 as your base, which is significantly better than playing 16.",
  },
  {
    scenario: 'Standing on 12 vs dealer 2 or 3',
    correct: 'Hit',
    why: "Many players stand on 12 vs any dealer bust card, but 12 vs 2 or 3 is actually a hit. The dealer's bust probability isn't high enough to compensate for your weak total — you need to improve.",
  },
  {
    scenario: 'Not doubling soft 13–18 vs dealer 5 or 6',
    correct: 'Double down',
    why: "Dealer 5 and 6 are the two weakest upcards — the dealer will bust roughly 42% of the time. Any time you can double vs 5 or 6 on a soft total, you should maximize your bet.",
  },
  {
    scenario: 'Hitting hard 12–16 vs dealer 4, 5, or 6',
    correct: 'Stand',
    why: "The dealer is showing a bust card. Your job is to get out of the way and let them bust. Even though 12–16 are uncomfortable hands, standing is correct when the dealer is weak.",
  },
  {
    scenario: 'Not surrendering 16 vs dealer 9, 10, or Ace',
    correct: 'Surrender (if available)',
    why: "Late surrender on hard 16 vs these upcards saves you money in the long run. You're expected to lose more than half your bet playing these hands — surrender recovers half immediately.",
  },
  {
    scenario: 'Splitting 4s vs dealer cards other than 5 or 6',
    correct: 'Hit (treat as hard 8)',
    why: "A pair of 4s totals 8, a decent base for hitting. You should only split 4s when the dealer shows 5 or 6 (where doubling after split is allowed). Otherwise, hitting is better.",
  },
];

const GLOSSARY = [
  { term: 'Hard hand', def: 'A hand with no ace, or an ace counted as 1. Example: 10+7 = hard 17.' },
  { term: 'Soft hand', def: 'A hand containing an ace counted as 11. Example: A+7 = soft 18.' },
  { term: 'Bust', def: 'When your hand total exceeds 21. An automatic loss.' },
  { term: 'Blackjack', def: 'An ace plus any 10-value card on the first two cards. Pays 3:2.' },
  { term: 'Double down', def: 'Double your bet after the first two cards and receive exactly one more card.' },
  { term: 'Split', def: 'When your first two cards are the same value, split them into two separate hands, each with an additional card dealt.' },
  { term: 'Surrender', def: 'Fold your hand and recover half your bet. Only available on the first two cards (late surrender).' },
  { term: 'Push', def: 'A tie — both player and dealer have the same total. Your bet is returned.' },
  { term: 'Basic strategy', def: 'The mathematically optimal set of decisions for every possible player hand vs every dealer upcard.' },
  { term: 'House edge', def: "The casino's mathematical advantage. With perfect basic strategy, the house edge on 6-deck blackjack is roughly 0.5%." },
  { term: 'Shoe', def: 'The device that holds multiple decks of cards. A 6-deck shoe holds 312 cards.' },
  { term: 'Upcard', def: "The dealer's face-up card visible to all players. Your basic strategy decisions are based on this card." },
];

export function LearnPage() {
  const [activeTab, setActiveTab] = useState<LearnTab>('overview');

  return (
    <div className="learn-page">
      <div className="learn-hero">
        <h1 className="learn-hero__title">Learn Blackjack</h1>
        <p className="learn-hero__subtitle">
          Master the rules and play every hand perfectly with basic strategy.
        </p>
      </div>

      <nav className="learn-tabs" role="tablist" aria-label="Learn sections">
        {([['overview', 'Overview'], ['strategy', 'Basic Strategy'], ['mistakes', 'Common Mistakes'], ['glossary', 'Glossary']] as [LearnTab, string][]).map(([tab, label]) => (
          <button
            key={tab}
            role="tab"
            aria-selected={activeTab === tab}
            className={`learn-tab ${activeTab === tab ? 'learn-tab--active' : ''}`}
            onClick={() => setActiveTab(tab)}
          >
            {label}
          </button>
        ))}
      </nav>

      <div className="learn-content">
        {activeTab === 'overview' && (
          <div className="learn-section animate-fade-in">
            <div className="rules-grid">
              <div className="rules-card">
                <h2>Objective</h2>
                <p>
                  Beat the dealer by getting a hand value closer to 21 without going over. You're
                  not competing against other players — only the dealer.
                </p>
              </div>

              <div className="rules-card">
                <h2>Card Values</h2>
                <ul className="card-values-list">
                  <li><span className="card-value-demo">2–9</span> Face value</li>
                  <li><span className="card-value-demo">10, J, Q, K</span> Worth 10</li>
                  <li><span className="card-value-demo">A</span> Worth 1 or 11 (whichever is better)</li>
                </ul>
              </div>

              <div className="rules-card">
                <h2>Flow of a Hand</h2>
                <ol className="rules-steps">
                  <li>Place your bet</li>
                  <li>Player and dealer each receive two cards (one dealer card is face down)</li>
                  <li>If either has blackjack, the hand may end immediately</li>
                  <li>Player chooses: Hit, Stand, Double, Split, or Surrender</li>
                  <li>If player doesn't bust, dealer reveals their hole card and plays</li>
                  <li>Dealer must hit until reaching 17 or higher</li>
                  <li>Whoever is closer to 21 (without busting) wins</li>
                </ol>
              </div>

              <div className="rules-card">
                <h2>Payouts</h2>
                <ul className="payout-list">
                  <li><span className="payout-label">Win</span> 1:1 (win $10 on a $10 bet)</li>
                  <li><span className="payout-label">Blackjack</span> 3:2 (win $15 on a $10 bet)</li>
                  <li><span className="payout-label">Push</span> Bet returned</li>
                  <li><span className="payout-label">Surrender</span> Half bet returned</li>
                </ul>
              </div>

              <div className="rules-card rules-card--wide">
                <h2>Player Actions</h2>
                <div className="actions-grid">
                  <div className="action-explain">
                    <span className="action-explain__name">Hit</span>
                    <p>Take another card from the deck.</p>
                  </div>
                  <div className="action-explain">
                    <span className="action-explain__name">Stand</span>
                    <p>Keep your current hand. End your turn.</p>
                  </div>
                  <div className="action-explain">
                    <span className="action-explain__name">Double Down</span>
                    <p>Double your bet and receive exactly one more card. Only available on the first two cards.</p>
                  </div>
                  <div className="action-explain">
                    <span className="action-explain__name">Split</span>
                    <p>When your first two cards have equal value, split them into two hands. Each hand gets a new second card and plays independently.</p>
                  </div>
                  <div className="action-explain">
                    <span className="action-explain__name">Surrender</span>
                    <p>Fold your hand and recover half your bet. Only available on the first two cards, and only if the casino offers late surrender.</p>
                  </div>
                </div>
              </div>

              <div className="rules-card rules-card--wide">
                <h2>Dealer Rules</h2>
                <p>
                  The dealer has no choices — they follow fixed rules. The dealer must hit
                  until their hand totals 17 or more. In most casinos (including Vegas Strip rules),
                  the dealer <strong>stands on soft 17</strong>. This rule slightly favors the player.
                </p>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'strategy' && (
          <div className="learn-section animate-fade-in">
            <div className="strategy-intro">
              <h2>Basic Strategy</h2>
              <p>
                Basic strategy is the mathematically optimal decision for every possible combination
                of your hand vs the dealer's upcard. Playing perfect basic strategy reduces the house
                edge to around 0.5% on a 6-deck game — lower than almost any other casino game.
              </p>
              <p>
                Click any cell in the chart to see an explanation of that decision.
              </p>
            </div>
            <StrategyChart />
          </div>
        )}

        {activeTab === 'mistakes' && (
          <div className="learn-section animate-fade-in">
            <h2>Common Mistakes</h2>
            <p className="section-lead">
              These are the most frequent strategy errors players make. Fixing just these ten
              mistakes will dramatically reduce the house edge against you.
            </p>
            <div className="mistakes-list">
              {COMMON_MISTAKES.map((m, i) => (
                <div key={i} className="mistake-card">
                  <div className="mistake-card__header">
                    <span className="mistake-number">{i + 1}</span>
                    <h3 className="mistake-scenario">{m.scenario}</h3>
                  </div>
                  <div className="mistake-card__body">
                    <div className="mistake-correct">
                      <span className="mistake-correct__label">Correct play:</span>
                      <span className="mistake-correct__action">{m.correct}</span>
                    </div>
                    <p className="mistake-why">{m.why}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === 'glossary' && (
          <div className="learn-section animate-fade-in">
            <h2>Glossary</h2>
            <dl className="glossary-list">
              {GLOSSARY.map(({ term, def }) => (
                <div key={term} className="glossary-entry">
                  <dt className="glossary-term">{term}</dt>
                  <dd className="glossary-def">{def}</dd>
                </div>
              ))}
            </dl>
          </div>
        )}
      </div>
    </div>
  );
}
