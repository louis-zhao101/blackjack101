#!/usr/bin/env python3
"""Push the App Store listing metadata to App Store Connect via the API.

Sets, for the editable 1.0.0 version (en-US):
  - App Info localization:   name, subtitle  (+ privacy policy URL, best-effort)
  - Version localization:    description, keywords, promotional text, support &
                             marketing URLs, what's new
  - Categories:              primary + secondary (+ secondary subcategory)

Reuses create_iap.py's ASC client + credentials (ASC_KEY_ID / ASC_ISSUER_ID /
ASC_PRIVATE_KEY). Nothing is submitted for review — this only fills the draft.

Usage:
  python3 set_metadata.py --dry-run   # discover IDs, show current vs new (default)
  python3 set_metadata.py --commit    # write the metadata
"""
import argparse
import json

import create_iap as c

LOCALE = "en-US"

NAME = "Blackjack 101 - Strategy"
SUBTITLE = "Practice trainer & drills"
KEYWORDS = "basic strategy,card counting,21,casino,dealer,odds,cheat sheet,vegas,split,double,drills,trainer"
PROMO = ("Learn perfect basic strategy with quick lessons, unlimited practice, and "
         "instant feedback on every hand. It's a trainer — no real-money gambling, "
         "just pure strategy.")
DESCRIPTION = """Blackjack 101 is the fastest way to learn and master perfect basic strategy — the proven system that shrinks the house edge to almost nothing.

Never played a hand? Start from the rules. Already play but keep second-guessing yourself? Drill the tough spots until the right move is automatic.

LEARN
• Short, focused lessons — from the rules to optimal play
• Clear guidance on hits, stands, doubles, splits, and soft hands
• The full strategy chart, explained cell by cell

PRACTICE
• Unlimited hands with instant feedback on every decision
• Test Yourself drills for any hand against any dealer upcard
• Difficulty tiers that scale as you improve

TRACK
• Watch your accuracy climb session over session
• Pinpoint your most common mistakes and fix them
• Unlimited stats history with Pro

CUSTOMIZE
• Hand-illustrated card decks and table themes

Blackjack 101 is a training tool — there's no betting, no wagering, and no prizes. Just you, the strategy, and steady improvement.

Play smarter. Start with Blackjack 101.

———
Blackjack 101 Pro is an auto-renewable subscription (monthly or yearly). Payment is charged to your Apple ID at purchase. It renews automatically unless turned off at least 24 hours before the period ends; manage or cancel anytime in your App Store account settings.

Terms of Use (EULA): https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: https://blackjack101.app/privacy.html"""
SUPPORT_URL = "https://blackjack101.app"
MARKETING_URL = "https://blackjack101.app"
PRIVACY_URL = "https://blackjack101.app/privacy.html"
WHATS_NEW = "First release — learn and master blackjack basic strategy."

PRIMARY_CATEGORY = "EDUCATION"
SECONDARY_CATEGORY = "GAMES"
SECONDARY_SUBCATEGORY = "GAMES_CARD"

# Apple field limits — validated before any write.
LIMITS = [("name", NAME, 30), ("subtitle", SUBTITLE, 30), ("keywords", KEYWORDS, 100),
          ("promotionalText", PROMO, 170), ("description", DESCRIPTION, 4000),
          ("whatsNew", WHATS_NEW, 4000)]

EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
            "INVALID_BINARY", "WAITING_FOR_REVIEW", "DEVELOPER_REMOVED_FROM_SALE"}


def check_limits():
    for name, val, lim in LIMITS:
        n = len(val)
        flag = "  <-- TOO LONG" if n > lim else ""
        print(f"  {name:<16} {n:>4}/{lim}{flag}")
        if n > lim:
            raise SystemExit(f"{name} exceeds {lim} chars")


def pick_editable(items, label):
    for it in items:
        st = it["attributes"].get("appStoreState") or it["attributes"].get("state")
        if st in EDITABLE:
            return it
    if items:
        return items[0]
    raise SystemExit(f"No {label} found for the app.")


