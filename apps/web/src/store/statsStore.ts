import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import {
  createSession,
  recordHand,
  endSession,
  type Session,
  type HandRecord,
} from '@blackjack101/core';
import { upsertSession, getCurrentUserId } from '../lib/sync';

interface StatsState {
  sessions: Session[];
  currentSession: Session | null;
  startSession: (bankroll: number, ruleSetId: string) => void;
  addHandRecord: (record: Omit<HandRecord, 'id' | 'timestamp'>) => void;
  finishSession: (endBankroll: number) => void;
  clearHistory: () => void;
  loadFromCloud: (sessions: Session[]) => void;
}

async function syncSession(session: Session): Promise<void> {
  const userId = await getCurrentUserId();
  if (userId) void upsertSession(userId, session);
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
        void syncSession(updated);
      },

      finishSession: (endBankroll) => {
        const { currentSession, sessions } = get();
        if (!currentSession) return;
        const finished = endSession(currentSession, endBankroll);
        set({ sessions: [finished, ...sessions].slice(0, 50), currentSession: null });
        void syncSession(finished);
      },

      clearHistory: () => set({ sessions: [], currentSession: null }),

      loadFromCloud: (cloudSessions) => {
        const live = cloudSessions.find((s) => s.endTime === null) ?? null;
        const finished = cloudSessions.filter((s) => s.endTime !== null);
        set({ sessions: finished, currentSession: live });
      },
    }),
    { name: 'bj101-stats' }
  )
);
