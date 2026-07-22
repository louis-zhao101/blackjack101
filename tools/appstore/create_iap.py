#!/usr/bin/env python3
"""Create Blackjack 101's in-app purchases in App Store Connect via the API.

Handles the 41 non-consumables (lifetime + 40 cosmetics) end to end: create the
IAP, add its en-US localization, set the USD price (all territories), and make it
available. Auto-renewable subscriptions (the 2 Pro plans) are opt-in via
--subscriptions because they need a group + price-point wiring and are easy to do
by hand — do those in ASC or pass the flag once you've tested a cosmetic first.

SAFETY
  * --dry-run is the DEFAULT. It writes nothing; it just prints the plan (and,
    if credentials are present, checks which products already exist).
  * --commit performs the creates. It is idempotent: anything already in ASC
    (matched by productId) is skipped.
  * Test one product first:  ... --commit --only theme_slate

CREDENTIALS (App Store Connect API key with "App Manager" role)
  export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  export ASC_KEY_ID=XXXXXXXXXX
  export ASC_PRIVATE_KEY=/absolute/path/AuthKey_XXXXXXXXXX.p8

DEPENDENCIES
  python3 -m pip install pyjwt cryptography requests

USAGE
  python3 create_iap.py --dry-run                 # show the plan (no writes)
  python3 create_iap.py --dump-manifest products.json
  python3 create_iap.py --commit --only theme_slate
  python3 create_iap.py --commit                  # all non-consumables
  python3 create_iap.py --commit --subscriptions  # + the 2 Pro plans
"""

import argparse
import json
import os
import sys
import time

BUNDLE_ID = "com.blackjack101.blackjack101"
BASE_TERRITORY = "USA"
BASE_URL = "https://api.appstoreconnect.apple.com"
REVIEW_NOTE = "Cosmetic-only unlock; no gameplay advantage or real-money gambling."
SUB_GROUP_REF = "Blackjack101 Pro"

# ---------------------------------------------------------------------------
# Catalog — mirrors app_flutter/lib/state/store_provider.dart. Display names are
# suffixed by type so shared base names (Illuminated, Greek Vase, ...) stay
# unique in ASC receipts / Manage Purchases. The app UI uses its own names.
# ---------------------------------------------------------------------------
DESC = {
    "theme": "A premium blackjack table theme.",
    "cardback": "A premium card-back design.",
    "chips": "A premium chip color set.",
    "deck": "A hand-illustrated 52-card deck.",
    "bundle": "A deck plus its matching card back.",
}
THEMES = [("theme_midnight_blue", "Midnight Blue"), ("theme_crimson", "Crimson"),
          ("theme_obsidian", "Obsidian"), ("theme_slate", "Slate")]
BACKS = [("back_coral", "Coral Club"), ("back_rose", "Rose"), ("back_black_gold", "Black & Gold"),
         ("back_emerald", "Emerald"), ("back_sapphire", "Sapphire"), ("back_jade", "Jade"),
         ("back_garnet", "Garnet"), ("back_platinum", "Platinum"), ("back_illuminated", "Illuminated"),
         ("back_ukiyoe", "Ukiyo-e"), ("back_greek", "Greek Vase"), ("back_egyptian", "Egyptian"),
         ("back_gyotaku", "Gyotaku"), ("back_tarot", "Tarot"), ("back_audubon", "Audubon")]
CHIPS = [("chips_monochrome", "Ivory & Onyx"), ("chips_sunset", "Sunset"),
         ("chips_illuminated", "Illuminated"), ("chips_ukiyoe", "Ukiyo-e"), ("chips_greek", "Greek Vase"),
         ("chips_egyptian", "Egyptian"), ("chips_gyotaku", "Gyotaku")]
DECKS = [("deck_illuminated", "Illuminated"), ("deck_ukiyoe", "Ukiyo-e"), ("deck_greek", "Greek Vase"),
         ("deck_egyptian", "Egyptian"), ("deck_gyotaku", "Gyotaku"), ("deck_tarot", "Tarot"),
         ("deck_audubon", "Audubon Birds")]
BUNDLES = [("bundle_illuminated", "Illuminated Set"), ("bundle_ukiyoe", "Ukiyo-e Set"),
           ("bundle_greek", "Greek Vase Set"), ("bundle_egyptian", "Egyptian Set"),
           ("bundle_gyotaku", "Gyotaku Set"), ("bundle_tarot", "Tarot Set"),
           ("bundle_audubon", "Audubon Set")]


