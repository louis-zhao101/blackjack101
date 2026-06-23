# Blackjack 101 — Flutter + Firebase Migration

Full rewrite of the React/Supabase web app ([../apps/web](../apps/web)) into a single
Flutter codebase targeting **iOS, Android, and web**, backed by **Firebase**.
The original TypeScript app stays as the reference spec; nothing is deleted until cutover.

## Decisions
- Framework: **Flutter** (Dart).
- Web: **unified** — Flutter web replaces the Vite app (Vercel keeps running until cutover).
- Backend/auth: **Firebase** (Auth + Cloud Firestore) replaces Supabase.
- Data migration: **none** — fresh start, no existing users to preserve.
- Location: this `app_flutter/` folder inside the existing repo.

## Technology mapping
| React app | Flutter app |
|---|---|
| Zustand stores | Riverpod providers |
| React Router | go_router |
| Recharts | fl_chart |
| Supabase Auth | Firebase Auth (email/password, Google; phone later) |
| Supabase Postgres | Cloud Firestore |
| Zustand `persist` | Hive / shared_preferences |
| Vercel | Firebase Hosting |

## Target structure
```
lib/
  engine/    # pure Dart port of packages/core (DONE) — no Flutter imports
  state/     # Riverpod providers mirroring the Zustand stores
  services/  # Firebase auth, Firestore sync, local persistence
  ui/        # screens (play/learn/stats) + widgets + theme
```

## Firestore data model (planned)
- `users/{uid}` → `{ bankroll }`              (replaces `user_profiles`)
- `users/{uid}/sessions/{sessionId}` → Session fields + `hands` array  (replaces `game_sessions`)
- Security rules: a user may read/write only their own `users/{uid}` subtree.

## Phases
1. **Engine port** — DONE. `lib/engine/` (cards, variants, engine, strategy, stats) with
   59 passing parity tests in `test/engine_test.dart`. Behavior matches the TS engine
   (dealer S17, split-ace handling, blackjack-only-when-not-split, 25% reshuffle,
   longest-streak, mistake categorization). Stats types include JSON round-trip for Firestore/Hive.
2. **State layer** — Riverpod providers: game, stats, auth, settings. Preserve subtle rules:
   first-mistake-per-hand recording, auto-rebet, 60-min session auto-rotation, running play stats.
3. **Firebase** — project setup, Auth (email/password + Google), Firestore sync
   (upsertSession / upsertProfile / loadUserData), security rules, Hive offline cache.
4. **UI** — theme from CSS tokens; GameTable, Learn (4 tabs), Stats (fl_chart + auth gate);
   responsive strategy-chart sidebar/bottom-sheet.
5. **Ship** — web → Firebase Hosting; Android → Play Store; iOS → App Store
   (note: market the iOS app as an educational no-real-money trainer to pass gambling review).

## Auth status (phone-only)
- Firebase project `blackjack101-app`; Phone provider **enabled** server-side.
- Test number for dev/review: `+1 555 123 4567` → code `123456`.
- ⚠️ **iOS and Android phone auth are NOT fully set up yet.** Still required before
  phone auth works on real devices:
  - iOS: upload APNs auth key to Firebase; add reversed-client-ID URL scheme to `Info.plist`.
  - Android: register debug + release SHA-1/SHA-256 fingerprints.
  - Project is on the **Spark (free)** plan — upgrade to **Blaze** for production SMS volume.
- Web phone auth works on `localhost` + the Firebase Hosting domains via reCAPTCHA.

## Notes
- Engine stays Flutter-free on purpose (testable + portable), same discipline as `packages/core`.
- Run `flutter test` and `flutter analyze` before each commit.
