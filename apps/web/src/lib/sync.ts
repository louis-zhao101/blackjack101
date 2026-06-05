import { supabase } from './supabase';
import type { Session } from '@blackjack101/core';

export async function upsertSession(userId: string, session: Session): Promise<void> {
  await supabase.from('game_sessions').upsert({
    id: session.id,
    user_id: userId,
    start_time: session.startTime,
    end_time: session.endTime,
    start_bankroll: session.startBankroll,
    end_bankroll: session.endBankroll,
    rule_set_id: session.ruleSetId,
    hands: session.hands,
  });
}

export async function upsertProfile(userId: string, bankroll: number): Promise<void> {
  await supabase.from('user_profiles').upsert({
    id: userId,
    bankroll,
    updated_at: new Date().toISOString(),
  });
}

export interface CloudData {
  profile: { bankroll: number } | null;
  sessions: Session[];
}

export async function loadUserData(userId: string): Promise<CloudData> {
  const [profileRes, sessionsRes] = await Promise.all([
    supabase.from('user_profiles').select('bankroll').eq('id', userId).single(),
    supabase
      .from('game_sessions')
      .select('id, start_time, end_time, start_bankroll, end_bankroll, rule_set_id, hands')
      .eq('user_id', userId)
      .order('start_time', { ascending: false })
      .limit(50),
  ]);

  const raw = sessionsRes.data ?? [];
  const sessions: Session[] = raw.map((r) => ({
    id: r.id as string,
    startTime: r.start_time as number,
    endTime: r.end_time as number | null,
    startBankroll: r.start_bankroll as number,
    endBankroll: r.end_bankroll as number | null,
    ruleSetId: r.rule_set_id as string,
    hands: (r.hands as Session['hands']) ?? [],
  }));

  return {
    profile: profileRes.data ? { bankroll: profileRes.data.bankroll as number } : null,
    sessions,
  };
}

export async function getCurrentUserId(): Promise<string | null> {
  const { data: { session } } = await supabase.auth.getSession();
  return session?.user?.id ?? null;
}
