import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { VEGAS_STRIP, type RuleSet } from '@blackjack101/core';

interface SettingsState {
  ruleSet: RuleSet;
  startingBankroll: number;
  setRuleSet: (ruleSet: RuleSet) => void;
  setStartingBankroll: (amount: number) => void;
}

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      ruleSet: VEGAS_STRIP,
      startingBankroll: 1000,
      setRuleSet: (ruleSet) => set({ ruleSet }),
      setStartingBankroll: (startingBankroll) => set({ startingBankroll }),
    }),
    {
      name: 'bj101-settings',
      version: 1,
      migrate: (state: any) => {
        // v0 → v1: surrender changed from 'late' to 'none' as default
        if (state?.ruleSet?.surrender === 'late') {
          state.ruleSet = { ...state.ruleSet, surrender: 'none' };
        }
        return state;
      },
    }
  )
);
