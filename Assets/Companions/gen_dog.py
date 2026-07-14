# -*- coding: utf-8 -*-
"""Flying companion pup for Underhalls: cute hovering dog with a tiny wizard hat.
24x24 frames, 6-frame idle (hover bob + wing flap + tail wag + blink).
Style-matched to the player: dark outline, purple hat, soul-cyan gem."""
from PIL import Image
import os

OUT = r"C:\Users\siebe\Documents\claude-test\Assets\Companions"
SP = r"C:\Users\siebe\AppData\Local\Temp\claude\C--Users-siebe-Documents-claude-test\c5068587-89ad-4eab-b9fd-a8437c533f13\scratchpad"
os.makedirs(OUT, exist_ok=True)

PAL = {
    'o': (26, 16, 28, 255),     # outline
    'B': (222, 168, 110, 255),  # tan fur
    'b': (176, 120, 72, 255),   # fur shade
    'H': (242, 202, 150, 255),  # fur highlight
    'E': (150, 95, 55, 255),    # floppy ear / dark fur
    'W': (245, 240, 228, 255),  # white (muzzle, chest, wings)
    'w': (202, 194, 178, 255),  # white shade
    'K': (30, 20, 30, 255),     # eye
    'X': (250, 250, 250, 255),  # eye sparkle
    'N': (52, 32, 42, 255),     # nose
    'P': (232, 130, 150, 255),  # tongue
    'M': (88, 66, 120, 255),    # hat purple (player cloak light)
    'm': (58, 44, 84, 255),     # hat shade
    'G': (230, 180, 70, 255),   # hat band gold
    'C': (124, 232, 255, 255),  # soul gem
    '.': (0, 0, 0, 0),
}

W, H = 24, 24

# Base pup (facing right), wing/tail added per-frame. Rows < 24 chars are padded.
BASE = [
    "",
    ".........oo",
    ".........oMMo",
    "........oMMMMo",
    "........oMmMMMo",
    ".......oGGCGGGo",
    "......ooMMMMMMMoo",
    ".....oBHBBBBBBBBBo",
    "....oEBHBBBBBBBBBBo",
    "...oEEoBBBBBBBKKoBo",
    "...oEEoBBBBBBBKXoBBo",
    "...oEEoBBBBBBBBBoWWWWo",
    "....oEoBBBBBBBBoWWWWNNo",
    "....oo.oBBBBBBBoWWWWWNo",
    ".......oBBBBBBBoWWWPWo",
    "......oBWWBBBBBBooWWo",
    "......oBWWWBBBBBBooo",
    "......oBWWWBBBBBBBo",
    "......oBWWBBBBBBBo",
    ".......oBBBBBBBBo",
    ".......oBBooBBBo",
    "........obo.obo",
    ".........o...o",
    "",
]

# Wing overlays: body pixels only — outlines added automatically. Anchored at
# the pup's back (~x6-7, y13-14) and sticking out clearly left/up-left.
WING_UP = [
    (6, 7, 'w'), (6, 6, 'W'), (5, 6, 'W'),
    (5, 5, 'W'), (4, 5, 'W'),
    (4, 4, 'W'), (3, 4, 'W'),
    (3, 3, 'W'), (3, 2, 'w'),
]
WING_MID = [
    (6, 7, 'w'), (5, 7, 'W'), (6, 6, 'W'),
    (4, 6, 'W'), (5, 6, 'W'),
    (2, 5, 'W'), (3, 5, 'W'), (4, 5, 'W'),
    (1, 5, 'w'),
]
WING_DOWN = [
    (6, 7, 'W'), (5, 8, 'W'), (6, 8, 'w'),
    (4, 8, 'W'), (3, 8, 'W'),
    (2, 9, 'W'), (3, 9, 'w'),
    (1, 9, 'w'),
]

# Tail overlays (bottom-left, wagging curl).
TAIL_UP = [
    (4, 16, 'B'), (3, 15, 'B'), (2, 14, 'B'), (3, 14, 'B'), (2, 13, 'b'),
]
TAIL_DOWN = [
    (4, 17, 'B'), (3, 17, 'B'), (2, 18, 'B'), (3, 18, 'b'), (2, 19, 'b'),
]

def base_grid():
    g = [['.'] * W for _ in range(H)]
    for y, row in enumerate(BASE):
        for x, c in enumerate(row):
            if c != '.' and c != '':
                g[y][x] = c
    return g

def overlay_behind(g, pixels, dy=0):
    placed = []
    for x, y, c in pixels:
        yy = y + dy
        if 0 <= x < W and 0 <= yy < H and g[yy][x] == '.':
            g[yy][x] = c
            placed.append((x, yy))
    # auto-outline the new limb where it meets transparency
    for x, y in placed:
        for ddx in (-1, 0, 1):
            for ddy in (-1, 0, 1):
                xx, yy = x + ddx, y + ddy
                if 0 <= xx < W and 0 <= yy < H and g[yy][xx] == '.':
                    g[yy][xx] = 'o'

def shift(g, dy):
    ng = [['.'] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if g[y][x] != '.' and 0 <= y + dy < H:
                ng[y + dy][x] = g[y][x]
    return ng

def blink(g):
    # Eye cells: K/X around (14-15, 9-10) -> fur, with a closed-lid line below.
    for y in range(H):
        for x in range(W):
            if g[y][x] in ('K', 'X'):
                g[y][x] = 'B'
    g[10][14] = 'o'; g[10][15] = 'o'
    return g

def frame(wing, tail, bob, blinking=False):
    g = base_grid()
    if blinking:
        g = blink(g)
    g = shift(g, bob)
    overlay_behind(g, wing, dy=bob)   # wing rides the body
    overlay_behind(g, tail, dy=bob)
    return g

FRAMES = [
    frame(WING_MID, TAIL_DOWN, 0),
    frame(WING_UP, TAIL_DOWN, 0),
    frame(WING_UP, TAIL_UP, -1),
    frame(WING_MID, TAIL_UP, -1),
    frame(WING_DOWN, TAIL_UP, 0),
    frame(WING_DOWN, TAIL_DOWN, 0, blinking=True),
]

def render(g):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for y in range(H):
        for x in range(W):
            px[x, y] = PAL[g[y][x]]
    return img

strip = Image.new("RGBA", (W * len(FRAMES), H), (0, 0, 0, 0))
for i, g in enumerate(FRAMES):
    strip.paste(render(g), (i * W, 0))
strip.save(os.path.join(OUT, "dog_idle.png"))

S = 10
prev = Image.new("RGBA", (strip.width * S + 40, H * S + 40), (24, 20, 32, 255))
big = strip.resize((strip.width * S, strip.height * S), Image.NEAREST)
prev.paste(big, (20, 20), big)
prev.save(os.path.join(SP, "dog_preview.png"))
print("done", strip.size)
