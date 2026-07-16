#!/usr/bin/env python3
"""Generate an app icon for Blackjack 101 with OpenAI's gpt-image-1.

App icons must be square and fully opaque (iOS rejects transparency and adds its
own rounded-corner mask), so this requests 1024x1024 with an opaque background.
Generates one or more candidates into tools/icon_out/. Stdlib only.

    OPENAI_API_KEY=sk-... python3 gen_icon.py                 # default concept, 3 tries
    OPENAI_API_KEY=sk-... python3 gen_icon.py --n 1
    OPENAI_API_KEY=sk-... python3 gen_icon.py --prompt "your own idea"
    OPENAI_API_KEY=sk-... python3 gen_icon.py --quality high

Pick the winner in icon_out/, then run it through your usual iOS/Android icon
sizing (e.g. flutter_launcher_icons) — this script only makes the 1024 master.
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

API_URL = "https://api.openai.com/v1/images/generations"
OUT_DIR = os.path.join(os.path.dirname(__file__), "icon_out")

# A concept tuned to the app: a premium blackjack trainer. Iconic, legible at
# small sizes, matching the in-app green-felt + gold palette. No text — iOS
# guidelines discourage words in the icon, and a symbol reads better tiny.
DEFAULT_PROMPT = (
    "A clean, modern mobile app icon for a premium blackjack card game, designed to be "
    "instantly recognizable at small sizes. A single crisp Ace of Spades playing card "
    "shown head-on and gently tilted at a slight angle, with one large bold black spade "
    "in the center rendered with a refined thin gold outline, sitting on a smooth rich "
    "casino-green background with a soft even radial vignette. Minimal, confident, flat "
    "modern design with just gentle depth and a soft highlight on the card — like a "
    "refined Apple-style app icon. Centered with generous margins so nothing is clipped "
    "by rounded corners. The ONLY gold in the image is the thin outline on the central "
    "spade. Absolutely NO corner ornament, NO filigree, NO scrollwork, NO decorative "
    "flourishes, NO gold corners, NO patterns, NO border frame, NO text, NO letters, NO "
    "words, NO numbers, NO card index, NO drop shadow outside the artwork. Uncluttered "
    "and premium, filling the entire square image edge to edge, high contrast and crisp."
)


def request_image(prompt, api_key, size, quality, retries=3):
    payload = {
        "model": "gpt-image-1",
        "prompt": prompt,
        "size": size,
        "quality": quality,
        "n": 1,
        "output_format": "png",
        "background": "opaque",
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        API_URL, data=body, method="POST",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
    )
    last = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=240) as resp:
                data = json.load(resp)
            return base64.b64decode(data["data"][0]["b64_json"])
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}: {e.read().decode('utf-8', 'replace')}"
            if e.code in (429, 500, 502, 503) and attempt < retries:
                time.sleep(5 * attempt); continue
            break
        except Exception as e:  # noqa: BLE001
            last = str(e)
            if attempt < retries:
                time.sleep(5 * attempt); continue
            break
    raise RuntimeError(last)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prompt", default=DEFAULT_PROMPT, help="icon description")
    ap.add_argument("--n", type=int, default=3, help="how many candidates to generate")
    ap.add_argument("--size", default="1024x1024",
                    choices=["1024x1024", "1024x1536", "1536x1024"])
    ap.add_argument("--quality", default="high", choices=["low", "medium", "high", "auto"])
    args = ap.parse_args()

    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        sys.exit("ERROR: set OPENAI_API_KEY first.")

    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Generating {args.n} icon candidate(s) at {args.size} (q={args.quality}) "
          f"-> {OUT_DIR}")

    failures = 0
    for i in range(1, args.n + 1):
        name = f"icon_{i}.png"
        print(f"  -> {name}", flush=True)
        try:
            img = request_image(args.prompt, key, args.size, args.quality)
            with open(os.path.join(OUT_DIR, name), "wb") as f:
                f.write(img)
        except Exception as e:  # noqa: BLE001
            failures += 1
            print(f"  !! FAILED {name}: {e}", flush=True)

    if failures:
        sys.exit(f"{failures}/{args.n} failed.")
    print("Done. Review the candidates and pick your favorite.")


if __name__ == "__main__":
    main()
