# Blackjack 101 — Claude Code Guide

## What this is
A blackjack strategy training web app. Players practice optimal strategy and track their accuracy over time. Live at `blackjack101-web.vercel.app`.

## Monorepo structure
```
packages/core/          Pure TypeScript game engine (no React)
apps/web/               React 18 + Vite + Zustand + Tailwind
```

## Commands
```bash
pnpm --filter @blackjack101/web dev       # dev server (usually starts on :5173)
pnpm --filter @blackjack101/web build     # production build
npx tsc --noEmit -p apps/web/tsconfig.json  # type check
```
Always run the type check before committing.

## Key files

**Core engine** (`packages/core/src/`):
- `engine.ts` — game state machine: deal, hit, stand, double, split, surrender
- `strategy.ts` — optimal action lookup table (Vegas Strip rules)
- `stats.ts` — session/hand record types, summarizeSession, getMistakeCategories
- `variants.ts` — VEGAS_STRIP ruleset (6-deck, S17, DAS, resplitAces, no surrender, 3:2)

**Web app** (`apps/web/src/`):
- `store/gameStore.ts` — game actions, per-hand mistake tracking, cloud sync triggers
- `store/statsStore.ts` — session history, addHandRecord, loadFromCloud
- `store/authStore.ts` — Supabase auth (email magic link, Google OAuth, phone methods kept for mobile)
- `store/settingsStore.ts` — ruleset + starting bankroll settings
- `lib/supabase.ts` — Supabase client (reads VITE_SUPABASE_URL, VITE_SUPABASE_ANON_KEY)
- `lib/sync.ts` — upsertSession, upsertProfile, loadUserData
- `App.tsx` — shell, nav, auth modal trigger, login/logout data sync
- `styles/index.css` — all CSS (no CSS modules or Tailwind utilities — plain classes only)

## Rules / conventions
- **No comments** unless the why is non-obvious
- **No new files** unless genuinely required — prefer editing existing ones
- **Plain CSS classes** in `index.css` — do not use Tailwind `className` utilities
- **Type check must pass** before any commit
- Vegas Strip rules are canonical — do not change the ruleset without explicit instruction

## Game rules in effect
6 decks, dealer stands soft 17, double after split allowed, re-split aces allowed, no surrender, blackjack pays 3:2, max 3 splits (4 hands total).

## State architecture
- `gameStore` owns live game state (deck, hands, bankroll, phase)
- `statsStore` owns session history and hand records (persisted to localStorage via Zustand `persist`)
- On every hand completion → `statsStore.addHandRecord()` → background sync to Supabase if logged in
- On login → `loadUserData()` fetches cloud sessions; if none exist, local data is uploaded

## Mistake tracking (important detail)
`handHadMistake` and `firstMistakeInfo` in gameStore track whether any play in a hand was wrong. The **first** wrong action's info is recorded to the stats store — not the last action — so "common mistakes" accurately reflects what actually went wrong.

## Auth
Supabase handles auth. Env vars needed locally in `apps/web/.env.local`:
```
VITE_SUPABASE_URL=
VITE_SUPABASE_ANON_KEY=
```
Same vars must be set in Vercel project settings for production.

## Supabase database tables
- `user_profiles` — `id` (FK auth.users), `bankroll`
- `game_sessions` — `id`, `user_id`, `start_time`, `end_time`, `start_bankroll`, `end_bankroll`, `rule_set_id`, `hands` (JSONB array of HandRecord)

## Vercel deploy
Root directory set to `apps/web`. Build config lives in `apps/web/vercel.json`. SPA rewrites handle direct URL navigation.
