#!/usr/bin/env python3
"""Assemble a table-readable illuminated suit from the components.

Face design (matches the app's minimalist cards):
  - clean parchment field (texture reused from the frame's vellum)
  - a gold border that BREAKS with a gap at the two diagonal index corners
  - large sans-serif corner indices (rank + suit glyph)
  - number cards show ONE large central suit emblem (rank read from the corner),
    exactly like the app — so there is no pip-count problem at all
  - Ace uses the ornate emblem; J/Q/K use the illuminated court figures

    python3 composite.py --suit hearts
"""

import argparse
import os
import random
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(__file__)
COMP_ROOT = os.path.join(HERE, "components")
OUT_ROOT = os.path.join(HERE, "output")
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

CARD_W = 1024
CARD_H = int(round(CARD_W * 100 / 72))   # match app aspect ratio (72:100)
SUIT_GLYPH = {"hearts": "♥", "diamonds": "♦", "spades": "♠", "clubs": "♣"}
CREAM = (233, 219, 186)   # washi-paper outline for indices over full-bleed prints

# Per-deck palette: the two-line border color and the red/black suit ink used for
# the corner indices. The pip/court art itself carries the deck's own colors.
DECK_STYLES = {
    "illuminated": {"border": ((170, 132, 50), (116, 86, 26)), "red": (168, 26, 30), "black": (32, 30, 34), "ace_fit": (0.44, 0.44)},
    "ukiyo-e":     {"border": ((40, 58, 104), (24, 36, 70)),   "red": (188, 58, 45), "black": (34, 44, 72), "ace_fit": (0.44, 0.44)},
    "van-gogh":    {"border": None,                             "red": (196, 46, 38), "black": (30, 40, 86), "ace_print": True},
    # Greek: no drawn border, and the background ground differs per suit — red
    # suits sit on black glaze (red-figure), black suits on terracotta clay.
    "greek": {
        "border": None,
        "border_per_suit": True,  # a keyline in the suit's figure color
        "red": (214, 110, 58),   # terracotta index, legible on black glaze
        "black": (26, 22, 20),   # near-black index, legible on terracotta
        "ground": {"hearts": "blackglaze", "diamonds": "blackglaze",
                   "spades": "terracotta", "clubs": "terracotta"},
        "court_fit": (0.64, 0.58),   # (×W, ×H) — a touch smaller than default
        "ace_fit": (0.42, 0.40),     # themed object centerpiece
    },
    "audubon": {
        "border": None,          # number cards: no card-edge border (just the bird)
        "red": (168, 44, 40),
        "black": (44, 40, 34),
        "ace_print": True,       # the ace is a full-bleed plate too
        "print_yshift": 55,      # nudge the full-plate art down a touch
        "number_fit": (0.56, 0.54),  # the isolated bird replacing the center pip
        "gold_outline": True,    # trace the isolated number birds in gold
        "gold_outline_width": 23,  # thick rim
        "face_trim": ((198, 164, 92), (150, 118, 58)),  # gold edge-trim on the face plates
        "pop_out": True,         # knock out the plate's white bg so the bird sits above the frame
    },
    "tarot": {
        "border": ((44, 36, 60), (24, 18, 36)),  # dark ink keyline on the cream cards
        "print_border": False,   # full-bleed Major-Arcana faces bleed to the edge, no frame
        "red": (176, 40, 44),   # deep red index
        "black": (34, 30, 40),  # dark ink index
        "ace_fit": (0.44, 0.46),  # single tarot emblem centered on the cream ground
    },
    "gyotaku": {
        "border": ((70, 64, 58), (40, 36, 32)),  # soft sumi-ink keyline on washi
        "red": (176, 52, 42),   # vermilion (seal-ink) index for red suits
        "black": (44, 40, 36),  # sumi near-black index
        "court_fit": (0.76, 0.66),  # fish run large across the card
        "court_fit_overrides": {    # bulkier fish shrunk so they don't overfill
            "spades_J": (0.64, 0.56),
            "diamonds_J": (0.62, 0.58),
            "hearts_Q": (0.66, 0.60),
            "clubs_J": (0.66, 0.575),
        },
        "ace_fit": (0.50, 0.44),
    },
    "egyptian": {
        "border": ((36, 52, 104), (20, 32, 64)),  # Egyptian-blue keyline on cream papyrus
        "red": (170, 52, 42),   # brick-red index for red suits
        "black": (30, 38, 72),  # deep ink-navy index for black suits
        "ace_fit": (0.42, 0.42),
    },
    "roman": {
        "border": ((150, 112, 78), (108, 80, 52)),  # muted bronze/terracotta
        "red": (158, 52, 40),   # terracotta-red index
        "black": (40, 37, 42),  # slate index
        "index_stroke": (240, 233, 214),  # faint outline so indices read on the ground
        "mosaic_bg": True,      # subtle procedural fine-tessera ground for every card
        "ace_fit": (0.44, 0.44),
    },
}

