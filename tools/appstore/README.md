# App Store Connect — bulk-create in-app purchases

`create_iap.py` creates Blackjack 101's in-app purchases in App Store Connect via
the App Store Connect API. It's idempotent (skips anything already there) and
defaults to a no-write dry run.

## What it creates
- **41 non-consumables**: `blackjack_pro_lifetime` + 40 cosmetics (themes, card
  backs, chips, decks, sets). Full pipeline: IAP → en-US localization → USD price
  (all territories) → availability.
- **2 subscriptions** (`blackjack_pro_monthly_1`, `blackjack_pro_yearly_1`):
  opt-in with `--subscriptions`. Creates/uses the "Blackjack101 Pro" group.

The catalog mirrors `app_flutter/lib/state/store_provider.dart`. Prices:
$1.99 cosmetics · $3.99 decks · $4.99 sets · $1.99/mo · $9.99/yr · $16.99 lifetime.
ASC display names are type-suffixed ("Illuminated Deck") so receipts stay legible.

## 1. Get an App Store Connect API key
App Store Connect → **Users and Access → Integrations → App Store Connect API** →
**+**. Role: **App Manager** (or Admin). Note the **Issuer ID** and **Key ID**,
and download the `.p8` **once**.

## 2. Install deps
```bash
python3 -m pip install pyjwt cryptography requests
```

## 3. Set credentials
```bash
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_ID=XXXXXXXXXX
export ASC_PRIVATE_KEY=/absolute/path/AuthKey_XXXXXXXXXX.p8
```

## 4. Run it — staged
```bash
# a) See the plan + which products already exist (no writes)
python3 create_iap.py --dry-run

# b) Create ONE product first and verify it in ASC before the rest
python3 create_iap.py --commit --only theme_slate

# c) All 41 non-consumables
python3 create_iap.py --commit

# d) Add the 2 subscriptions (or just do these 2 by hand in ASC)
python3 create_iap.py --commit --subscriptions
```

`--dump-manifest products.json` writes the catalog to JSON without touching ASC.

## Notes / gotchas
- **Test with `--only` first.** The write endpoints (price schedule, availability,
  subscription price points) can't be tested without a real key; validate one
  product end-to-end before the bulk run.
- IAPs still need a **review screenshot** at submission time — the API doesn't set
  that; add it in ASC before submitting for review.
- After creation, in **RevenueCat**: make sure the 3 Pro products (App Store, not
  Test Store) are attached to `blackjack_pro` (all three) and `all_access`
  (lifetime only), and are in the current Offering. Cosmetics are bought directly
  by product id, so they don't need entitlements.
- Re-running is safe — existing products (matched by productId) are skipped.
- **Subscription prices are set manually.** The API reliably creates the group,
  subscriptions, and localizations, but setting a brand-new subscription's first
  price via the API returns a 409 (a known ASC quirk). The script logs this and
  moves on — set the 2 prices in the ASC UI (open each subscription → Add price →
  $1.99 monthly / $9.99 yearly). Non-consumable prices ARE set by the script.
