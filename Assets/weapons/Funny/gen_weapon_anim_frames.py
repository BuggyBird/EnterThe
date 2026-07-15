# -*- coding: utf-8 -*-
"""Wind-up animation frames for the funny weapons (companion to gen_funny_weapons.py).

longbow_draw_1..3.png  — the soul string bends into a V, the arrow slides back with
                         it and the limbs flex toward the archer. Canvas is the base
                         longbow padded 6px on BOTH sides (31x27) so the art keeps the
                         exact same position relative to the sprite centre; the pulled
                         string/arrow use the left padding.
crossbow_charge_1..3.png — the soul string heats up and ghostly banked bolts
                         materialise above the stock as shots are charged. Same
                         34x17 canvas as the base crossbow.
"""
from PIL import Image
import os

OUT = os.path.dirname(os.path.abspath(__file__))

COMMON = {
    'o': (26, 16, 28, 255),
    '.': (0, 0, 0, 0),
}

# ---------------- Longbow draw frames ----------------
BOW_PAL = dict(COMMON, **{
    'B': (112, 76, 98, 255),    # cursed wood
    'b': (74, 48, 66, 255),     # wood shade / knots
    'H': (156, 108, 132, 255),  # wood highlight
    'T': (124, 232, 255, 255),  # soul string
    'X': (222, 250, 255, 255),  # string at full draw: white-hot
    'A': (212, 222, 236, 255),  # spectral arrow shaft
    'S': (86, 224, 202, 255),   # soul crystal head
    'R': (150, 238, 255, 255),  # spectral fletching
    'G': (230, 180, 70, 255),   # grip wrap
    'g': (172, 120, 42, 255),   # grip wrap shade
    'v': (124, 232, 255, 80),   # faint soul glow
})

PAD = 6  # symmetric padding keeps art centred exactly like the base 19x27 sprite


def longbow_draw_grid(draw):
    """The base longbow at draw stage 1..3: string V, arrow pulled back, limbs flexed."""
    W, H = 19 + PAD * 2, 27
    MID = 13
    pull = 2 * draw                       # px the string/arrow travel back
    g = [['.'] * W for _ in range(H)]

    def put(x, y, c):
        x += PAD
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = c

    # limb flex: rows near the tips lean toward the archer as the draw deepens
    def flex(y):
        dist = abs(y - MID)
        f = 0
        if draw >= 2 and dist >= 10:
            f += 1
        if draw == 3 and dist >= 12:
            f += 1
        return f

    offs = [5, 6, 7, 8, 9, 9, 10, 10, 11, 11, 11, 11, 11, 11]
    offs = offs + offs[-2::-1]
    for y, off in enumerate(offs):
        off -= flex(y)
        tip = y in (0, H - 1)
        put(off, y, 'o')
        put(off + 1, y, 'B' if tip else 'H')
        if not tip:
            put(off + 2, y, 'B')
        put(off + (2 if tip else 3), y, 'o')
    put(4 - flex(0), 0, 'o')
    put(4 - flex(H - 1), H - 1, 'o')
    # knots in the cursed wood
    for y in (5, 8, 18, 21):
        put(offs[y] - flex(y) + 2, y, 'b')
    # gold grip wrap over the belly
    for y in range(11, 16):
        put(offs[y] + 1, y, 'G')
        put(offs[y] + 2, y, 'g')

    # string: a V from each (flexed) tip anchor to the pull point at the nock
    string_c = 'X' if draw == 3 else 'T'
    for y in range(1, H - 1):
        dist = abs(y - MID)
        anchor = 4 - flex(y)
        x = round(anchor + ((4 - pull) - anchor) * (1.0 - dist / float(MID - 1)))
        put(x, y, string_c)

    # arrow: nocked on the pull point, everything shifted back by `pull`
    put(1 - pull, MID - 1, 'R'); put(2 - pull, MID - 1, 'R')
    put(1 - pull, MID + 1, 'R'); put(2 - pull, MID + 1, 'R')
    for x in range(1, 4):
        put(x - pull, MID, 'R')
    for x in range(4, 15):
        put(x - pull, MID, 'A')
    put(15 - pull, MID, 'S'); put(16 - pull, MID, 'S'); put(17 - pull, MID, 'S')
    put(15 - pull, MID - 1, 'o'); put(16 - pull, MID - 1, 'o')
    put(15 - pull, MID + 1, 'o'); put(16 - pull, MID + 1, 'o')
    put(17 - pull, MID - 1, 'o'); put(17 - pull, MID + 1, 'o')
    put(18 - pull, MID, 'o')
    # outline the arrow shaft/fletch
    for x in range(0 - pull, 15 - pull):
        for dy in (-1, 1):
            if 0 <= x + PAD < W and g[MID + dy][x + PAD] == '.':
                put(x, MID + dy, 'o')
    put(0 - pull, MID, 'o')
    for x, y in [(0, MID - 2), (1, MID - 2), (2, MID - 2),
                 (0, MID + 2), (1, MID + 2), (2, MID + 2),
                 (3, MID - 1), (3, MID + 1)]:
        if g[y][x - pull + PAD] == '.':
            put(x - pull, y, 'o')
    return ["".join(r) for r in g]