# Bound per run by build().
COMP = ""
GOLD = (170, 132, 50)
GOLD_DK = (116, 86, 26)
SUIT_COLOR = {}
GROUND = {}   # suit -> ground name, for decks with per-suit backgrounds

PIP_RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10"]
COURT_RANKS = ["J", "Q", "K"]
ALL_RANKS = ["A"] + PIP_RANKS + COURT_RANKS


def autocrop(img, thresh=32):
    # Threshold the alpha first so faint stray specks near the edges don't inflate
    # the bounding box — otherwise the figure scales/centres off its real bounds.
    mask = img.getchannel("A").point(lambda v: 255 if v > thresh else 0)
    bbox = mask.getbbox()
    return img.crop(bbox) if bbox else img


def clean_halo(img, sat_thresh=42, alpha_thresh=205):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or a >= alpha_thresh:
                continue
            if (max(r, g, b) - min(r, g, b)) < sat_thresh:
                px[x, y] = (r, g, b, 0)
    return img


def fit(img, box_w, box_h):
    img = autocrop(img)
    s = min(box_w / img.width, box_h / img.height)
    return img.resize((max(1, int(img.width * s)), max(1, int(img.height * s))), Image.LANCZOS)


def paste_center(base, sprite, cx, cy):
    base.alpha_composite(sprite, (int(cx - sprite.width / 2), int(cy - sprite.height / 2)))


def roman_mosaic_bg(seed):
    """A fine Roman tessera field drawn procedurally (the AI frame comes out too
    coarse). A grid of small jittered warm-stone tiles separated by grout."""
    rnd = random.Random(seed)
    grout = (208, 194, 168)   # close to the tiles → faint, subtle lines
    palette = [(228, 216, 190), (232, 221, 197), (224, 212, 185), (234, 223, 199),
               (226, 214, 188), (230, 218, 193)]
    tile = max(16, CARD_W // 36)
    img = Image.new("RGB", (CARD_W, CARD_H), grout)
    d = ImageDraw.Draw(img)
    for y in range(0, CARD_H, tile):
        for x in range(0, CARD_W, tile):
            r, g, b = rnd.choice(palette)
            j = rnd.randint(-5, 5)
            c = (max(0, min(255, r + j)), max(0, min(255, g + j)), max(0, min(255, b + j)))
            d.rectangle([x + 1, y + 1, x + tile - 2, y + tile - 2], fill=c)
    return img.convert("RGBA")


def gold_outline(fig, width=7, color=(212, 176, 92)):
    """Trace a gold rim around an isolated (transparent) subject's silhouette by
    dilating its alpha edge and filling the ring with gold, behind the subject."""
    alpha = fig.split()[3]
    k = width if width % 2 else width + 1   # MaxFilter needs an odd kernel
    ring = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(k)), alpha)
    ring = ring.filter(ImageFilter.GaussianBlur(1))
    layer = Image.new("RGBA", fig.size, color + (255,))
    layer.putalpha(ring)
    return Image.alpha_composite(layer, fig)   # gold rim behind, subject on top


