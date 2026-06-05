import { create } from 'zustand';
import {
  createInitialState,
  dealHand,
  hit,
  stand,
  doubleDown,
  split,
  surrender,
  newHand,
  addToBet,
  clearBet,
  canDouble,
  canSplit,
  canSurrender,
  getOptimalAction,
  handValue,
  type GameState,
  type Action,
  type OptimalAction,
} from '@blackjack101/core';
import { useSettingsStore } from './settingsStore.js';
import { useStatsStore } from './statsStore.js';
import { upsertProfile, getCurrentUserId } from '../lib/sync.js';

async function syncBankroll(bankroll: number): Promise<void> {
  const userId = await getCurrentUserId();
  if (userId) void upsertProfile(userId, bankroll);
}

export interface LastHandInfo {
  optimal: OptimalAction;
  playerAction: Action;
  wasCorrect: boolean;
  playerTotal: number;
  soft: boolean;
  dealerUpcard: string;
  handType: 'hard' | 'soft' | 'pair';
}

interface GameStoreState {
  game: GameState;
  lastHandInfo: LastHandInfo | null;
  lastBet: number;
  playStats: { total: number; correct: number };
  handHadMistake: boolean;
  firstMistakeInfo: LastHandInfo | null; // first wrong action this hand; used for accurate mistake recording

  // Actions
  placeBetChip: (amount: number) => void;
  clearBet: () => void;
  deal: () => void;
  hit: () => void;
  stand: () => void;
  double: () => void;
  split: () => void;
  surrender: () => void;
  nextHand: () => void;
  rebetAndDeal: () => void;
  newSession: () => void;
  topUp: (amount: number) => void;
  loadBankroll: (bankroll: number) => void;

  // Derived helpers
  canDouble: () => boolean;
  canSplit: () => boolean;
  canSurrender: () => boolean;
}

function detectHandType(game: GameState): 'hard' | 'soft' | 'pair' {
  const hand = game.playerHands[game.activeHandIndex];
  if (!hand) return 'hard';
  const { total, soft } = handValue(hand.cards);
  if (
    hand.cards.length === 2 &&
    (() => {
      const [c1, c2] = hand.cards;
      if (!c1 || !c2) return false;
      const k1 = c1.rank === 'J' || c1.rank === 'Q' || c1.rank === 'K' ? '10' : c1.rank;
      const k2 = c2.rank === 'J' || c2.rank === 'Q' || c2.rank === 'K' ? '10' : c2.rank;
      return k1 === k2;
    })()
  ) {
    return 'pair';
  }
  if (soft && total >= 13 && total <= 20) return 'soft';
  return 'hard';
}