# ---------------- Crossbow charge frames ----------------
XBOW_PAL = dict(COMMON, **{
    'B': (112, 76, 98, 255),    # cursed wood
    'b': (74, 48, 66, 255),     # wood shade
    'H': (156, 108, 132, 255),  # wood highlight
    'S': (108, 116, 140, 255),  # dark iron
    's': (64, 70, 92, 255),     # iron shade
    'T': (124, 232, 255, 255),  # soul string
    'U': (176, 242, 255, 255),  # string, energised
    'X': (230, 252, 255, 255),  # string, white-hot
    'A': (212, 222, 236, 255),  # spectral bolt shaft
    'a': (212, 222, 236, 140),  # ghost banked bolt shaft
    'G': (230, 180, 70, 255),   # gold fitting
    'C': (86, 224, 202, 255),   # soul crystal
    'c': (86, 224, 202, 170),   # ghost banked bolt head
    'v': (124, 232, 255, 80),   # faint soul glow
    'u': (124, 232, 255, 36),   # outer glow ring
})


def crossbow_grid():
    """Identical to gen_funny_weapons.crossbow_grid — the charge frames build on it."""
    W, H, MID = 34, 17, 8
    g = [['.'] * W for _ in range(H)]

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = c

    def outline_around(cells):
        for x, y in list(cells):
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if 0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] == '.':
                        g[y + dy][x + dx] = 'o'
    body = set()
    for x in range(1, 25):
        for y in (7, 8, 9):
            put(x, y, 'H' if y == 7 else ('B' if y == 8 else 'b')); body.add((x, y))
    for x in range(1, 4):
        for y in (6, 10):
            put(x, y, 'B'); body.add((x, y))
    for y in range(10, 14):
        for x in (10, 11):
            put(x, y, 'b' if y > 11 else 'B'); body.add((x, y))
    put(12, 10, 'G'); body.add((12, 10))
    limb = [(25, 7), (24, 6), (23, 6), (23, 5), (22, 5), (22, 4), (21, 4),
            (21, 3), (20, 3), (20, 2), (19, 2)]
    for x, y in limb:
        put(x, y, 'S'); body.add((x, y))
        put(x, y + 1, 's'); body.add((x, y + 1))
        put(x, 2 * MID - y, 's'); body.add((x, 2 * MID - y))
        put(x, 2 * MID - y - 1, 'S'); body.add((x, 2 * MID - y - 1))
    for y in (7, 8, 9):
        put(25, y, 'S' if y < 9 else 's'); body.add((25, y))
    outline_around(body)
    for y in range(3, 14):
        if g[y][18] in ('.', 'o'):
            put(18, y, 'T')
    put(19, 2, 'S'); put(18, 2, 'T'); put(18, 14, 'T')
    put(6, 8, 'C'); put(8, 8, 'C')
    put(25, 8, 'C')
    for x in range(26, 31):
        put(x, 8, 'A')
    put(31, 8, 'C'); put(32, 8, 'C')
    put(30, 7, 'o'); put(31, 7, 'o'); put(32, 7, 'o')
    put(30, 9, 'o'); put(31, 9, 'o'); put(32, 9, 'o')
    put(33, 8, 'o')
    return g


def crossbow_charge_grid(stage):
    """Charge stage 1..3: string energises; ghost bolts stack up above the stock."""
    g = crossbow_grid()
    string_c = {1: 'U', 2: 'U', 3: 'X'}[stage]
    for y in range(len(g)):
        for x in range(len(g[0])):
            if g[y][x] == 'T':
                g[y][x] = string_c

    def ghost(x0, y, length):
        for x in range(x0, x0 + length):
            if g[y][x] == '.':
                g[y][x] = 'a'
        for x in (x0 + length, x0 + length + 1):
            if g[y][x] == '.':
                g[y][x] = 'c'
    if stage >= 2:
        ghost(6, 4, 6)    # first banked bolt shimmers above the rail
    if stage >= 3:
        ghost(8, 2, 6)    # a second one stacks up — nearly full
    return ["".join(r) for r in g]


def add_glow(rows, targets, glow='v'):
    """1px faint halo on transparent pixels around glowing elements."""
    w = max(len(r) for r in rows)
    g = [list(r.ljust(w, '.')) for r in rows]
    src = [r[:] for r in g]
    for y in range(len(g)):
        for x in range(w):
            if src[y][x] != '.':
                continue
            near = False
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < len(g) and 0 <= xx < w and src[yy][xx] in targets:
                        near = True
            if near:
                g[y][x] = glow
    return ["".join(r) for r in g]


def render(rows, pal, name):
    w = max(len(r) for r in rows)
    rows = [r.ljust(w, '.') for r in rows]
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            px[x, y] = pal[c]
    img.save(os.path.join(OUT, name))
    return img


sprites = []
for d in (1, 2, 3):
    rows = add_glow(longbow_draw_grid(d), {'T', 'X', 'S', 'R'})
    sprites.append(("longbow_draw_%d.png" % d, rows, BOW_PAL))
for st in (1, 2, 3):
    rows = add_glow(crossbow_charge_grid(st), {'T', 'U', 'X', 'C', 'c'})
    if st >= 2:  # a wider aura as the charge builds
        rows = add_glow(rows, {'v'}, glow='u')
    sprites.append(("crossbow_charge_%d.png" % st, rows, XBOW_PAL))

imgs = [render(rows, pal, name) for name, rows, pal in sprites]

S = 12
pad = 20
w = max(im.width for im in imgs) * S + pad * 2
h = sum(im.height * S + pad for im in imgs) + pad
prev = Image.new("RGBA", (w, h), (24, 20, 32, 255))
y = pad
for im in imgs:
    big = im.resize((im.width * S, im.height * S), Image.NEAREST)
    prev.paste(big, (pad, y), big)
    y += big.height + pad
prev.save(os.path.join(os.environ.get("PREVIEW_DIR", OUT), "anim_frames_preview.png"))
print("done", [(n, i.size) for (n, _, _), i in zip(sprites, imgs)])
