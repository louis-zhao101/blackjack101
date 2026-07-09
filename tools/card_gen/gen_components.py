#!/usr/bin/env python3
"""Generate the reusable art components for a composite card deck.

Per suit it produces: one shared background/frame, one pip emblem, one Ace
emblem, and J/Q/K court figures (all but the frame on transparent backgrounds).
Deck-aware: each deck in DECKS defines its own style, palette, and prompts.
Output is namespaced under components/<deck>/. Key from OPENAI_API_KEY. Stdlib only.

    OPENAI_API_KEY=sk-... python3 gen_components.py --deck ukiyo-e --suit hearts
    OPENAI_API_KEY=sk-... python3 gen_components.py --deck ukiyo-e --suit hearts --what courts
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
COMP_ROOT = os.path.join(os.path.dirname(__file__), "components")

# --------------------------------------------------------------------------- #
# Deck definitions. Each deck supplies a style anchor, a per-suit (emblem,color)
# map, a background/frame prompt, prompt builders for the pip/ace emblems, and a
# unique figure description for each of the 12 court cards.
# --------------------------------------------------------------------------- #

ILLUMINATED_STYLE = (
    "authentic 13th-century Gothic illuminated manuscript style: burnished "
    "gold-leaf, rich ultramarine blue and vermilion red, fine dark ink outlines, "
    "flat medieval perspective, tempera-and-gold-leaf texture, dignified serene "
    "faces (not cartoonish, not comical), historically faithful."
)

UKIYOE_STYLE = (
    "authentic Japanese ukiyo-e woodblock print style, in the manner of Katsushika "
    "Hokusai and Hiroshige: flat areas of unshaded color, bold dark sumi-ink "
    "outlines, a limited traditional palette of prussian/indigo blue, soft "
    "vermilion red, mustard ochre, sage green, beige and black, visible woodgrain "
    "and aged washi-paper texture, no gradients, no modern shading, no photorealism."
)

VANGOGH_STYLE = (
    "the Post-Impressionist oil-painting style of Vincent van Gogh: thick swirling "
    "impasto brushstrokes, vivid expressive color, bold energetic dark outlines, "
    "dynamic directional strokes and visible canvas texture, no photorealism."
)

GREEK_STYLE = (
    "authentic ancient Greek Attic vase-painting style: bold flat silhouettes, fine "
    "elegant linear detail, no shading, no modern perspective, a flat decorative "
    "ancient-pottery aesthetic."
)

ROMAN_STYLE = (
    "an ancient Roman floor mosaic made of small square stone-and-glass tesserae "
    "with visible grout lines, an earthy antique palette of terracotta, ochre, "
    "cream, deep red, olive, slate-blue and black, flat and decorative with a "
    "weathered antique look, no smooth shading, no photorealism."
)
GYOTAKU_STYLE = (
    "authentic Japanese gyotaku fish-print style: a direct hand-printed impression "
    "(rubbing) of a real fish in dark sumi ink, with SUBTLE muted natural watercolor "
    "coloring softly washed over the print — gentle olive, ochre, russet-red and pale "
    "blue tints on the body, belly, fins and spots — keeping fine visible scales, fins "
    "and gills and organic ink mottling and gaps from hand-printing. A delicate "
    "hand-pressed printed look, flat and graphic, muted and understated (not vivid or "
    "glossy), no 3D shading, no photorealism."
)
EGYPTIAN_STYLE = (
    "a bold minimal ancient Egyptian hieroglyph ICON style: the figure reduced to a "
    "few large simple flat shapes with clean crisp vector edges and a strong black "
    "silhouette, using only one or two small flat accent colors (e.g. gold or "
    "turquoise) and nothing more — NO shading, NO gradients, NO fine detail, NO small "
    "interior shapes, NO realism; extremely simplified and graphic like a single "
    "carved glyph or pictogram, in composite profile (head and legs in side view, "
    "torso and eye frontal), against a warm golden-ochre amber ground."
)
# Suit-color maps to the two real vase techniques (drawn on transparent bg).
GREEK_TECH = {
    "red-figure": (
        "Use the ancient RED-FIGURE technique: the subject is a solid reddish-orange "
        "terracotta shape with fine dark painted interior details, on a fully "
        "transparent background with NO background fill of any kind."
    ),
    "black-figure": (
        "Use the ancient BLACK-FIGURE technique: the subject is a solid glossy black "
        "silhouette with sparse fine incised interior lines, on a fully transparent "
        "background with NO background fill of any kind."
    ),
}

DECKS = {
    "illuminated": {
        "style": ILLUMINATED_STYLE,
        "suits": {
            "hearts": ("heart", "vermilion red"),
            "diamonds": ("diamond lozenge", "vermilion red"),
            "spades": ("spade", "near-black charcoal"),
            "clubs": ("trefoil club (clover)", "near-black charcoal"),
        },
        "frame": (
            "A blank playing-card face template in an " + ILLUMINATED_STYLE + " "
            "A SLIM decorative illuminated border of fine gold vine scrollwork with "
            "small ultramarine blue and vermilion red accents runs just inside the "
            "card edge, leaving a VERY LARGE clean cream vellum central area. Purely "
            "floral ornament: NO human faces, NO figures, NO animals. The central "
            "area is completely EMPTY cream vellum: no symbols, no text, no pips. "
            "Portrait orientation, thin dark outer keyline, even narrow margins."
        ),
        "emblem_fill": (
            "solid {color} with a fine burnished gold outline and subtle darker "
            "inner shading"
        ),
        "ace": (
            "One single large ornate heraldic {emblem}, medieval illuminated "
            "manuscript style, filled {color} with delicate gold-leaf foliate "
            "scrollwork and vine tracery inside it, outlined in burnished gold, "
            "symmetric and upright. PURELY floral vine ornament inside: NO faces, NO "
            "eyes, NO figures, NO animals."
        ),
        "ace_objects": {
            "spades": "a knight's upright longsword with a cross-guard hilt",
            "hearts": "an ornate golden ceremonial chalice (goblet)",
            "diamonds": "a jeweled royal crown",
            "clubs": "an ornate heraldic fleur-de-lis",
        },
        "back": (
            "A symmetric ornamental playing-card BACK in the style of a 13th-century "
            "Gothic illuminated manuscript: a deep ultramarine blue ground with an "
            "elegant slim gold-leaf vine-scroll border and a single large central gold "
            "quatrefoil medallion enclosing one stylized fleur-de-lis ornament, plus a "
            "few sparse gold and vermilion-red accents. Clean, balanced and uncluttered "
            "with generous negative space — NOT a dense repeating all-over pattern, and "
            "absolutely NO tiny repeated dots, flowers or holes. The design fills the "
            "FULL WIDTH edge to edge with NO outer cream or parchment margin; keep the "
            "border and medallion within the central area and leave only a plain "
            "deep-blue band of empty ground along the very TOP and very BOTTOM edges "
            "(this margin will be trimmed). Symmetric, portrait orientation. NO text, "
            "NO numbers, NO letters, NO pips, NO faces."
        ),
        "courts": {
            ("spades", "K"): "an old crowned king with a long white beard, seated and playing a golden harp, wearing a deep ultramarine-blue robe",
            ("hearts", "K"): "a stern crowned emperor with a forked brown beard, holding a great upright broadsword behind his head, wearing a crimson-and-gold robe",
            ("diamonds", "K"): "a crowned king shown in side profile, clean-shaven with a laurel wreath under his crown, holding a battle-axe, wearing a green-and-gold robe",
            ("clubs", "K"): "a young crowned king with curly golden hair and a short beard, holding a golden orb aloft, wearing a royal-purple robe",
            ("spades", "Q"): "a crowned warrior queen with a stern face, holding an upright spear and a small round shield, wearing steel-blue and silver robes",
            ("hearts", "Q"): "a gentle crowned queen with long flowing golden hair, holding a single red rose to her chest, wearing rose-and-gold robes",
            ("diamonds", "Q"): "a crowned queen with dark braided hair, holding a tall golden lily-scepter, wearing emerald-green and violet robes",
            ("clubs", "Q"): "a regal crowned queen in an elaborate headdress, holding a fan of peacock feathers, wearing deep-teal and gold robes",
            ("spades", "J"): "a young armored knight-page in chainmail and a plumed steel helm, holding a tall pike",
            ("hearts", "J"): "a curly-haired young page in a bright red tunic and a floppy cap, playing a small lute",
            ("diamonds", "J"): "a young page shown in side profile wearing a green cloak and cap, holding a banner on a wooden staff",
            ("clubs", "J"): "a young page in a feathered cap and blue doublet, holding a hunting falcon on his gloved fist",
        },
    },
    "ukiyo-e": {
        "style": UKIYOE_STYLE,
        "suits": {
            "hearts": ("heart", "soft vermilion red"),
            "diamonds": ("diamond lozenge", "soft vermilion red"),
            "spades": ("spade", "prussian indigo blue-black"),
            "clubs": ("trefoil club (clover)", "prussian indigo blue-black"),
        },
        "frame": (
            "A blank sheet of aged Japanese washi paper, warm beige and cream with "
            "subtle visible fibers and a faint woodgrain texture, in an " + UKIYOE_STYLE + " "
            "The sheet is completely EMPTY: no border, no frame, no symbols, no "
            "figures, no text, no ink — just the plain textured paper filling the "
            "whole image, flat and evenly lit. Portrait orientation."
        ),
        "emblem_fill": (
            "a bold flat {color} fill with a strong dark sumi-ink outline and a "
            "faint hint of woodgrain within the fill"
        ),
        "ace": (
            "One single large bold {emblem} playing-card suit symbol in Japanese "
            "ukiyo-e woodblock style, a flat {color} shape with a strong dark "
            "sumi-ink outline, filled inside with a traditional seigaiha concentric "
            "wave pattern in lighter tones. Symmetric and upright."
        ),
        "ace_objects": {
            "spades": "a samurai kabuto helmet",
            "hearts": "an open folding fan (sensu) decorated with a wave pattern",
            "diamonds": "a leaping koi carp",
            "clubs": "a standing crane (tsuru) bird",
        },
        "back": (
            "A symmetric ornamental playing-card BACK in Japanese ukiyo-e woodblock "
            "style: a full-bleed repeating seigaiha (concentric wave) pattern in "
            "prussian/indigo blue and cream with a central circular medallion holding "
            "a stylized cresting wave, bold dark outlines, aged washi-paper texture. "
            "Symmetric, filling the entire card, portrait orientation. NO text, NO "
            "numbers, NO letters, NO playing-card pips."
        ),
        "courts": {
            ("spades", "K"): "a stern daimyo warlord in full samurai armor and a horned kabuto helmet, holding a war fan",
            ("hearts", "K"): "an emperor in elaborate Heian court robes and a tall black eboshi cap, holding a wooden ritual scepter",
            ("diamonds", "K"): "a wealthy merchant lord in a finely patterned kimono holding a folding fan, shown in three-quarter view",
            ("clubs", "K"): "a mighty sumo yokozuna grand champion wearing a thick ceremonial rope belt, arms crossed",
            ("spades", "Q"): "an onna-bugeisha female samurai in armor, holding a naginata polearm",
            ("hearts", "Q"): "a beautiful court lady in a many-layered junihitoe kimono with long flowing black hair",
            ("diamonds", "Q"): "an elegant geisha holding an open folding fan, with elaborate hair ornaments",
            ("clubs", "Q"): "a serene empress in imperial robes and a golden headdress",
            ("spades", "J"): "a young samurai swordsman drawing his katana, hair in a topknot",
            ("hearts", "J"): "a dramatic kabuki actor in a bold striped costume striking a mie pose with exaggerated makeup",
            ("diamonds", "J"): "a traveling poet in a conical straw hat and simple robe holding a bamboo staff, in profile",
            ("clubs", "J"): "a young sumo wrestler in a colorful mawashi loincloth in a low stance",
        },
        # Each face card is a distinct famous ukiyo-e print, so every suit's court
        # looks different. Full-bleed scenes rendered behind the card border.
        "prints": {
            # Hearts (already generated as the shared trio).
            ("hearts", "K"): "a faithful re-creation of Katsushika Hokusai's 'The Great Wave off Kanagawa': one enormous cresting wave with clawing white foam, small boats beneath it, and Mount Fuji small in the distance, deep prussian-blue and white",
            ("hearts", "Q"): "a faithful re-creation of Katsushika Hokusai's 'Fine Wind, Clear Morning' (Red Fuji): Mount Fuji as a large red-brown cone against a clear blue sky with a few white clouds and a dark forested base",
            ("hearts", "J"): "a faithful re-creation of Utagawa Hiroshige's 'Sudden Shower over Shin-Ohashi Bridge and Atake': tiny figures under umbrellas hurrying across a wooden bridge in slanting grey rain over a river",
            # Spades — dark and dramatic.
            ("spades", "K"): "a faithful re-creation of Katsushika Hokusai's woodblock print 'Fine Wind, Clear Morning' reimagined at dusk: a solid dark indigo-and-charcoal Mount Fuji against a deep twilight sky with a scattering of thin white clouds, calm and graphic, flat woodblock color — absolutely NO lava, NO glowing molten rock, NO fire, NO orange or red glow on the mountain",
            ("spades", "Q"): "a faithful re-creation of Utagawa Hiroshige's 'Naruto Whirlpools of Awa': swirling deep-blue ocean whirlpools crashing against rocks with white foam",
            ("spades", "J"): "a faithful re-creation of Katsushika Hokusai's 'Kajikazawa in Kai Province': a lone fisherman standing on a rocky outcrop, holding a SINGLE taut fishing line that arcs down into the pale misty water below, with Mount Fuji faint in the distance",
            # Diamonds — warm and scenic.
            ("diamonds", "K"): "a faithful re-creation of Utagawa Hiroshige's 'Plum Park in Kameido': a bold red-blossomed plum tree branch in the foreground with a green garden and figures behind",
            ("diamonds", "Q"): "a faithful re-creation of Utagawa Hiroshige's 'Moon Pine, Ueno': the great circular looping branch of a pine framing a distant landscape and pale sky",
            ("diamonds", "J"): "a faithful re-creation of Utagawa Hiroshige's 'Fireworks at Ryogoku Bridge': golden fireworks bursting over a dark night river dotted with boats and lanterns",
            # Clubs — travellers and landscapes.
            ("clubs", "K"): "a faithful re-creation of Katsushika Hokusai's 'Ejiri in Suruga Province': travellers on a windy road clutching their hats as sheets of paper blow into a pale sky with Mount Fuji",
            ("clubs", "Q"): "a faithful re-creation of Utagawa Hiroshige's 'Evening Snow at Kanbara': a quiet snow-covered village at dusk with figures trudging through deep snow, muted blue-grey",
            ("clubs", "J"): "a faithful re-creation of Katsushika Hokusai's 'Mishima Pass in Kai Province': a single colossal cedar tree with travellers dwarfed at its base and Mount Fuji in the distance",
        },
    },
    "van-gogh": {
        "style": VANGOGH_STYLE,
        "suits": {
            "hearts": ("heart", "vivid crimson red"),
            "diamonds": ("diamond lozenge", "vivid crimson red"),
            "spades": ("spade", "deep midnight blue-black"),
            "clubs": ("trefoil club (clover)", "deep midnight blue-black"),
        },
        "frame": (
            "A blank painterly oil-on-canvas surface loosely in " + VANGOGH_STYLE + " "
            "VERY PALE, soft, MUTED cream and warm off-white with only faint gentle "
            "brushstroke texture — light, calm and uniform, NOT bright, NOT saturated "
            "yellow, NOT busy. The surface is completely EMPTY: no subject, no border, "
            "no symbols, no text — just the softly textured pale canvas filling the "
            "whole image. Portrait orientation."
        ),
        "emblem_fill": (
            "a bold {color} shape painted in thick impasto brushstrokes with visible "
            "directional strokes and a dark energetic outline"
        ),
        "ace": (
            "One single large {emblem} playing-card suit symbol painted in the "
            "swirling impasto style of Van Gogh: a bold {color} form filled inside "
            "with swirling brushstrokes in rich harmonious shades and highlights of "
            "its OWN color ({color}) with a few touches of warm gold, bold dark "
            "energetic outline, symmetric and upright"
        ),
        # Impasto resists transparency, so the Van Gogh Ace is a full-bleed painting
        # of the object (matching its edge-to-edge face cards) rather than a cut-out.
        "ace_print": True,
        "ace_objects": {
            "spades": "a pair of worn leather peasant boots",
            "hearts": "a single large sunflower",
            "diamonds": "a yellow straw hat",
            "clubs": "a simple rustic wooden chair",
        },
        "prints": {
            # Hearts — warm and romantic.
            ("hearts", "K"): "a faithful re-creation of Vincent van Gogh's painting 'The Starry Night': a swirling deep-blue night sky with a glowing golden crescent moon and haloed stars over a small village, with a tall dark cypress in the foreground",
            ("hearts", "Q"): "a faithful re-creation of Vincent van Gogh's painting 'Sunflowers': a vase of bright golden-yellow sunflowers against a warm yellow background",
            ("hearts", "J"): "a faithful re-creation of Vincent van Gogh's painting 'Almond Blossoms': branches of white almond blossom against a bright turquoise-blue sky",
            # Spades — dark and dramatic.
            ("spades", "K"): "a faithful re-creation of Vincent van Gogh's painting 'Wheatfield with Crows': a stormy dark-blue sky over a golden wheat field with a flock of black crows and a diverging path",
            ("spades", "Q"): "a faithful re-creation of Vincent van Gogh's 1889 'Self-Portrait': the artist with red hair and beard in a blue coat against a swirling pale turquoise background",
            ("spades", "J"): "a faithful re-creation of Vincent van Gogh's painting 'The Potato Eaters': peasants in earthy dark browns and greens gathered around a dim lamp-lit table",
            # Diamonds — bright and vivid.
            ("diamonds", "K"): "a faithful re-creation of Vincent van Gogh's painting 'Cafe Terrace at Night': a glowing yellow cafe terrace under a deep-blue star-filled sky on a cobbled street",
            ("diamonds", "Q"): "a faithful re-creation of Vincent van Gogh's painting 'Irises': a vivid cluster of blue-violet irises among green leaves",
            ("diamonds", "J"): "a faithful re-creation of Vincent van Gogh's painting 'Bedroom in Arles': a simple bedroom with a wooden bed, chairs and bright yellow and blue walls in tilted perspective",
            # Clubs — landscapes and portraits.
            ("clubs", "K"): "a faithful re-creation of Vincent van Gogh's painting 'Starry Night Over the Rhone': reflections of gas lamps and stars shimmering on a dark blue river at night",
            ("clubs", "Q"): "a faithful re-creation of Vincent van Gogh's painting 'Wheat Field with Cypresses': rolling golden wheat and green fields under a swirling white-and-blue sky with tall dark cypress trees",
            ("clubs", "J"): "a faithful re-creation of Vincent van Gogh's painting 'Portrait of Doctor Gachet': the pensive doctor resting his head on his hand against a blue background with foxglove flowers",
        },
    },
    "greek": {
        "style": GREEK_STYLE,
        # Red suits are painted in red-figure, black suits in black-figure.
        "technique": {
            "hearts": GREEK_TECH["red-figure"],
            "diamonds": GREEK_TECH["red-figure"],
            "spades": GREEK_TECH["black-figure"],
            "clubs": GREEK_TECH["black-figure"],
        },
        "suits": {
            "hearts": ("heart", "reddish-orange terracotta"),
            "diamonds": ("diamond lozenge", "reddish-orange terracotta"),
            "spades": ("spade", "glossy black"),
            "clubs": ("trefoil club (clover)", "glossy black"),
        },
        # Two ground surfaces: black glaze (behind red-figure) and terracotta clay
        # (behind black-figure). The composite picks per suit.
        "frames": {
            "blackglaze": (
                "A blank ancient Greek pottery surface of solid deep glossy BLACK "
                "glaze with a subtle sheen and very faint clay texture. Completely "
                "EMPTY: no figures, no symbols, no border, no text — just the plain "
                "black glazed surface filling the whole image. Portrait orientation."
            ),
            "terracotta": (
                "A blank ancient Greek pottery surface of plain matte TERRACOTTA-"
                "ORANGE fired clay with a subtle fine texture. Completely EMPTY: no "
                "figures, no symbols, no border, no text — just the plain orange clay "
                "surface filling the whole image. Portrait orientation."
            ),
        },
        "emblem_fill": "a bold flat {color} vase-painting silhouette",
        # Aces show a distinct iconic Greek object per suit (not the suit symbol) —
        # the corner index still identifies the suit.
        "ace_objects": {
            "spades": "a Corinthian bronze war helmet in side profile",
            "hearts": "a lyre (kithara), a seven-stringed ancient Greek musical instrument",
            "diamonds": "an amphora, a tall two-handled ancient Greek storage vase",
            "clubs": "an owl (the owl of Athena) standing and facing forward",
        },
        "back": (
            "A playing-card BACK in ancient Greek vase style: a SINGLE CENTERED round "
            "medallion — a palmette/anthemion rosette framed by a thin circular "
            "Greek-key (meander) ring — in terracotta-orange on a plain glossy black "
            "ground. Flat and decorative, no shading. The medallion sits in the middle "
            "with a GENEROUS plain black margin all around it and empty black ground "
            "extending to every edge. Portrait orientation. NO rectangular border frame "
            "at the card edges, NO text, NO numbers, NO letters, NO pips, NO people."
        ),
        "courts": {
            ("spades", "K"): "the god Zeus enthroned, holding a thunderbolt, with an eagle beside him",
            ("hearts", "K"): "a single powerful charging bull with lowered horns",
            ("diamonds", "K"): "a four-horse chariot (quadriga) at full gallop driven by a charioteer",
            ("clubs", "K"): "the god Poseidon striding forward brandishing a trident, with a dolphin",
            ("spades", "Q"): "the goddess Athena in a crested helmet holding a spear and shield, with an owl",
            ("hearts", "Q"): "a dancing maenad with flowing robes holding a thyrsus staff",
            ("diamonds", "Q"): "the goddess Artemis the huntress drawing a bow beside a stag",
            ("clubs", "Q"): "a fearsome Gorgon (Medusa) face with writhing snakes for hair and small wings",
            ("spades", "J"): "two hoplite warriors in a shield-and-spear duel",
            ("hearts", "J"): "a centaur (half man, half horse) rearing up and drawing a bow",
            ("diamonds", "J"): "the winged horse Pegasus rearing up with spread wings",
            ("clubs", "J"): "the hero Herakles wrestling the Nemean lion, wearing the lion skin",
        },
    },
    "egyptian": {
        "style": EGYPTIAN_STYLE,
        "suits": {
            "hearts": ("heart", "deep terracotta red"),
            "diamonds": ("diamond lozenge", "deep terracotta red"),
            "spades": ("spade", "black"),
            "clubs": ("trefoil club (clover)", "black"),
        },
        "frame": (
            "A blank flat field of a single even warm golden-ochre amber color "
            "(Egyptian ochre), one solid flat color filling the entire image, "
            "absolutely no texture, no pattern, no gradient, no figures, no border, "
            "no text. Portrait orientation."
        ),
        "emblem_style": (
            "a bold flat solid graphic silhouette style: a clean crisp solid shape, "
            "high contrast, completely flat, no shading and no interior detail."
        ),
        "emblem_fill": (
            "a single solid flat {color} silhouette with clean crisp edges, no "
            "shading and no interior texture"
        ),
        "iso_note": (
            "Render ONLY the figure's own solid silhouette shape — no rectangular "
            "panel, box, block, tablet or background field of any kind behind or "
            "around it, on a fully transparent background."
        ),
        # Aces show a distinct iconic Egyptian object per suit (not the suit symbol).
        "ace_objects": {
            "spades": "ankh (the Egyptian looped cross, symbol of life)",
            "hearts": "winged scarab beetle (khepri) with outspread wings",
            "diamonds": "Eye of Horus (wedjat eye)",
            "clubs": "golden pharaoh funerary mask in a striped nemes headdress",
        },
        "back": (
            "A playing-card BACK in bold flat Egyptian hieroglyph style: a SINGLE "
            "CENTERED medallion of a winged scarab beetle holding a sun disk, enclosed "
            "in a thin circular band, in solid black on a plain warm golden-ochre amber "
            "ground. High contrast, flat, no shading, no texture. The medallion sits in "
            "the middle with a GENEROUS plain ochre margin all around it and empty "
            "ochre ground extending to every edge. Portrait orientation. NO border "
            "frame at the card edges, NO extra colors, NO text, NO numbers, NO letters, "
            "NO pips."
        ),
        "courts": {
            ("spades", "K"): "the god Osiris as a wrapped mummy with green skin, wearing the tall white Atef crown with two feathers, holding the crook and flail across his chest",
            ("spades", "Q"): "the goddess Isis in a sheath dress with a throne-shaped headdress, arms outstretched showing long feathered wings",
            ("spades", "J"): "the jackal-headed god Anubis standing in profile, holding a tall was-scepter",
            ("hearts", "K"): "the falcon-headed sun god Ra crowned with a golden sun disk encircled by a cobra, holding a was-scepter",
            ("hearts", "Q"): "the goddess Hathor as a woman with cow horns cradling a golden sun disk, holding a sistrum rattle",
            ("hearts", "J"): "the cat-headed goddess Bastet standing in a green sheath dress, holding a sistrum",
            ("diamonds", "K"): "a young pharaoh (Tutankhamun) enthroned, wearing the blue-and-gold striped nemes headdress with a golden cobra, holding the crook and flail",
            ("diamonds", "Q"): "Queen Nefertiti in profile wearing her tall flat-topped blue crown and a broad jeweled collar",
            ("diamonds", "J"): "an Egyptian scribe seated cross-legged with an unrolled papyrus scroll on his lap and a reed pen",
            ("clubs", "K"): "the falcon-headed god Horus wearing the tall Double Crown of Upper and Lower Egypt, holding a was-scepter",
            ("clubs", "Q"): "the goddess Ma'at, a woman with a single tall ostrich feather on her head, arms outstretched showing feathered wings",
            ("clubs", "J"): "the ibis-headed god Thoth holding a scribe's palette and a reed pen",
        },
    },
    "gyotaku": {
        "style": GYOTAKU_STYLE,
        "suits": {
            "hearts": ("heart", "vermilion red"),
            "diamonds": ("diamond lozenge", "vermilion red"),
            "spades": ("spade", "black"),
            "clubs": ("trefoil club (clover)", "black"),
        },
        "frame": (
            "A blank sheet of aged cream Japanese washi paper: a soft off-white cream "
            "handmade paper with subtle fibers and a faint mottled texture, evenly lit. "
            "Completely EMPTY: no fish, no ink, no figures, no symbols, no border, no "
            "text — just the plain washi surface filling the whole image. Portrait "
            "orientation."
        ),
        "emblem_style": (
            "a bold Japanese hand-pressed ink seal-stamp (hanko) style: a solid inky "
            "stamped shape with slightly rough, uneven hand-stamped edges and faint "
            "ink texture, flat and graphic, no photorealism."
        ),
        "emblem_fill": (
            "a single {color} shape hand-pressed like a hand-carved ink seal stamp — "
            "a completely FILLED SOLID inky stamped impression (NOT hollow, NOT just "
            "an outline) with slightly rough, uneven hand-stamped edges and faint ink "
            "texture, with NO separate dark outline and NO drop shadow"
        ),
        "iso_note": (
            "Render ONLY the fish's own inked silhouette shape — no rectangular panel, "
            "box, paper sheet or background field of any kind behind or around it, on a "
            "fully transparent background."
        ),
        # Aces are the prized invertebrate catches (also classic gyotaku subjects).
        "ace_objects": {
            "spades": "a large octopus (tako) with curling tentacles",
            "hearts": "a large sweet prawn / shrimp (ebi) curved head to tail",
            "diamonds": "a crab (kani) seen from above with claws spread",
            "clubs": "a squid (ika) with trailing tentacles",
        },
        "back": (
            "A symmetric ornamental playing-card BACK in Japanese gyotaku sumi-ink "
            "style: a single centered black-ink fish-print medallion of a curled koi "
            "carp within a thin ink ring, with one small vermilion-red seal (hanko) "
            "stamp, on aged cream washi paper. Clean and uncluttered with generous "
            "negative space. The design fills the FULL WIDTH edge to edge; keep the "
            "motif within the central area and leave only plain washi along the very "
            "TOP and very BOTTOM edges (this margin will be trimmed). Symmetric, "
            "portrait orientation. NO text, NO numbers, NO letters, NO pips."
        ),
        "courts": {
            ("hearts", "K"): "a large ornamental koi carp curving in a graceful S-shape as if swimming upward",
            ("hearts", "Q"): "a yamame cherry trout with crimson and indigo spots along its side, angled steeply head-up in a near-vertical orientation",
            ("hearts", "J"): "a slender ayu sweetfish angled diagonally",
            ("spades", "K"): "a large sea bass (suzuki) angled diagonally head-up",
            ("spades", "Q"): "a long Japanese eel (unagi) curving in an S-shape vertically",
            ("spades", "J"): "a mackerel (saba) angled diagonally",
            ("diamonds", "K"): "a red sea bream (tai) angled diagonally head-up, a large auspicious fish",
            ("diamonds", "Q"): "a yellowtail (buri) angled diagonally",
            ("diamonds", "J"): "a flatfish flounder (hirame) seen from above, with mottled sandy-brown and grey markings and both eyes on top",
            ("clubs", "K"): "a powerful bluefin tuna (maguro) angled diagonally head-up",
            ("clubs", "Q"): "a slender Pacific saury (sanma) angled diagonally",
            ("clubs", "J"): "a pufferfish (fugu) un-puffed in a natural side profile, angled steeply head-up in a near-vertical orientation",
        },
    },
    "roman": {
        "style": ROMAN_STYLE,
        "suits": {
            "hearts": ("heart", "deep red"),
            "diamonds": ("diamond lozenge", "deep red"),
            "spades": ("spade", "dark slate-black"),
            "clubs": ("trefoil club (clover)", "dark slate-black"),
        },
        "emblem_fill": "a bold {color} shape built from small mosaic tesserae with grout lines",
        # Standalone mosaic figures on transparent backgrounds (composited onto a
        # subtle procedural tessera ground) — same approach as the illuminated deck.
        "ace_objects": {
            "spades": "a Roman legionary helmet (galea)",
            "hearts": "a laurel victory wreath",
            "diamonds": "a two-handled Roman amphora",
            "clubs": "a Roman legionary eagle standard (aquila)",
        },
        "courts": {
            # Hearts — the sea and love.
            ("hearts", "K"): "the god Neptune holding a trident, flanked by two dolphins",
            ("hearts", "Q"): "the goddess Juno, crowned and robed, holding a scepter, with a peacock",
            ("hearts", "J"): "a single leaping dolphin over stylized waves",
            # Spades — power and war.
            ("spades", "K"): "the god Jupiter enthroned holding a thunderbolt, with an eagle",
            ("spades", "Q"): "the goddess Minerva in a crested helmet with an owl",
            ("spades", "J"): "a Roman gladiator with a short sword and a rectangular shield",
            # Diamonds — nobility, the hunt and the games.
            ("diamonds", "K"): "a victorious charioteer driving a four-horse quadriga",
            ("diamonds", "Q"): "the goddess Diana the huntress with a bow and a stag",
            ("diamonds", "J"): "the god Bacchus crowned with grapevine, holding a wine cup",
            # Clubs — Rome and myth.
            ("clubs", "K"): "the god Mars in full Roman armor and plumed helmet, holding a spear and shield",
            ("clubs", "Q"): "a Medusa gorgoneion medallion with snakes for hair",
            ("clubs", "J"): "a guard dog on a chain (the 'Cave Canem' dog)",
        },
    },
}


def eff_style(deck, suit):
    """Deck style, plus the suit's vase technique if the deck defines one."""
    d = DECKS[deck]
    tech = d.get("technique")
    return d["style"] + (" " + tech[suit] if tech else "")


