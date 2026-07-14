# -*- coding: utf-8 -*-
"""Pet owl companion for Underhalls: round fluffy owl, front-facing for maximum
cute — big amber eyes, ear tufts, cream facial disc/belly, flappy wings.
24x24 frames, 6-frame idle (hover bob + both wings + blink)."""
from PIL import Image
import os

OUT = r"C:\Users\siebe\Documents\claude-test\Assets\Companions"
SP = r"C:\Users\siebe\AppData\Local\Temp\claude\C--Users-siebe-Documents-claude-test\c5068587-89ad-4eab-b9fd-a8437c533f13\scratchpad"
os.makedirs(OUT, exist_ok=True)

PAL = {
    'o': (26, 16, 28, 255),     # outline
    'F': (146, 104, 78, 255),   # feathers
    'f': (104, 70, 52, 255),    # feather shade
    'D': (238, 222, 190, 255),  # facial disc cream
    'B': (226, 204, 168, 255),  # belly cream
    'A': (255, 196, 70, 255),   # eye amber
    'K': (30, 20, 30, 255),     # pupil
    'X': (252, 250, 244, 255),  # eye sparkle
    'k': (222, 160, 70, 255),   # beak / talons
    'v': (255, 214, 140, 70),   # soft lantern glow rim
    '.': (0, 0, 0, 0),
}

W, H = 24, 24

BASE = [
    "",
    "",
    ".....oo..........oo",
    ".....oFFo.......oFFo",
    "....ooFFFooooooFFFoo",
    "....oFFFFFFFFFFFFFFo",
    "...oFFDDDDDFFDDDDDFFo",
    "...oFDAAAADDDDAAAADFo",
    "...oFDAKXADDDDAKXADFo",
    "...oFDAKKADDDDAKKADFo",
    "...oFDDAADDokkoAADDFo",
    "...oFFDDDDDokkoDDDFFo",
    "....oFFDDDDDooDDDFFo",
    "....oFBBBBBBBBBBBBFo",
    "....oFBBfBBBBBfBBBFo",
    "....oFBBBBBBBBBBBBFo",
    "....oFBBBBBfBBBBBBFo",
    ".....oFBBBBBBBBBBFo",
    ".....ooFBBBBBBBBFoo",
    ".......ooBBBBBBoo",
    ".........okko.okko",
    ".........okko.okko",
    "..........oo...oo",
    "",
]

# Wing overlays (body pixels only, outlines auto-added; drawn behind the body).
def mirror(pixels):
    return [(W - 1 - x, y, c) for x, y, c in pixels]

WING_UP_L = [
    (4, 12, 'F'), (3, 11, 'F'), (4, 11, 'F'),
    (2, 10, 'F'), (3, 10, 'F'),
    (2, 9, 'F'), (1, 8, 'F'), (1, 7, 'f'),
]
WING_MID_L = [
    (4, 12, 'F'), (3, 12, 'F'), (2, 12, 'F'), (1, 12, 'f'),
    (2, 13, 'f'), (3, 13, 'F'), (4, 13, 'F'),
]
WING_DOWN_L = [
    (4, 13, 'F'), (3, 14, 'F'), (4, 14, 'F'),
    (2, 15, 'F'), (3, 15, 'f'),
    (2, 16, 'f'),
]
WING_UP = WING_UP_L + mirror(WING_UP_L)
WING_MID = WING_MID_L + mirror(WING_MID_L)
WING_DOWN = WING_DOWN_L + mirror(WING_DOWN_L)

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
    for y in range(H):
        for x in range(W):
            if g[y][x] in ('A', 'K', 'X'):
                g[y][x] = 'D'
    # closed-lid lines across both eyes
    for x in (6, 7, 8, 9):
        g[9][x] = 'o'
    for x in (14, 15, 16, 17):
        g[9][x] = 'o'
    return g

def add_glow(g):
    """1px warm halo on transparent pixels around the owl so he stays readable
    against dark dungeon floors, especially while moving."""
    src = [row[:] for row in g]
    for y in range(H):
        for x in range(W):
            if src[y][x] != '.':
                continue
            near = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < H and 0 <= xx < W and src[yy][xx] not in ('.', 'v'):
                        near = True
            if near:
                g[y][x] = 'v'
    return g

def frame(wing, bob, blinking=False):
    g = base_grid()
    if blinking:
        g = blink(g)
    g = shift(g, bob)
    overlay_behind(g, wing, dy=bob)
    return add_glow(g)

FRAMES = [
    frame(WING_MID, 0),
    frame(WING_UP, 0),
    frame(WING_UP, -1),
    frame(WING_MID, -1),
    frame(WING_DOWN, 0),
    frame(WING_DOWN, 0, blinking=True),
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
strip.save(os.path.join(OUT, "owl_idle.png"))

S = 10
prev = Image.new("RGBA", (strip.width * S + 40, H * S + 40), (24, 20, 32, 255))
big = strip.resize((strip.width * S, strip.height * S), Image.NEAREST)
prev.paste(big, (20, 20), big)
prev.save(os.path.join(SP, "owl_preview.png"))
print("done", strip.size)