def remove_white_bg(path, thresh=55):
    """Knock out the near-white background of a plate by flooding inward from the
    edges, leaving the bird + botanical as a transparent cutout. Interior whites
    (blossoms, pale feathers) survive — they aren't connected to the edge."""
    im = Image.open(path).convert("RGB").copy()
    w, h = im.size
    SENT = (255, 0, 254)
    seeds = [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3),
             (w // 2, 2), (w // 2, h - 3), (2, h // 2), (w - 3, h // 2)]
    for xy in seeds:
        ImageDraw.floodfill(im, xy, SENT, thresh=thresh)
    out = Image.open(path).convert("RGBA")
    op, ip = out.load(), im.load()
    for y in range(h):
        for x in range(w):
            if ip[x, y] == SENT:
                r, g, b, _ = op[x, y]
                op[x, y] = (r, g, b, 0)
    return out


def draw_edge_trim(card, colors):
    """A single bold continuous gold trim hugging the whole outer edge (no gaps)."""
    gold = colors[0]
    m = int(CARD_W * 0.038)
    r = int(CARD_W * 0.05)
    w = int(CARD_W * 0.020)
    ImageDraw.Draw(card).rounded_rectangle(
        [m, m, CARD_W - 1 - m, CARD_H - 1 - m], radius=r, outline=gold, width=w)


def parchment_plain(suit):
    """The card's background texture, cropped from the (per-suit) frame center."""
    ground = GROUND.get(suit)
    name = f"frame_{ground}.png" if ground else "frame.png"
    frame = Image.open(os.path.join(COMP, name)).convert("RGB")
    W, H = frame.size
    patch = frame.crop((int(W * 0.36), int(H * 0.36), int(W * 0.64), int(H * 0.64)))
    return patch.resize((CARD_W, CARD_H), Image.LANCZOS).convert("RGBA")


# Border geometry
BM = int(CARD_W * 0.05)          # inset from card edge
BW = int(CARD_W * 0.020)         # border stroke width
BR = int(CARD_W * 0.06)          # corner radius (matches app card-back 0.06*W)

# Index geometry — app uses left 5/72, top 4/72 of width. Rank 0.19W; the suit
# glyph is drawn larger (0.185W) than the app's 0.15W because Arial's suit glyphs
# render small — this matches the Classic deck's readable corner suit.
IDX_X = int(CARD_W * 0.069)
IDX_Y = int(CARD_W * 0.056)
IDX_TW = int(CARD_W * 0.25)      # wide enough for a full-size "10"
IDX_TH = int(CARD_W * 0.42)


def draw_border_with_gaps(card, bg):
    d = ImageDraw.Draw(card)
    d.rounded_rectangle([BM, BM, CARD_W - BM, CARD_H - BM], radius=BR,
                        outline=GOLD, width=BW)
    m2 = int(BM + BW * 1.6)
    d.rounded_rectangle([m2, m2, CARD_W - m2, CARD_H - m2], radius=int(BR * 0.7),
                        outline=GOLD_DK, width=max(1, int(CARD_W * 0.0035)))

    # Fully clear the border in each index corner: extend the cut to the card
    # edges (off-canvas) so no border line survives around the index, and round
    # only the inner corner (facing the card centre) so the opening looks clean.
    pad = int(CARD_W * 0.022)
    r = int(IDX_TW * 0.24)
    off = CARD_W  # push outer corners off-canvas so only the inner one rounds
    gx = IDX_X + IDX_TW + pad
    gy = IDX_Y + IDX_TH + pad
    boxes = [
        [-off, -off, gx, gy],                                   # top-left
        [CARD_W - gx, CARD_H - gy, CARD_W + off, CARD_H + off],  # bottom-right
    ]
    for box in boxes:
        mask = Image.new("L", card.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(box, radius=r, fill=255)
        card.paste(bg, (0, 0), mask)


def cover_fit(img, yshift=0):
    """Scale [img] to fill the whole card, cropping the overflow (BoxFit.cover).
    [yshift] > 0 biases the crop so the art sits lower on the card (in card px)."""
    img = img.convert("RGBA")
    scale = max(CARD_W / img.width, CARD_H / img.height)
    img = img.resize((round(img.width * scale), round(img.height * scale)), Image.LANCZOS)
    left = (img.width - CARD_W) // 2
    top = (img.height - CARD_H) // 2
    if yshift:
        top = max(0, min(img.height - CARD_H, top - yshift))
    return img.crop((left, top, left + CARD_W, top + CARD_H))


def draw_indices(card, suit, rank, stroke=None):
    color = SUIT_COLOR[suit]
    rank_fs = int(CARD_W * 0.19)          # same size for every rank, incl. "10"
    glyph_fs = int(CARD_W * 0.185)        # bigger corner suit for readability
    font = ImageFont.truetype(FONT_PATH, rank_fs)
    gfont = ImageFont.truetype(FONT_PATH, glyph_fs)
    glyph = SUIT_GLYPH[suit]
    label = "10" if rank == "10" else rank
    # Over a busy print, a light outline keeps the index legible. Pad the tile by
    # the stroke width so the outline isn't clipped at the corner.
    sw = int(rank_fs * 0.08) if stroke else 0
    pad = sw

    tile = Image.new("RGBA", (IDX_TW + 2 * pad, IDX_TH + 2 * pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.text((pad, pad), label, font=font, fill=color, anchor="lt",
           stroke_width=sw, stroke_fill=stroke)   # left-aligned to corner
    rank_w = d.textlength(label, font=font)
    d.text((pad + rank_w / 2, pad + int(rank_fs * 1.02)), glyph, font=gfont, fill=color,
           anchor="mt", stroke_width=sw, stroke_fill=stroke)

    # Padding keeps the visible index at the same corner position as the unpadded
    # case (P0/Pr reduce to the originals when pad == 0).
    card.alpha_composite(tile, (IDX_X - pad, IDX_Y - pad))
    card.alpha_composite(
        tile.rotate(180),
        (CARD_W - IDX_X - IDX_TW - pad, CARD_H - IDX_Y - IDX_TH - pad))


def build(deck, suit, do_clean):
    global COMP, GOLD, GOLD_DK, SUIT_COLOR, GROUND
    style = DECK_STYLES[deck]
    GROUND = style.get("ground") or {}
    COMP = os.path.join(COMP_ROOT, deck)
    SUIT_COLOR = {
        "hearts": style["red"], "diamonds": style["red"],
        "spades": style["black"], "clubs": style["black"],
    }
    border = style["border"]   # None → no drawn card border (art bleeds to the edge)
    if style.get("border_per_suit"):
        # Frame in the suit's own figure color (orange on black / black on terracotta).
        GOLD = SUIT_COLOR[suit]
        GOLD_DK = tuple(int(v * 0.55) for v in GOLD)
        border = True
    elif border:
        GOLD, GOLD_DK = border

    # A per-number-subject deck (e.g. Audubon) has no shared suit pip.
    pip_path = os.path.join(COMP, f"pip_{suit}.png")
    pip = autocrop(Image.open(pip_path).convert("RGBA")) if os.path.exists(pip_path) else None
    ace = autocrop(Image.open(os.path.join(COMP, f"ace_{suit}.png")).convert("RGBA"))
    out_dir = os.path.join(OUT_ROOT, deck, suit)
    os.makedirs(out_dir, exist_ok=True)

    center = (CARD_W / 2, CARD_H / 2)
    big_pip = fit(pip, CARD_W * 0.31, CARD_W * 0.30) if pip else None
    court_fit = style.get("court_fit", (0.58, 0.62))
    ace_fit = style.get("ace_fit", (0.36, 0.34))

    for rank in ALL_RANKS:
        # A full-bleed image face: a famous-print court, or (for some decks) an Ace
        # painted as a full-bleed object rather than a cut-out.
        print_path = None
        if rank in COURT_RANKS:
            p = os.path.join(COMP, f"print_{suit}_{rank}.png")
            if os.path.exists(p):
                print_path = p
        elif rank == "A" and style.get("ace_print"):
            print_path = os.path.join(COMP, f"ace_{suit}.png")

        if print_path:
            idx_stroke = CREAM
            if style.get("pop_out"):
                # White plate ground + gold frame, then the bird cutout ON TOP so the
                # subject sits above the frame (its white background knocked out).
                card = parchment_plain(suit)
                idx_stroke = card.getpixel((20, 20))[:3]   # match the plate ground
                if style.get("face_trim"):
                    draw_edge_trim(card, style["face_trim"])
                cut = autocrop(remove_white_bg(print_path))
                pf = style.get("pop_fit", (0.84, 0.9))
                fitted = fit(cut, CARD_W * pf[0], CARD_H * pf[1])
                paste_center(card, fitted, CARD_W / 2,
                             CARD_H / 2 + style.get("print_yshift", 0))
            else:
                bg = cover_fit(Image.open(print_path), yshift=style.get("print_yshift", 0))
                card = bg.copy()
                if border and style.get("print_border", True):
                    draw_border_with_gaps(card, bg)
            draw_indices(card, suit, rank, stroke=idx_stroke)
            card.convert("RGB").save(os.path.join(out_dir, f"{suit}_{rank}.png"))
            print(f"  {suit} {rank} (print)")
            continue

        if style.get("mosaic_bg"):
            bg = roman_mosaic_bg(sum(ord(ch) for ch in suit + rank))
        else:
            bg = parchment_plain(suit)
        card = bg.copy()
        if border:
            draw_border_with_gaps(card, bg)

        if rank == "A":
            paste_center(card, fit(ace, CARD_W * ace_fit[0], CARD_W * ace_fit[1]), *center)
        elif rank in PIP_RANKS:
            # A deck may give each number card its own isolated subject (e.g. a bird)
            # instead of a repeated center pip.
            num_path = os.path.join(COMP, f"number_{suit}_{rank}.png")
            if os.path.exists(num_path):
                fig = Image.open(num_path).convert("RGBA")
                if do_clean:
                    fig = clean_halo(fig)
                if style.get("gold_outline"):
                    fig = gold_outline(fig, width=style.get("gold_outline_width", 7))
                nf = style.get("number_fit", (0.5, 0.5))
                paste_center(card, fit(fig, CARD_W * nf[0], CARD_H * nf[1]), *center)
            else:
                paste_center(card, big_pip, *center)
        else:
            court_path = os.path.join(COMP, f"court_{suit}_{rank}.png")
            if not os.path.exists(court_path):
                continue  # skip un-generated courts (partial-suit mockups)
            fig = Image.open(court_path).convert("RGBA")
            if do_clean:
                fig = clean_halo(fig)
            cf = style.get("court_fit_overrides", {}).get(f"{suit}_{rank}", court_fit)
            paste_center(card, fit(fig, CARD_W * cf[0], CARD_H * cf[1]), *center)

        draw_indices(card, suit, rank, stroke=style.get("index_stroke"))
        card.convert("RGB").save(os.path.join(out_dir, f"{suit}_{rank}.png"))
        print(f"  {suit} {rank}")
    print(f"Wrote 13 cards to {out_dir}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deck", default="ukiyo-e", choices=DECK_STYLES.keys())
    ap.add_argument("--suit", default="hearts")
    ap.add_argument("--no-clean", action="store_true")
    args = ap.parse_args()
    build(args.deck, args.suit, do_clean=not args.no_clean)


if __name__ == "__main__":
    main()
