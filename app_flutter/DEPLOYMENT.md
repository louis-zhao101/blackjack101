# Blackjack 101 (Flutter) — Deployment & Testing

Practical guide for running, testing, building, and shipping the Flutter app
(`app_flutter/`). Firebase project: **`blackjack101-app`**. App/bundle id:
**`com.blackjack101.blackjack101`**.

All commands assume you're in `app_flutter/`:

```bash
cd app_flutter
```

---

## 1. Prerequisites

- **Flutter** 3.41+ (`flutter --version`) and Dart 3.11+
- **Xcode** 26+ with iOS simulators (for iOS)
- **CocoaPods** 1.16+ (`pod --version`)
- **Android Studio** / SDK + an emulator or device (for Android)
- **Firebase CLI** (`firebase --version`) logged in (`firebase login`)
- **FlutterFire CLI** (`dart pub global activate flutterfire_cli`)
- First-time setup: `flutter pub get`

---

## 2. Running locally

### Web (fastest for iterating)
```bash
flutter run -d chrome --web-port 8081
```
- `r` = hot reload, `R` = hot restart, `q` = quit.
- Web phone auth works on `localhost` (an authorized domain) via reCAPTCHA.

### iOS Simulator
```bash
open -a Simulator
flutter run -d <simulator-id>     # list ids with: flutter devices
```
- First build is slow (~5 min: pod install + compiling Firebase/gRPC). Later builds are fast.
- If pods fail with "specs repository is too out-of-date", run:
  `cd ios && pod repo update && pod install && cd ..`

### Android emulator/device
```bash
flutter run -d <android-id>
```
- Phone auth on a debug Android build needs the debug **SHA-1** registered in Firebase
  (Project Settings → Your apps → Android → Add fingerprint). Get it with:
  `cd android && ./gradlew signingReport` (look for the `debug` variant SHA-1).

---

## 3. Testing

### Engine unit tests (59 tests, parity with the original TS engine)
```bash
flutter test
```

### Static analysis (must be clean before committing)
```bash
flutter analyze
```

### Test phone numbers (no real SMS, no charges)
Configured in Firebase → Authentication → Sign-in method → Phone → "Phone numbers for testing":

| Phone | Code |
|-------|------|
| `+12025550123` | `123456` |

> If a test number stops working with "code is incorrect", confirm it still exists in that
> list — console edits can replace it. Use a number with a **real** area code (e.g. 202, 626);
> fake `555` area codes fail region geolocation.

### Manual smoke test checklist
1. Sign in with the test number above → lands on the game table.
2. Place a bet (chips) → **Deal** → play Hit/Stand/Double/Split; balance + bet stay visible up top.
3. Finish a hand → strategy hint (✓/✕) shows; **Stats** tab populates (hands, accuracy, charts).
4. **Learn** tab → all 4 sub-tabs render; tap strategy-chart cells for explanations.
5. Header palette icon → switch table skins (Classic Green / Midnight Blue / Crimson).
6. Sign out (account menu) → back to sign-in.

> **Always judge performance in `--release` / `--profile`.** Debug builds are much slower
> (e.g. first paint of the strategy chart) and don't reflect the shipped app.

---

## 4. Building releases

### Web
```bash
flutter build web --no-web-resources-cdn
```
- `--no-web-resources-cdn` bundles CanvasKit locally. **Required** — without it the app
  fetches CanvasKit from a Google CDN at runtime and shows a blank white screen if that
  fetch is blocked.

### iOS (App Store)
```bash
flutter build ipa
```
- Needs an Apple Developer account ($99/yr) and signing configured in Xcode
  (`open ios/Runner.xcworkspace`).
- iOS deployment target is **15.0** (required by `cloud_firestore`).

### Android (Play Store)
```bash
flutter build appbundle      # .aab for Play Store
flutter build apk            # .apk for sideloading/testing
```
- Needs a Google Play Developer account ($25 one-time) and a release keystore.
- Register the **release** SHA-1/SHA-256 in Firebase too (not just debug).

---

## 5. Deploying the web app (Firebase Hosting)

Hosting is configured in `firebase.json` (`public: build/web`, SPA rewrites).

```bash
flutter build web --no-web-resources-cdn
firebase deploy --only hosting --project blackjack101-app
```
Live URLs after deploy:
- `https://blackjack101-app.web.app`
- `https://blackjack101-app.firebaseapp.com`

When using a custom domain, add it under Authentication → Settings → Authorized domains
so phone-auth reCAPTCHA works there.

### Firestore security rules
```bash
firebase deploy --only firestore:rules --project blackjack101-app
```
Rules (`firestore.rules`) restrict each user to their own `users/{uid}` subtree.

---

## 6. Firebase backend reference

- **Auth:** phone-only. Phone provider enabled; Google provider also enabled (only to
  provision the iOS OAuth `CLIENT_ID` that phone-auth needs — not used in the UI).
- **SMS region policy:** allowlist of ~30 countries (Authentication → Settings → SMS region).
  Prevents SMS-pumping fraud. Add countries there as your audience grows.
- **Firestore data model:**
  - `users/{uid}` → `{ bankroll, updatedAt }`
  - `users/{uid}/sessions/{sessionId}` → session JSON (incl. `hands`)
- **Plan:** currently **Spark (free)**. Production phone auth at volume needs **Blaze**
  (pay-as-you-go) — real SMS isn't free.

---

## 7. Known gotchas (already handled, keep in mind)

- **White screen on web** → build with `--no-web-resources-cdn` (CanvasKit CDN issue).
- **iOS pod errors** → `cd ios && pod repo update && pod install`.
- **iOS `MISSING_CLIENT_IDENTIFIER`** → needs the reversed-client-ID URL scheme in
  `Info.plist` (present) + the OAuth client (Google provider enabled).
- **Debug perf** → always benchmark in `--release`.

---

## 8. Still pending for full production

- iOS: upload an **APNs auth key** to Firebase so production phone auth uses silent push
  instead of reCAPTCHA.
- Android: register **release** SHA fingerprints.
- Upgrade Firebase to **Blaze** for real SMS volume.
- App Store / Play Store listings: icons, screenshots, privacy policy, and copy that
  states this is an **educational, no-real-money** trainer (avoids gambling-category review issues).