export const useGameStore = create<GameStoreState>((set, get) => ({
  game: createInitialState(
    useSettingsStore.getState().startingBankroll,
    useSettingsStore.getState().ruleSet
  ),
  lastHandInfo: null,
  lastBet: 0,
  playStats: { total: 0, correct: 0 },
  handHadMistake: false,
  firstMistakeInfo: null,

  placeBetChip: (amount) =>
    set((s) => ({ game: addToBet(s.game, amount) })),

  clearBet: () =>
    set((s) => ({ game: clearBet(s.game) })),

  deal: () => {
    const { game } = get();
    const settings = useSettingsStore.getState();
    const stats = useStatsStore.getState();

    // Auto-rotate session after 60 minutes of inactivity
    if (stats.currentSession && stats.currentSession.hands.length > 0) {
      const lastHand = stats.currentSession.hands[stats.currentSession.hands.length - 1];
      if (lastHand && Date.now() - lastHand.timestamp > 60 * 60 * 1000) {
        stats.finishSession(game.bankroll);
        stats.startSession(game.bankroll, settings.ruleSet.id);
        set({ playStats: { total: 0, correct: 0 }, handHadMistake: false });
      }
    }

    if (!stats.currentSession) {
      stats.startSession(game.bankroll, settings.ruleSet.id);
    }

    const originalBet = game.pendingBet;
    set((s) => ({
      game: dealHand(s.game),
      lastHandInfo: null,
      handHadMistake: false,
      firstMistakeInfo: null,
      lastBet: originalBet,
    }));
  },

  hit: () => {
    const { game, playStats, handHadMistake, firstMistakeInfo } = get();
    const hand = game.playerHands[game.activeHandIndex];
    if (!hand) return;
    const dealerUpcard = game.dealerCards[0];
    if (!dealerUpcard) return;

    const optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    const playerAction: Action = 'H';
    const wasCorrect = optimal.action === 'H' ||
      (optimal.action === 'D' && optimal.doubleFallback === 'H' && !canDouble(game));
    const handType = detectHandType(game);
    const { total, soft } = handValue(hand.cards);

    const nextGame = hit(game);
    _applyPlay(set, nextGame, { optimal, playerAction, wasCorrect, playerTotal: total, soft, dealerUpcard: dealerUpcard.rank, handType }, playStats, handHadMistake, firstMistakeInfo);
  },

  stand: () => {
    const { game, playStats, handHadMistake, firstMistakeInfo } = get();
    const hand = game.playerHands[game.activeHandIndex];
    if (!hand) return;
    const dealerUpcard = game.dealerCards[0];
    if (!dealerUpcard) return;

    const optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    const playerAction: Action = 'S';
    const wasCorrect = optimal.action === 'S' ||
      (optimal.action === 'D' && optimal.doubleFallback === 'S' && !canDouble(game));
    const handType = detectHandType(game);
    const { total, soft } = handValue(hand.cards);

    const nextGame = stand(game);
    _applyPlay(set, nextGame, { optimal, playerAction, wasCorrect, playerTotal: total, soft, dealerUpcard: dealerUpcard.rank, handType }, playStats, handHadMistake, firstMistakeInfo);
  },

  double: () => {
    const { game, playStats, handHadMistake, firstMistakeInfo } = get();
    const hand = game.playerHands[game.activeHandIndex];
    if (!hand) return;
    const dealerUpcard = game.dealerCards[0];
    if (!dealerUpcard) return;

    const optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    const playerAction: Action = 'D';
    const wasCorrect = optimal.action === 'D';
    const handType = detectHandType(game);
    const { total, soft } = handValue(hand.cards);

    const nextGame = doubleDown(game);
    _applyPlay(set, nextGame, { optimal, playerAction, wasCorrect, playerTotal: total, soft, dealerUpcard: dealerUpcard.rank, handType }, playStats, handHadMistake, firstMistakeInfo);
  },

  split: () => {
    const { game, playStats, handHadMistake, firstMistakeInfo } = get();
    const hand = game.playerHands[game.activeHandIndex];
    if (!hand) return;
    const dealerUpcard = game.dealerCards[0];
    if (!dealerUpcard) return;

    const optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    const playerAction: Action = 'P';
    const wasCorrect = optimal.action === 'P';
    const handType: 'pair' = 'pair';
    const { total, soft } = handValue(hand.cards);

    const nextGame = split(game);
    _applyPlay(set, nextGame, { optimal, playerAction, wasCorrect, playerTotal: total, soft, dealerUpcard: dealerUpcard.rank, handType }, playStats, handHadMistake, firstMistakeInfo);
  },

  surrender: () => {
    const { game, playStats, handHadMistake, firstMistakeInfo } = get();
    const hand = game.playerHands[game.activeHandIndex];
    if (!hand) return;
    const dealerUpcard = game.dealerCards[0];
    if (!dealerUpcard) return;

    const optimal = getOptimalAction(hand.cards, dealerUpcard, game.ruleSet);
    const playerAction: Action = 'R';
    const wasCorrect = optimal.action === 'R';
    const handType = detectHandType(game);
    const { total, soft } = handValue(hand.cards);

    const nextGame = surrender(game);
    _applyPlay(set, nextGame, { optimal, playerAction, wasCorrect, playerTotal: total, soft, dealerUpcard: dealerUpcard.rank, handType }, playStats, handHadMistake, firstMistakeInfo);
  },

  nextHand: () => {
    const { game, lastBet } = get();
    const nextGame = newHand(game);
    const autobet = Math.min(lastBet, nextGame.bankroll);
    set({
      game: autobet > 0 ? { ...nextGame, pendingBet: autobet } : nextGame,
      lastHandInfo: null,
      handHadMistake: false,
      firstMistakeInfo: null,
    });
  },

  rebetAndDeal: () => {
    const { game, lastBet } = get();
    const settings = useSettingsStore.getState();
    const stats = useStatsStore.getState();

    // Auto-rotate session after 60 minutes of inactivity
    if (stats.currentSession && stats.currentSession.hands.length > 0) {
      const lastHand = stats.currentSession.hands[stats.currentSession.hands.length - 1];
      if (lastHand && Date.now() - lastHand.timestamp > 60 * 60 * 1000) {
        stats.finishSession(game.bankroll);
        stats.startSession(game.bankroll, settings.ruleSet.id);
        set({ playStats: { total: 0, correct: 0 }, handHadMistake: false });
      }
    }

    if (!stats.currentSession) {
      stats.startSession(game.bankroll, settings.ruleSet.id);
    }

    let nextGame = newHand(game);
    const autobet = Math.min(lastBet, nextGame.bankroll);
    if (autobet > 0) {
      nextGame = dealHand({ ...nextGame, pendingBet: autobet });
    }
    set({ game: nextGame, lastHandInfo: null, handHadMistake: false, firstMistakeInfo: null });
  },

  topUp: (amount) => {
    const newBankroll = get().game.bankroll + amount;
    set((s) => ({ game: { ...s.game, bankroll: s.game.bankroll + amount } }));
    void syncBankroll(newBankroll);
  },

  loadBankroll: (bankroll) =>
    set((s) => ({ game: { ...s.game, bankroll } })),

  newSession: () => {
    const { game } = get();
    const settings = useSettingsStore.getState();
    const stats = useStatsStore.getState();
    stats.finishSession(game.bankroll);
    stats.startSession(game.bankroll, settings.ruleSet.id);
    void syncBankroll(game.bankroll);
    set({
      game: createInitialState(game.bankroll, settings.ruleSet),
      lastHandInfo: null,
      lastBet: 0,
      playStats: { total: 0, correct: 0 },
      handHadMistake: false,
      firstMistakeInfo: null,
    });
  },

  canDouble: () => canDouble(get().game),
  canSplit: () => canSplit(get().game),
  canSurrender: () => canSurrender(get().game),
}));