def print_prompt(deck, suit, rank):
    d = DECKS[deck]
    scene = d["prints"][(suit, rank)]
    return (
        f"{scene}. Rendered in {d['style']} Arranged as a vertical portrait "
        f"composition that fills the entire image edge to edge (full-bleed scene). "
        f"No card, no border, no frame, no text, no signature."
    )


def emblem_prompt(deck, suit):
    d = DECKS[deck]
    emblem, color = d["suits"][suit]
    fill = d["emblem_fill"].format(color=color)
    # A deck whose figure style depicts a subject (e.g. gyotaku fish) needs a
    # separate plain style for the bare suit symbol, or the subject leaks in.
    style = d.get("emblem_style", eff_style(deck, suit))
    clean = (" It is a clean solid even silhouette with a smooth fill and NO interior "
             "lines, stems, flourishes or patterns, perfectly upright with the two "
             "rounded lobes at the TOP and the single point at the BOTTOM."
             if deck == "greek" else "")
    return (
        f"A single playing-card suit symbol: one {emblem}, in {style} "
        f"It is {fill}, symmetric and upright with clean edges.{clean} It is ONLY the "
        f"plain {emblem} outline shape — NO fish, NO animal, NO creature, NO figure, "
        f"NO person, NO hieroglyph and nothing else inside or around it. Just the bare "
        f"symbol shape ALONE on a 100% transparent background. Absolutely NO "
        f"rectangular panel, NO frame, NO box, NO washi paper, NO paper texture, "
        f"NO textured backdrop of any kind behind or around the symbol, no card, "
        f"no text — nothing but the single {emblem} shape floating in empty space."
        f"{_iso(deck)}"
    )