def build_catalog():
    items = [
        dict(kind="subscription", product_id="blackjack_pro_monthly_1", name="Pro Monthly",
             desc="All Pro training features, monthly.", price=3.99, period="ONE_MONTH"),
        dict(kind="subscription", product_id="blackjack_pro_yearly_1", name="Pro Yearly",
             desc="All Pro training features, yearly.", price=19.99, period="ONE_YEAR"),
        dict(kind="NON_CONSUMABLE", product_id="blackjack_pro_lifetime", name="Pro Lifetime",
             desc="Unlock every Pro feature and cosmetic.", price=34.99),
    ]
    for pid, n in THEMES:
        items.append(dict(kind="NON_CONSUMABLE", product_id=pid, name=f"{n} Table Theme", desc=DESC["theme"], price=1.99))
    for pid, n in BACKS:
        items.append(dict(kind="NON_CONSUMABLE", product_id=pid, name=f"{n} Card Back", desc=DESC["cardback"], price=1.99))
    for pid, n in CHIPS:
        items.append(dict(kind="NON_CONSUMABLE", product_id=pid, name=f"{n} Chips", desc=DESC["chips"], price=1.99))
    for pid, n in DECKS:
        items.append(dict(kind="NON_CONSUMABLE", product_id=pid, name=f"{n} Deck", desc=DESC["deck"], price=3.99))
    for pid, n in BUNDLES:
        items.append(dict(kind="NON_CONSUMABLE", product_id=pid, name=n, desc=DESC["bundle"], price=4.99))
    for it in items:
        if len(it["name"]) > 30:
            raise SystemExit(f"Display name too long (>30): {it['name']!r}")
        if len(it["desc"]) > 45:
            raise SystemExit(f"Description too long (>45): {it['desc']!r}")
    return items


# ---------------------------------------------------------------------------
# API client
# ---------------------------------------------------------------------------
class ASC:
    def __init__(self, issuer, key_id, private_key):
        import jwt  # PyJWT
        self._jwt = jwt
        self.issuer, self.key_id, self.private_key = issuer, key_id, private_key
        import requests
        self.http = requests.Session()
        self._token = None
        self._token_exp = 0

    def token(self):
        now = int(time.time())
        if not self._token or now >= self._token_exp - 60:
            exp = now + 1200
            self._token = self._jwt.encode(
                {"iss": self.issuer, "iat": now, "exp": exp, "aud": "appstoreconnect-v1"},
                self.private_key, algorithm="ES256",
                headers={"alg": "ES256", "kid": self.key_id, "typ": "JWT"})
            self._token_exp = exp
        return self._token

    def _req(self, method, path, **kw):
        url = path if path.startswith("http") else BASE_URL + path
        for attempt in range(4):
            r = self.http.request(method, url,
                                   headers={"Authorization": f"Bearer {self.token()}",
                                            "Content-Type": "application/json"}, **kw)
            if r.status_code == 429 or r.status_code >= 500:
                time.sleep(2 ** attempt)
                continue
            if r.status_code >= 400:
                raise RuntimeError(f"{method} {url} -> {r.status_code}\n{r.text}")
            return r.json() if r.text else {}
        raise RuntimeError(f"{method} {url} failed after retries")

    def get(self, path, **kw):
        return self._req("GET", path, **kw)

    def post(self, path, body):
        return self._req("POST", path, data=json.dumps(body))

    def paged(self, path):
        out, url = [], path
        while url:
            data = self.get(url)
            out.extend(data.get("data", []))
            url = data.get("links", {}).get("next")
        return out


# ---------------------------------------------------------------------------
# Lookups
# ---------------------------------------------------------------------------
def find_app_id(api):
    data = api.get(f"/v1/apps?filter[bundleId]={BUNDLE_ID}").get("data", [])
    if not data:
        raise SystemExit(f"No app found for bundleId {BUNDLE_ID}. Check the key's app access.")
    return data[0]["id"]


def existing_iap_ids(api, app_id):
    return {i["attributes"]["productId"]: i["id"]
            for i in api.paged(f"/v1/apps/{app_id}/inAppPurchasesV2?limit=200")}


def existing_sub_ids(api, group_id):
    if not group_id:
        return {}
    return {s["attributes"]["productId"]: s["id"]
            for s in api.paged(f"/v1/subscriptionGroups/{group_id}/subscriptions?limit=200")}


def all_territory_ids(api):
    return [t["id"] for t in api.paged("/v1/territories?limit=200")]


def price_point_id(api, iap_id, price):
    for pp in api.paged(f"/v2/inAppPurchases/{iap_id}/pricePoints?filter[territory]={BASE_TERRITORY}&limit=200"):
        if abs(float(pp["attributes"]["customerPrice"]) - price) < 0.005:
            return pp["id"]
    raise RuntimeError(f"No {BASE_TERRITORY} price point == {price} for IAP {iap_id}")