function _applyPlay(
  set: (partial: Partial<GameStoreState>) => void,
  nextGame: GameState,
  info: LastHandInfo,
  currentPlayStats: { total: number; correct: number },
  currentHandHadMistake: boolean,
  currentFirstMistakeInfo: LastHandInfo | null,
) {
  const newHadMistake = currentHandHadMistake || !info.wasCorrect;
  const newPlayStats = {
    total: currentPlayStats.total + 1,
    correct: currentPlayStats.correct + (info.wasCorrect ? 1 : 0),
  };
  // Capture the FIRST wrong action this hand; ignore all subsequent actions (right or wrong)
  const newFirstMistakeInfo = !currentHandHadMistake && !info.wasCorrect
    ? info
    : currentFirstMistakeInfo;

  set({ game: nextGame, lastHandInfo: info, handHadMistake: newHadMistake, playStats: newPlayStats, firstMistakeInfo: newFirstMistakeInfo });

  // Record one entry per completed hand to the stats store
  if (nextGame.phase === 'COMPLETE') {
    const statsStore = useStatsStore.getState();
    if (statsStore.currentSession) {
      // Use the first mistake's action details so common mistakes accurately reflects what went wrong
      const recordInfo = newHadMistake && newFirstMistakeInfo ? newFirstMistakeInfo : info;
      statsStore.addHandRecord({
        playerAction: recordInfo.playerAction,
        optimalAction: recordInfo.optimal.action,
        wasCorrect: !newHadMistake,
        playerTotal: recordInfo.playerTotal,
        soft: recordInfo.soft,
        dealerUpcard: recordInfo.dealerUpcard,
        handType: recordInfo.handType,
        explanation: recordInfo.optimal.explanation,
        betAmount: nextGame.playerHands[0]?.bet ?? 0,
        outcome: nextGame.playerHands[0]?.result ?? 'lose',
        payout: nextGame.playerHands[0]?.payout ?? 0,
      });
    }
  }
}