def ace_prompt(deck, suit):
    d = DECKS[deck]
    emblem, color = d["suits"][suit]
    objects = d.get("ace_objects")
    if objects and d.get("ace_print"):
        return (
            f"An image of {objects[suit]}, in {eff_style(deck, suit)} A vertical "
            f"portrait composition that fills the entire image edge to edge "
            f"(full-bleed). No card, no border, no text, no signature."
        )
    if objects:
        body = f"One single {objects[suit]}, centered, symmetric and upright"
    else:
        body = d["ace"].format(emblem=emblem, color=color)
    return (
        f"{body} In {eff_style(deck, suit)} The complete subject occupies only the central "
        f"~60% of the frame with generous empty margin on all sides — its top and "
        f"bottom must NOT touch or be cropped by any edge. Isolated on a 100% "
        f"transparent background, no washi paper or texture behind it. No card, no "
        f"border, no text.{_iso(deck)}"
    )


def court_prompt(deck, suit, rank):
    d = DECKS[deck]
    figure = d["courts"][(suit, rank)]
    return (
        f"A single small full-length depiction of {figure}, drawn with the linework "
        f"and flat colors of {eff_style(deck, suit)} "
        f"The figure occupies only the central ~65% of the frame, centered and "
        f"upright, with WIDE empty margins on all four sides — the top of the "
        f"head/hat and the feet must be well inside the frame and NOT touch or be "
        f"cropped by any edge. The background is 100% fully transparent: absolutely "
        f"NO paper, NO washi texture, NO backdrop, NO rectangle behind the figure. "
        f"No card, no border, no floor, no suit symbols, no text.{_iso(deck)}"
    )