def sub_price_point_id(api, sub_id, price):
    for pp in api.paged(f"/v1/subscriptions/{sub_id}/pricePoints?filter[territory]={BASE_TERRITORY}&limit=200"):
        if abs(float(pp["attributes"]["customerPrice"]) - price) < 0.005:
            return pp["id"]
    raise RuntimeError(f"No {BASE_TERRITORY} price point == {price} for subscription {sub_id}")


# ---------------------------------------------------------------------------
# Creates (non-consumables)
# ---------------------------------------------------------------------------
def set_iap_price(api, iap_id, price):
    """Set (or replace) a non-consumable's price schedule — one manual USD price
    that Apple equalizes to other territories. Re-POSTing replaces the current
    schedule, so this doubles as a repricing call."""
    pp_id = price_point_id(api, iap_id, price)
    api.post("/v1/inAppPurchasePriceSchedules", {
        "data": {"type": "inAppPurchasePriceSchedules",
                 "relationships": {
                     "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
                     "baseTerritory": {"data": {"type": "territories", "id": BASE_TERRITORY}},
                     "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${p}"}]}}},
        "included": [{"type": "inAppPurchasePrices", "id": "${p}",
                      "attributes": {"startDate": None},
                      "relationships": {
                          "inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}},
                          "inAppPurchasePricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": pp_id}}}}]})


