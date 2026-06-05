import { Action } from './strategy.js';

export interface HandRecord {
  id: string;
  timestamp: number;
  playerAction: Action;
  optimalAction: Action;
  wasCorrect: boolean;
  playerTotal: number;
  soft: boolean;
  dealerUpcard: string;
  handType: 'hard' | 'soft' | 'pair';
  explanation: string;
  betAmount: number;
  outcome: 'win' | 'lose' | 'push' | 'blackjack' | 'surrender';
  payout: number;
}

export interface Session {
  id: string;
  startTime: number;
  endTime: number | null;
  startBankroll: number;
  endBankroll: number | null;
  hands: HandRecord[];
  ruleSetId: string;
}

export interface SessionSummary {
  id: string;
  date: number;
  handsPlayed: number;
  correctPct: number;
  profitLoss: number;
  ruleSetId: string;
  longestStreak: number;
  isLive: boolean;
}

export interface MistakeSummary {
  playerTotal: number;
  soft: boolean;
  dealerUpcard: string;
  handType: 'hard' | 'soft' | 'pair';
  playerAction: Action;
  optimalAction: Action;
  count: number;
  explanation: string;
}

export function createSession(startBankroll: number, ruleSetId: string): Session {
  return {
    id: crypto.randomUUID(),
    startTime: Date.now(),
    endTime: null,
    startBankroll,
    endBankroll: null,
    hands: [],
    ruleSetId,
  };
}

export function recordHand(session: Session, record: Omit<HandRecord, 'id' | 'timestamp'>): Session {
  const hand: HandRecord = {
    ...record,
    id: crypto.randomUUID(),
    timestamp: Date.now(),
  };
  return { ...session, hands: [...session.hands, hand] };
}

export function endSession(session: Session, endBankroll: number): Session {
  return { ...session, endTime: Date.now(), endBankroll };
}

export function computeLongestStreak(hands: HandRecord[]): number {
  let max = 0;
  let current = 0;
  for (const h of hands) {
    if (h.wasCorrect) { current++; max = Math.max(max, current); }
    else { current = 0; }
  }
  return max;
}

export function summarizeSession(session: Session): SessionSummary {
  const { hands } = session;
  const correctCount = hands.filter((h) => h.wasCorrect).length;
  const correctPct = hands.length > 0 ? (correctCount / hands.length) * 100 : 0;
  const endBankroll = session.endBankroll ?? session.startBankroll;

  return {
    id: session.id,
    date: session.startTime,
    handsPlayed: hands.length,
    correctPct: Math.round(correctPct * 10) / 10,
    profitLoss: endBankroll - session.startBankroll,
    ruleSetId: session.ruleSetId,
    longestStreak: computeLongestStreak(hands),
    isLive: session.endTime === null,
  };
}

export function getCommonMistakes(sessions: Session[], topN = 10): MistakeSummary[] {
  const allHands = sessions.flatMap((s) => s.hands);
  const mistakes = allHands.filter((h) => !h.wasCorrect);

  const counts = new Map<string, MistakeSummary>();
  for (const m of mistakes) {
    const key = `${m.handType}-${m.playerTotal}-${m.soft}-${m.dealerUpcard}-${m.playerAction}-${m.optimalAction}`;
    const existing = counts.get(key);
    if (existing) {
      existing.count++;
    } else {
      counts.set(key, {
        playerTotal: m.playerTotal,
        soft: m.soft,
        dealerUpcard: m.dealerUpcard,
        handType: m.handType,
        playerAction: m.playerAction,
        optimalAction: m.optimalAction,
        count: 1,
        explanation: m.explanation,
      });
    }
  }

  return Array.from(counts.values())
    .sort((a, b) => b.count - a.count)
    .slice(0, topN);
}