def _iso(deck):
    note = DECKS[deck].get("iso_note")
    return " " + note if note else ""


def request_image(prompt, api_key, size, quality, transparent, retries=3):
    payload = {
        "model": "gpt-image-1",
        "prompt": prompt,
        "size": size,
        "quality": quality,
        "n": 1,
        "output_format": "png",
    }
    if transparent:
        payload["background"] = "transparent"
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


def save(deck, name, prompt, api_key, size, quality, transparent):
    out_dir = os.path.join(COMP_ROOT, deck)
    os.makedirs(out_dir, exist_ok=True)
    print(f"  -> {name}", flush=True)
    img = request_image(prompt, api_key, size, quality, transparent)
    with open(os.path.join(out_dir, name), "wb") as f:
        f.write(img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--deck", choices=DECKS.keys(), default="ukiyo-e")
    ap.add_argument("--suit", choices=["hearts", "diamonds", "spades", "clubs"], default="hearts")
    ap.add_argument("--what", default="all",
                    choices=["all", "frame", "pip", "ace", "courts", "prints", "back"])
    ap.add_argument("--ranks", default="J,Q,K", help="court/print ranks to make")
    ap.add_argument("--quality", default="medium", choices=["low", "medium", "high", "auto"])
    args = ap.parse_args()
    court_ranks = [r.strip().upper() for r in args.ranks.split(",")]

    key = os.environ.get("OPENAI_API_KEY")
    if not key:
        sys.exit("ERROR: set OPENAI_API_KEY first.")

    deck, suit = args.deck, args.suit
    print(f"[{deck}] components for {suit} (q={args.quality}) -> {os.path.join(COMP_ROOT, deck)}")

    if args.what in ("all", "frame"):
        frames = DECKS[deck].get("frames")
        if frames:
            for ground, prompt in frames.items():
                save(deck, f"frame_{ground}.png", prompt, key, "1024x1536", args.quality, False)
        else:
            save(deck, "frame.png", DECKS[deck]["frame"], key, "1024x1536", args.quality, False)
    if args.what in ("all", "pip"):
        save(deck, f"pip_{suit}.png", emblem_prompt(deck, suit), key, "1024x1024", args.quality, True)
    if args.what in ("all", "ace"):
        ace_print = DECKS[deck].get("ace_print")
        save(deck, f"ace_{suit}.png", ace_prompt(deck, suit), key,
             "1024x1536" if ace_print else "1024x1024", args.quality, transparent=not ace_print)
    if args.what in ("all", "courts") and "prints" not in DECKS[deck]:
        for rank in court_ranks:
            save(deck, f"court_{suit}_{rank}.png", court_prompt(deck, suit, rank),
                 key, "1024x1536", args.quality, True)
    # Card back — one full-bleed ornamental design per deck (suit-independent).
    if args.what in ("all", "back") and DECKS[deck].get("back"):
        save(deck, "back.png", DECKS[deck]["back"], key, "1024x1536", args.quality, False)
    # Print-based face cards, one distinct print per suit.
    if args.what in ("all", "prints") and "prints" in DECKS[deck]:
        for rank in court_ranks:
            save(deck, f"print_{suit}_{rank}.png", print_prompt(deck, suit, rank),
                 key, "1024x1536", args.quality, False)

    print("Done.")


if __name__ == "__main__":
    main()
