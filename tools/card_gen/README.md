# card_gen — themed card-face deck generator

Generates the premium card-face decks for the Blackjack 101 Flutter app.

## Pipeline (3 steps)

1. **`gen_components.py`** — calls OpenAI's image API to make a deck's reusable
   *components*: background frame(s), a pip emblem, an ace, and the face cards
   (either illustrated **courts** or full-bleed **prints**). → `components/<deck>/`
2. **`composite.py`** — deterministically assembles the 52 card PNGs from those
   components (background, border, pips, corner indices). **No API calls.**
   → `output/<deck>/<suit>/`
3. **`export_to_app.py`** — downscales the PNGs to optimized JPEGs into
   `app_flutter/assets/card_faces/<deck>/`.

## Usage

```bash
export OPENAI_API_KEY=sk-...
# 1. generate components — run once per suit (frames/prints are shared where noted)
python3 gen_components.py --deck greek --suit hearts --what all
#    --what: all | frame | pip | ace | courts | prints
#    --ranks J,Q,K   (limit which court/print ranks to (re)generate)
# 2. assemble the cards (no API)
python3 composite.py --deck greek --suit hearts
# 3. ship optimized JPEGs to the app
python3 export_to_app.py --deck greek
```

## Adding a deck

1. Add an entry to `DECKS` in `gen_components.py`: `style`, per-suit
   `suits` (emblem, color), a `frame` (or `frames` map for per-suit grounds),
   and either `courts` (illustrated figures) or `prints` (famous artworks).
   Optional: `ace_objects`, `ace_print`, `technique` (per-suit style).
2. Add a matching palette to `DECK_STYLES` in `composite.py`: `border`
   (or `None` / `border_per_suit`), `red`/`black` index colors, and optional
   `ground`, `court_fit`, `ace_fit`, `ace_print`.
3. Register in the app: preset in `appearance.dart`, product in
   `store_provider.dart`, asset dir in `pubspec.yaml`.

## Folders

- `components/<deck>/` — AI-generated source art (the expensive bit; keep these).
- `output/<deck>/<suit>/` — composited full-res card PNGs (regenerable via step 2).
- `output/sheets/` — contact/review sheets.
- `archive/` — the original whole-card generator and its early output (superseded).

## Decks

- **illuminated** — 13th-c. Gothic manuscript; illustrated courts; gold object aces.
- **ukiyo-e** — woodblock; famous Hokusai/Hiroshige prints as face cards.
- **greek** — vase painting; dual red-figure (♥♦) / black-figure (♠♣) technique.
- **van-gogh** — recipe kept here but **not shipped** (removed from the app).
