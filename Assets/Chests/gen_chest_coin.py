# -*- coding: utf-8 -*-
"""Chests (5 rarities x 6-frame opening animation) + spinning gold coin.
Chest trim/gem/glow are tinted with the game's perk RARITY_COLORS so chest
rarity reads identically to perk rarity. 26x24 frames; coin 8x8 x4."""
from PIL import Image
import os

OUT = r"C:\Users\siebe\Documents\claude-test\Assets\Chests"
SP = r"C:\Users\siebe\AppData\Local\Temp\claude\C--Users-siebe-Documents-claude-test\c5068587-89ad-4eab-b9fd-a8437c533f13\scratchpad"
os.makedirs(OUT, exist_ok=True)

# Upgrades.RARITY_COLORS (perk system), as 0-255.
RARITIES = {
    "common": (189, 196, 209),
    "rare": (102, 168, 250),
    "epic": (184, 107, 250),
    "legendary": (250, 184, 71),
    "mythic": (250, 87, 107),
}

def scale(c, f, a=255):
    return (min(int(c[0] * f), 255), min(int(c[1] * f), 255), min(int(c[2] * f), 255), a)

def lerp_white(c, t, a=255):
    return (int(c[0] + (255 - c[0]) * t), int(c[1] + (255 - c[1]) * t), int(c[2] + (255 - c[2]) * t), a)

def palette(rc):
    return {
        'o': (26, 16, 28, 255),
        'B': (154, 96, 56, 255),    # wood
        'b': (104, 62, 36, 255),    # wood shade
        'H': (196, 138, 86, 255),   # wood highlight
        'T': scale(rc, 1.0),        # rarity trim
        't': scale(rc, 0.55),       # trim shade
        'h': lerp_white(rc, 0.45),  # trim highlight
        'G': lerp_white(rc, 0.65),  # gem / bright core
        'S': (30, 16, 34, 255),     # interior dark
        'V': lerp_white(rc, 0.35, 170),  # glow strong
        'v': scale(rc, 1.0, 80),         # glow faint
        '*': (255, 255, 255, 220),  # sparkle
        '.': (0, 0, 0, 0),
    }

W, H = 26, 24

CLOSED = [
    "", "", "", "", "",
    ".....ooooooooooooooo",
    "....oBHHHHHHHHHHHHHBo",
    "...oBHBBBBBBBBBBBBBBBo",
    "...oBTthBBBBBBBBBBTthBo",
    "...oBTthBBBoooooBBTthBo",
    "...ooooooooTTTTooooooo",
    "...oBTthBBoThGGToBTthBo",
    "...oBTthBBoTGGGToBTthBo",
    "...oBTthBBoTTTTToBTthBo",
    "...oBTthBBBoooooBBTthBo",
    "...oBTthBBBBBBBBBBTthBo",
    "...obTthbbbbbbbbbbTthbo",
    "...obTthbbbbbbbbbbTthbo",
    "....ooooooooooooooooo",
    "", "", "", "", "",
]

HALF = [
    "", "",
    "....ooooooooooooooo",
    "...oBHHHHHHHHHHHHHHBo",
    "..oBHBBBBBBBBBBBBBBBBo",
    "..oooooooooooooooooooo",
    "....oSSSSSvvvvSSSSSo",
    "...oSSSSSvvVVvvSSSSSo",
    "...ooooooooooooooooooo",
    "...oBTthBBBoooooBBTthBo",
    "...ooooooooTTTTooooooo",
    "...oBTthBBoThGGToBTthBo",
    "...oBTthBBoTGGGToBTthBo",
    "...oBTthBBoTTTTToBTthBo",
    "...oBTthBBBoooooBBTthBo",
    "...oBTthBBBBBBBBBBTthBo",
    "...obTthbbbbbbbbbbTthbo",
    "...obTthbbbbbbbbbbTthbo",
    "....ooooooooooooooooo",
    "", "", "", "", "",
]

OPEN = [
    "", "", "",
    "....oooooooooooooooo",
    "...oBbbbbbbbbbbbbbbbBo",
    "...oooooooooooooooooo",
    "...oSSSSSSvvVVvvSSSSSo",
    "..oSSSSSvvVVVVVvvSSSSo",
    "..oSSSSSvVVGGVVvvSSSSo",
    "...ooooooooooooooooooo",
    "...oBTthBBBoooooBBTthBo",
    "...ooooooooTTTTooooooo",
    "...oBTthBBoThGGToBTthBo",
    "...oBTthBBoTGGGToBTthBo",
    "...oBTthBBoTTTTToBTthBo",
    "...oBTthBBBoooooBBTthBo",
    "...oBTthBBBBBBBBBBTthBo",
    "...obTthbbbbbbbbbbTthbo",
    "...obTthbbbbbbbbbbTthbo",
    "....ooooooooooooooooo",
    "", "", "", "", "",
]