def create_nonconsumable(api, app_id, item, territories):
    iap = api.post("/v2/inAppPurchases", {"data": {
        "type": "inAppPurchases",
        "attributes": {"name": item["name"], "productId": item["product_id"],
                       "inAppPurchaseType": item["kind"], "reviewNote": REVIEW_NOTE},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
    iap_id = iap["data"]["id"]

    api.post("/v1/inAppPurchaseLocalizations", {"data": {
        "type": "inAppPurchaseLocalizations",
        "attributes": {"locale": "en-US", "name": item["name"], "description": item["desc"]},
        "relationships": {"inAppPurchaseV2": {"data": {"type": "inAppPurchases", "id": iap_id}}}}})

    set_iap_price(api, iap_id, item["price"])

    api.post("/v1/inAppPurchaseAvailabilities", {"data": {
        "type": "inAppPurchaseAvailabilities",
        "attributes": {"availableInNewTerritories": True},
        "relationships": {
            "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap_id}},
            "availableTerritories": {"data": [{"type": "territories", "id": t} for t in territories]}}}})
    return iap_id


# ---------------------------------------------------------------------------
# Creates (subscriptions) — opt-in
# ---------------------------------------------------------------------------
def ensure_sub_group(api, app_id):
    for g in api.paged(f"/v1/apps/{app_id}/subscriptionGroups?limit=200"):
        if g["attributes"]["referenceName"] == SUB_GROUP_REF:
            return g["id"]
    g = api.post("/v1/subscriptionGroups", {"data": {
        "type": "subscriptionGroups", "attributes": {"referenceName": SUB_GROUP_REF},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}})
    gid = g["data"]["id"]
    api.post("/v1/subscriptionGroupLocalizations", {"data": {
        "type": "subscriptionGroupLocalizations",
        "attributes": {"locale": "en-US", "name": "Blackjack 101 Pro"},
        "relationships": {"subscriptionGroup": {"data": {"type": "subscriptionGroups", "id": gid}}}}})
    return gid


def create_subscription(api, group_id, item):
    sub = api.post("/v1/subscriptions", {"data": {
        "type": "subscriptions",
        "attributes": {"name": item["name"], "productId": item["product_id"],
                       "subscriptionPeriod": item["period"], "familySharable": False},
        "relationships": {"group": {"data": {"type": "subscriptionGroups", "id": group_id}}}}})
    sub_id = sub["data"]["id"]

    api.post("/v1/subscriptionLocalizations", {"data": {
        "type": "subscriptionLocalizations",
        "attributes": {"locale": "en-US", "name": item["name"], "description": item["desc"]},
        "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sub_id}}}}})

    # Setting a brand-new subscription's first price via the API is flaky (the
    # price-point relationship is often rejected with a 409). Best-effort: if it
    # fails, the subscription + localization still land and the price is a quick
    # manual step in App Store Connect.
    try:
        pp_id = sub_price_point_id(api, sub_id, item["price"])
        api.post("/v1/subscriptionPrices", {"data": {
            "type": "subscriptionPrices",
            "attributes": {"startDate": None},
            "relationships": {
                "subscription": {"data": {"type": "subscriptions", "id": sub_id}},
                "subscriptionPricePoint": {"data": {"type": "subscriptionPricePoints", "id": pp_id}}}}})
    except Exception as e:  # noqa: BLE001
        print(f"[price not set — set ${item['price']} in ASC UI; {str(e).splitlines()[0]}]",
              end=" ", flush=True)
    return sub_id


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def creds():
    issuer, key_id, key_path = (os.environ.get("ASC_ISSUER_ID"),
                                os.environ.get("ASC_KEY_ID"),
                                os.environ.get("ASC_PRIVATE_KEY"))
    if not (issuer and key_id and key_path):
        return None
    with open(os.path.expanduser(key_path)) as f:
        return issuer, key_id, f.read()


def main():
    ap = argparse.ArgumentParser(description="Create Blackjack 101 IAPs in App Store Connect.")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", help="Print the plan; write nothing (default).")
    g.add_argument("--commit", action="store_true", help="Actually create the products.")
    ap.add_argument("--only", metavar="PRODUCT_ID", help="Act on just this one product (test first!).")
    ap.add_argument("--subscriptions", action="store_true", help="Also create the 2 Pro subscriptions.")
    ap.add_argument("--reprice", action="store_true",
                    help="Update prices of EXISTING non-consumables to the catalog price (no create).")
    ap.add_argument("--dump-manifest", metavar="FILE", help="Write the catalog to a JSON file and exit.")
    args = ap.parse_args()

    catalog = build_catalog()

    if args.dump_manifest:
        with open(args.dump_manifest, "w") as f:
            json.dump({"bundleId": BUNDLE_ID, "baseTerritory": BASE_TERRITORY,
                       "subscriptionGroup": SUB_GROUP_REF, "products": catalog}, f, indent=2)
        print(f"Wrote {len(catalog)} products to {args.dump_manifest}")
        return

    subs = [c for c in catalog if c["kind"] == "subscription"]
    ncs = [c for c in catalog if c["kind"] == "NON_CONSUMABLE"]
    if args.only:
        catalog = [c for c in catalog if c["product_id"] == args.only]
        if not catalog:
            raise SystemExit(f"--only {args.only}: no such product")
        subs = [c for c in catalog if c["kind"] == "subscription"]
        ncs = [c for c in catalog if c["kind"] == "NON_CONSUMABLE"]
    do_subs = args.subscriptions or (args.only and subs)

    print(f"App bundle: {BUNDLE_ID}")
    print(f"Non-consumables: {len(ncs)}   Subscriptions: {len(subs)}"
          f"{' (skipped — pass --subscriptions)' if subs and not do_subs else ''}\n")
    for c in catalog:
        tag = "SUB " if c["kind"] == "subscription" else "NC  "
        skip = "" if (c["kind"] != "subscription" or do_subs) else "  [skipped]"
        print(f"  {tag} {c['product_id']:<26} ${c['price']:<6} {c['name']}{skip}")
    print()

    c = creds()
    if not args.commit:
        if not c:
            print("DRY RUN (no credentials set) — plan above. Set ASC_* env vars to check "
                  "existing products, then re-run with --commit.")
            return
        api = ASC(*c)
        app_id = find_app_id(api)
        have = existing_iap_ids(api, app_id)
        group_id = None
        for g2 in api.paged(f"/v1/apps/{app_id}/subscriptionGroups?limit=200"):
            if g2["attributes"]["referenceName"] == SUB_GROUP_REF:
                group_id = g2["id"]
        have.update(existing_sub_ids(api, group_id))
        print(f"App id: {app_id}")
        for c2 in catalog:
            print(f"  [{'EXISTS' if c2['product_id'] in have else 'NEW   '}] {c2['product_id']}")
        print("\nDRY RUN — re-run with --commit to create the NEW ones.")
        return

    if not c:
        raise SystemExit("--commit needs ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY env vars.")
    api = ASC(*c)
    app_id = find_app_id(api)
    print(f"App id: {app_id}")
    have = existing_iap_ids(api, app_id)

    if args.reprice:
        for item in ncs:
            pid = item["product_id"]
            if pid not in have:
                print(f"  skip (missing) {pid}")
                continue
            print(f"  repricing      {pid} -> ${item['price']} ...", end=" ", flush=True)
            set_iap_price(api, have[pid], item["price"])
            print("done")
        print("\nDone repricing. (Subscription prices are set in the ASC UI.)")
        return

    territories = all_territory_ids(api) if ncs else []
    for item in ncs:
        pid = item["product_id"]
        if pid in have:
            print(f"  skip (exists)  {pid}")
            continue
        print(f"  creating       {pid} ...", end=" ", flush=True)
        create_nonconsumable(api, app_id, item, territories)
        print("done")

    if do_subs and subs:
        group_id = ensure_sub_group(api, app_id)
        have_subs = existing_sub_ids(api, group_id)
        for item in subs:
            pid = item["product_id"]
            if pid in have_subs:
                print(f"  skip (exists)  {pid}")
                continue
            print(f"  creating sub   {pid} ...", end=" ", flush=True)
            create_subscription(api, group_id, item)
            print("done")

    print("\nDone. Review the products in App Store Connect, add review screenshots at "
          "submission, then import/map them in RevenueCat.")


if __name__ == "__main__":
    main()
