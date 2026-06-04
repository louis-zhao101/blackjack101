import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import {
  createSession,
  recordHand,
  endSession,
  type Session,
  type HandRecord,
} from '@blackjack101/core';

interface StatsState {
  sessions: Session[];
  currentSession: Session | null;
  startSession: (bankroll: number, ruleSetId: string) => void;
  addHandRecord: (record: Omit<HandRecord, 'id' | 'timestamp'>) => void;
  finishSession: (endBankroll: number) => void;
  clearHistory: () => void;
}

export const useStatsStore = create<StatsState>()(
  persist(
    (set, get) => ({
      sessions: [],
      currentSession: null,

      startSession: (bankroll, ruleSetId) => {
        const session = createSession(bankroll, ruleSetId);
        set({ currentSession: session });
      },

      addHandRecord: (record) => {
        const { currentSession } = get();
        if (!currentSession) return;
        const updated = recordHand(currentSession, record);
        set({ currentSession: updated });
      },

      finishSession: (endBankroll) => {
        const { currentSession, sessions } = get();
        if (!currentSession) return;
        const finished = endSession(currentSession, endBankroll);
        set({ sessions: [finished, ...sessions].slice(0, 50), currentSession: null });
      },

      clearHistory: () => set({ sessions: [], currentSession: null }),
    }),
    { name: 'bj101-stats' }
  )
);