# Rising glow + sparkles over the OPEN state, one per animation beat.
GLOW_1 = [(11, 5, 'v'), (12, 5, 'v'), (13, 5, 'v'), (14, 5, 'v')]
GLOW_2 = GLOW_1 + [(10, 4, 'v'), (12, 4, 'V'), (13, 4, 'V'), (15, 4, 'v'),
                   (11, 3, 'v'), (14, 3, 'v'), (8, 6, '*')]
GLOW_3 = GLOW_2 + [(12, 2, 'v'), (13, 2, 'v'), (12, 1, 'v'), (17, 3, '*'),
                   (10, 1, '*'), (14, 0, 'v'), (11, 0, 'v')]
GLOW_SETTLE = GLOW_1 + [(12, 4, 'v'), (13, 4, 'v'), (16, 5, '*')]

def grid(rows):
    g = [['.'] * W for _ in range(H)]
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c != '.' and c != '':
                g[y][x] = c
    return g

def with_overlay(rows, pixels):
    g = grid(rows)
    for x, y, c in pixels:
        if g[y][x] == '.':
            g[y][x] = c
    return g

def render(g, pal, w=W, h=H):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            px[x, y] = pal[g[y][x]]
    return img

def chest_frames():
    return [
        grid(CLOSED),
        grid(HALF),
        with_overlay(OPEN, GLOW_1),
        with_overlay(OPEN, GLOW_2),
        with_overlay(OPEN, GLOW_3),
        with_overlay(OPEN, GLOW_SETTLE),
    ]

frames = chest_frames()
for name, rc in RARITIES.items():
    pal = palette(rc)
    strip = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
    for i, g in enumerate(frames):
        strip.paste(render(g, pal), (i * W, 0))
    strip.save(os.path.join(OUT, f"chest_{name}.png"))

# ---------------- coin (8x8, 4-frame spin) ----------------
COIN_PAL = {
    'o': (26, 16, 28, 255),
    'G': (240, 196, 80, 255),
    'g': (180, 130, 40, 255),
    'h': (255, 235, 160, 255),
    '.': (0, 0, 0, 0),
}
COIN = [
    [
        "..oooo..",
        ".ohhGGo.",
        "ohGGGgGo",
        "ohGgGGgo",
        "oGGGGGgo",
        "oGgGGggo",
        ".oGgggo.",
        "..oooo..",
    ],
    [
        "...oo...",
        "..ohGo..",
        ".ohGGgo.",
        ".ohGGgo.",
        ".oGGGgo.",
        ".oGGggo.",
        "..oGgo..",
        "...oo...",
    ],
    [
        "...oo...",
        "...oGo..",
        "..ohGo..",
        "..ohGo..",
        "..oGgo..",
        "..oGgo..",
        "...ogo..",
        "...oo...",
    ],
    [
        "...oo...",
        "..ohGo..",
        ".ohGGgo.",
        ".ohGGgo.",
        ".oGGGgo.",
        ".oGGggo.",
        "..oGgo..",
        "...oo...",
    ],
]
coin_strip = Image.new("RGBA", (8 * 4, 8), (0, 0, 0, 0))
for i, rows in enumerate(COIN):
    g = [list(r.ljust(8, '.')) for r in rows]
    coin_strip.paste(render(g, COIN_PAL, 8, 8), (i * 8, 0))
coin_strip.save(os.path.join(OUT, "coin.png"))

# preview: mythic chest animation + one closed chest per rarity + coin
S = 8
rows_imgs = []
myth = Image.open(os.path.join(OUT, "chest_mythic.png"))
rows_imgs.append(myth)
closed_row = Image.new("RGBA", (W * 5, H), (0, 0, 0, 0))
for i, name in enumerate(RARITIES):
    im = Image.open(os.path.join(OUT, f"chest_{name}.png")).crop((0, 0, W, H))
    closed_row.paste(im, (i * W, 0))
rows_imgs.append(closed_row)
rows_imgs.append(coin_strip)
pw = max(r.width for r in rows_imgs) * S + 40
ph = sum(r.height * S + 20 for r in rows_imgs) + 20
prev = Image.new("RGBA", (pw, ph), (24, 20, 32, 255))
y = 20
for r in rows_imgs:
    big = r.resize((r.width * S, r.height * S), Image.NEAREST)
    prev.paste(big, (20, y), big)
    y += big.height + 20
prev.save(os.path.join(SP, "chest_preview.png"))
print("done")
