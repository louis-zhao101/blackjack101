#!/usr/bin/env python3
"""Upload an IAP review screenshot to every in-app purchase (and, opt-in, the
subscriptions) — clears the "Missing Metadata" state that blocks submission.

Apple only shows this screenshot to reviewers, so one image reused across all
products is fine. Any image works: it's letterboxed to 1242x2688 (an accepted
IAP screenshot size) before upload.

Reuses the ASC client + lookups from create_iap.py. Same credentials:
  ASC_ISSUER_ID / ASC_KEY_ID / ASC_PRIVATE_KEY   (see create_iap README)

USAGE
  python3 upload_screenshots.py --image shot.png --dry-run
  python3 upload_screenshots.py --image shot.png --commit --only theme_slate
  python3 upload_screenshots.py --image shot.png --commit
  python3 upload_screenshots.py --image shot.png --commit --subscriptions
Add --force to replace a screenshot a product already has.
"""

import argparse
import hashlib
import io
import json
import os

import create_iap as c

TARGET_SIZE = (1242, 2688)  # accepted IAP review-screenshot dimensions (6.5")


def prep_image(path):
    from PIL import Image
    im = Image.open(path).convert("RGB")
    canvas = Image.new("RGB", TARGET_SIZE, (11, 26, 18))  # felt-green letterbox
    im.thumbnail(TARGET_SIZE, Image.LANCZOS)
    canvas.paste(im, ((TARGET_SIZE[0] - im.width) // 2, (TARGET_SIZE[1] - im.height) // 2))
    buf = io.BytesIO()
    canvas.save(buf, "PNG")
    return buf.getvalue()


def has_screenshot(api, rel_path):
    """rel_path -> a subscription/IAP's appStoreReviewScreenshot to-one relationship."""
    try:
        return bool(api.get(rel_path).get("data"))
    except Exception:
        return False


def upload(api, res_type, rel_name, parent_id, img, file_name):
    # 1. reserve
    res = api.post(f"/v1/{res_type}", {"data": {
        "type": res_type,
        "attributes": {"fileName": file_name, "fileSize": len(img)},
        "relationships": {rel_name: {"data": {
            "type": "inAppPurchases" if rel_name == "inAppPurchaseV2" else "subscriptions",
            "id": parent_id}}}}})
    sid = res["data"]["id"]
    # 2. upload the bytes to the pre-signed CDN operations (no auth header)
    for op in res["data"]["attributes"]["uploadOperations"]:
        chunk = img[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        r = api.http.request(op["method"], op["url"], data=chunk, headers=headers)
        if r.status_code >= 400:
            raise RuntimeError(f"CDN upload {r.status_code}: {r.text[:200]}")
    # 3. commit
    api._req("PATCH", f"/v1/{res_type}/{sid}", data=json.dumps({"data": {
        "type": res_type, "id": sid,
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(img).hexdigest()}}}))


def main():
    ap = argparse.ArgumentParser(description="Upload IAP review screenshots to ASC.")
    ap.add_argument("--image", required=True, help="Any image; letterboxed to 1242x2688.")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--dry-run", action="store_true", help="Print the plan; upload nothing (default).")
    g.add_argument("--commit", action="store_true", help="Actually upload.")
    ap.add_argument("--only", metavar="PRODUCT_ID", help="Just this one product.")
    ap.add_argument("--subscriptions", action="store_true", help="Also the 2 subscriptions.")
    ap.add_argument("--force", action="store_true", help="Replace an existing screenshot.")
    args = ap.parse_args()

    catalog = c.build_catalog()
    ncs = [x for x in catalog if x["kind"] == "NON_CONSUMABLE"]
    subs = [x for x in catalog if x["kind"] == "subscription"]
    if args.only:
        ncs = [x for x in ncs if x["product_id"] == args.only]
        subs = [x for x in subs if x["product_id"] == args.only]
        if not (ncs or subs):
            raise SystemExit(f"--only {args.only}: no such product")
    do_subs = args.subscriptions or (args.only and subs)

    img = prep_image(args.image)
    print(f"Image: {args.image} -> {TARGET_SIZE[0]}x{TARGET_SIZE[1]} PNG, {len(img)} bytes")
    print(f"Targets: {len(ncs)} non-consumables"
          + (f" + {len(subs)} subscriptions" if do_subs and subs else "") + "\n")

    creds = c.creds()
    if not args.commit:
        print("DRY RUN — re-run with --commit to upload. Products:")
        for x in ncs + (subs if do_subs else []):
            print(f"  {x['product_id']}")
        return
    if not creds:
        raise SystemExit("--commit needs ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY env vars.")

    api = c.ASC(*creds)
    app_id = c.find_app_id(api)
    iap_ids = c.existing_iap_ids(api, app_id)
    fn = "review.png"

    for x in ncs:
        pid = x["product_id"]
        iid = iap_ids.get(pid)
        if not iid:
            print(f"  skip (missing) {pid}")
            continue
        if not args.force and has_screenshot(api, f"/v2/inAppPurchases/{iid}/appStoreReviewScreenshot"):
            print(f"  skip (has one) {pid}")
            continue
        print(f"  uploading      {pid} ...", end=" ", flush=True)
        upload(api, "inAppPurchaseAppStoreReviewScreenshots", "inAppPurchaseV2", iid, img, fn)
        print("done")

    if do_subs and subs:
        group_id = None
        for grp in api.paged(f"/v1/apps/{app_id}/subscriptionGroups?limit=200"):
            if grp["attributes"]["referenceName"] == c.SUB_GROUP_REF:
                group_id = grp["id"]
        sub_ids = c.existing_sub_ids(api, group_id)
        for x in subs:
            pid = x["product_id"]
            sid = sub_ids.get(pid)
            if not sid:
                print(f"  skip (missing) {pid}")
                continue
            if not args.force and has_screenshot(api, f"/v1/subscriptions/{sid}/appStoreReviewScreenshot"):
                print(f"  skip (has one) {pid}")
                continue
            print(f"  uploading sub  {pid} ...", end=" ", flush=True)
            upload(api, "subscriptionAppStoreReviewScreenshots", "subscription", sid, img, fn)
            print("done")

    print("\nDone. Screenshots process async — 'Missing Metadata' clears once Apple finishes.")


if __name__ == "__main__":
    main()