def find_loc_id(api, path):
    for loc in api.paged(path):
        if loc["attributes"]["locale"] == LOCALE:
            return loc["id"]
    return None


def patch(api, res_type, res_id, attrs):
    api._req("PATCH", f"/v1/{res_type}/{res_id}",
             data=json.dumps({"data": {"type": res_type, "id": res_id, "attributes": attrs}}))


def main():
    ap = argparse.ArgumentParser(description="Push App Store listing metadata.")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", help="Discover + preview only (default).")
    g.add_argument("--commit", action="store_true", help="Write the metadata.")
    args = ap.parse_args()

    print("Field lengths:")
    check_limits()
    print()

    creds = c.creds()
    if not creds:
        raise SystemExit("Set ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY.")
    api = c.ASC(*creds)
    app_id = c.find_app_id(api)

    info = pick_editable(api.paged(f"/v1/apps/{app_id}/appInfos?limit=50"), "appInfo")
    ver = pick_editable(api.paged(f"/v1/apps/{app_id}/appStoreVersions?limit=50"), "version")
    info_id, ver_id = info["id"], ver["id"]
    ver_str = ver["attributes"].get("versionString")
    info_loc = find_loc_id(api, f"/v1/appInfos/{info_id}/appInfoLocalizations")
    ver_loc = find_loc_id(api, f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations")

    print(f"App {app_id} | appInfo {info_id} | version {ver_str} {ver_id}")
    print(f"en-US appInfoLoc={info_loc}  versionLoc={ver_loc}")
    print(f"Categories -> primary {PRIMARY_CATEGORY}, secondary {SECONDARY_CATEGORY} / {SECONDARY_SUBCATEGORY}\n")

    if not args.commit:
        print("DRY RUN — re-run with --commit to write the above metadata.")
        return
    if not (info_loc and ver_loc):
        raise SystemExit("Missing en-US localization; create it once in ASC, then re-run.")

    # 1. App Info localization: name + subtitle
    print("Setting name + subtitle ...", end=" ", flush=True)
    patch(api, "appInfoLocalizations", info_loc, {"name": NAME, "subtitle": SUBTITLE})
    print("done")

    # privacy policy URL (best-effort — attribute name/support varies)
    try:
        patch(api, "appInfoLocalizations", info_loc, {"privacyPolicyUrl": PRIVACY_URL})
        print("Set privacy policy URL ... done")
    except Exception as e:  # noqa: BLE001
        print(f"Privacy URL not set via API — set it in App Privacy. ({str(e).splitlines()[0]})")

    # 2. Version localization (whatsNew is only editable on updates, not v1 — set
    #    separately so its expected failure on a first release doesn't block the rest)
    print("Setting description/keywords/promo/URLs ...", end=" ", flush=True)
    patch(api, "appStoreVersionLocalizations", ver_loc, {
        "description": DESCRIPTION, "keywords": KEYWORDS, "promotionalText": PROMO,
        "supportUrl": SUPPORT_URL, "marketingUrl": MARKETING_URL})
    print("done")
    try:
        patch(api, "appStoreVersionLocalizations", ver_loc, {"whatsNew": WHATS_NEW})
        print("Set what's new ... done")
    except Exception as e:  # noqa: BLE001
        print(f"What's New skipped (not editable on a first release). ({str(e).splitlines()[0]})")

    # 3. Categories
    try:
        api._req("PATCH", f"/v1/appInfos/{info_id}", data=json.dumps({"data": {
            "type": "appInfos", "id": info_id, "relationships": {
                "primaryCategory": {"data": {"type": "appCategories", "id": PRIMARY_CATEGORY}},
                "secondaryCategory": {"data": {"type": "appCategories", "id": SECONDARY_CATEGORY}},
                "secondarySubcategoryOne": {"data": {"type": "appCategories", "id": SECONDARY_SUBCATEGORY}},
            }}}))
        print("Set categories ... done")
    except Exception as e:  # noqa: BLE001
        print(f"Categories not set via API — set them in ASC. ({str(e).splitlines()[0]})")

    print("\nDone. Review the listing in App Store Connect (nothing was submitted).")


if __name__ == "__main__":
    main()
