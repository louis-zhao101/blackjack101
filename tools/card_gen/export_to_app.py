#!/usr/bin/env python3
"""Downscale composited card PNGs into optimized JPEGs in the Flutter app assets.

    python3 export_to_app.py --deck greek
"""

import argparse
import glob
import os
from PIL import Image

HERE = os.path.dirname(__file__)
OUT_ROOT = os.path.join(HERE, "output")
APP_ROOT = os.path.join(HERE, "..", "..", "app_flutter", "assets", "card_faces")


def export(deck, width=512, quality=86):
    src = os.path.join(OUT_ROOT, deck)
    dst = os.path.join(APP_ROOT, deck)
    os.makedirs(dst, exist_ok=True)
    n = 0
    for f in glob.glob(os.path.join(src, "*", "*.png")):
        im = Image.open(f).convert("RGB")
        h = round(width * im.height / im.width)
        im = im.resize((width, h), Image.LANCZOS)
        name = os.path.splitext(os.path.basename(f))[0] + ".jpg"
        im.save(os.path.join(dst, name), quality=quality, optimize=True, progressive=True)
        n += 1
    print(f"exported {n} cards -> {dst}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deck", required=True)
    ap.add_argument("--width", type=int, default=512)
    ap.add_argument("--quality", type=int, default=86)
    args = ap.parse_args()
    export(args.deck, args.width, args.quality)


if __name__ == "__main__":
    main()
