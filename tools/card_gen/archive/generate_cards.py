#!/usr/bin/env python3
"""Generate playing-card face art via OpenAI's image API (gpt-image-1).

Reads the API key from the OPENAI_API_KEY environment variable so the secret
never lives in this file. Uses only the Python standard library.

Examples:
    OPENAI_API_KEY=sk-... python3 generate_cards.py --suit hearts
    OPENAI_API_KEY=sk-... python3 generate_cards.py --suit hearts --ranks A,K,Q
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

# Shared look-and-feel anchor, reused verbatim on every card so a full suit
# reads as one coherent set.
STYLE = (
    "in the style of a 13th-century Gothic illuminated manuscript miniature: "
    "burnished gold-leaf background with fine diaper patterning, rich ultramarine "
    "blue and vermilion red, thin dark ink outlines, flat medieval perspective, "
    "playful big-eyed slightly comical facial expressions, tempera-and-gold-leaf "
    "texture with visible aged vellum. The subject is centered on a plain cream "
    "vellum panel with a thin decorative gold border. No modern elements, no text, "
    "no numerals, no printed playing-card pips, no borders cropping the figure."
)

# Face/Ace ranks get a single silly illuminated character. Number ranks (2-10)
# are deliberately NOT here — they use a clean pip layout (see PIP_COUNT) so the
# card stays legible with an uncluttered center.
RANK_SUBJECT = {
    "A": "a single haloed angel joyfully holding one large ornate emblem",
    "J": "a single cheeky young page in a floppy hat, holding the emblem",
    "Q": "a single crowned queen with a gentle silly smile, holding a lily and the emblem",
    "K": "a single pompous crowned bearded king holding a scepter and the emblem",
}

# Number cards: exactly N suit emblems, traditional pip arrangement, clean center.
PIP_COUNT = {"2": "two", "3": "three", "4": "four", "5": "five",
             "6": "six", "7": "seven", "8": "eight", "9": "nine", "10": "ten"}

RANK_ORDER = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

SUITS = {
    "hearts":   {"emblem": "red heart",           "color": "red"},
    "diamonds": {"emblem": "red diamond lozenge", "color": "red"},
    "clubs":    {"emblem": "black trefoil clover", "color": "black"},
    "spades":   {"emblem": "black spade leaf",     "color": "black"},
}


def build_prompt(suit_key, rank):
    suit = SUITS[suit_key]
    if rank in PIP_COUNT:
        count = PIP_COUNT[rank]
        return (
            f"A clean illuminated-manuscript playing-card face showing exactly "
            f"{count} identical {suit['color']} {suit['emblem']} symbols, evenly "
            f"arranged upright in the traditional playing-card pip layout on a plain "
            f"cream vellum center with generous empty space between them. Surround the "
            f"panel with a thin decorative gold-leaf border with tiny vine flourishes. "
            f"Absolutely no human figures, no animals, no characters, no scene — only "
            f"the {count} suit symbols and the border. "
            f"Style: {STYLE}"
        )
    subject = RANK_SUBJECT[rank].replace("emblem", suit["emblem"])
    return (
        f"A single illuminated manuscript playing-card face illustration. "
        f"Depict {subject}. Decorate the panel border with a few small "
        f"{suit['color']} {suit['emblem']} motifs. {STYLE}"
    )


def generate(prompt, api_key, model, size, quality, retries=3):
    body = json.dumps({
        "model": model,
        "prompt": prompt,
        "size": size,
        "quality": quality,
        "n": 1,
    }).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            with urllib.request.urlopen(req, timeout=180) as resp:
                payload = json.load(resp)
            return base64.b64decode(payload["data"][0]["b64_json"])
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", "replace")
            last_err = f"HTTP {e.code}: {detail}"
            if e.code in (429, 500, 502, 503) and attempt < retries:
                wait = 5 * attempt
                print(f"    retry {attempt}/{retries} after {wait}s ({e.code})", flush=True)
                time.sleep(wait)
                continue
            break
        except Exception as e:  # noqa: BLE001
            last_err = str(e)
            if attempt < retries:
                time.sleep(5 * attempt)
                continue
            break
    raise RuntimeError(last_err)


def main():
    ap = argparse.ArgumentParser(description="Generate card face art via OpenAI images API")
    ap.add_argument("--suit", choices=SUITS.keys(), default="hearts")
    ap.add_argument("--ranks", default="all",
                    help="Comma list like A,K,Q or 'all' (default)")
    ap.add_argument("--model", default="gpt-image-1")
    ap.add_argument("--size", default="1024x1536",
                    help="1024x1536 (portrait), 1024x1024, or 1536x1024")
    ap.add_argument("--quality", default="medium",
                    choices=["low", "medium", "high", "auto"])
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "output"))
    args = ap.parse_args()

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        sys.exit("ERROR: set OPENAI_API_KEY in the environment first.")

    ranks = RANK_ORDER if args.ranks == "all" else [r.strip().upper() for r in args.ranks.split(",")]
    bad = [r for r in ranks if r not in RANK_ORDER]
    if bad:
        sys.exit(f"ERROR: unknown ranks {bad}. Valid: {RANK_ORDER}")

    out_dir = os.path.join(args.out, args.suit)
    os.makedirs(out_dir, exist_ok=True)

    print(f"Generating {len(ranks)} card(s) for {args.suit} "
          f"[{args.model} {args.size} q={args.quality}] -> {out_dir}\n")

    manifest = []
    for i, rank in enumerate(ranks, 1):
        prompt = build_prompt(args.suit, rank)
        fname = f"{args.suit}_{rank}.png"
        fpath = os.path.join(out_dir, fname)
        print(f"[{i}/{len(ranks)}] {rank:>2}  -> {fname}", flush=True)
        try:
            img = generate(prompt, api_key, args.model, args.size, args.quality)
        except Exception as e:  # noqa: BLE001
            print(f"    FAILED: {e}", flush=True)
            manifest.append({"rank": rank, "file": fname, "ok": False, "error": str(e)})
            continue
        with open(fpath, "wb") as f:
            f.write(img)
        manifest.append({"rank": rank, "file": fname, "ok": True, "prompt": prompt})

    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)

    ok = sum(1 for m in manifest if m.get("ok"))
    print(f"\nDone: {ok}/{len(ranks)} saved to {out_dir}")
    print("Review the images, then we can tweak the prompt or generate the other suits.")


if __name__ == "__main__":
    main()
