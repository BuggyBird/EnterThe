# -*- coding: utf-8 -*-
"""Funny weapon sprites for Underhalls — style matched to user's tiny pixel gun reference:
side view facing right, dark outline, bright colors, ~2-tone shading, no outer white outline."""
from PIL import Image
import os

OUT = r"C:\Users\siebe\Documents\claude-test\Assets\weapons\Funny"
SP = r"C:\Users\siebe\AppData\Local\Temp\claude\C--Users-siebe-Documents-claude-test\c5068587-89ad-4eab-b9fd-a8437c533f13\scratchpad"
os.makedirs(OUT, exist_ok=True)

COMMON = {
    'o': (26, 16, 28, 255),
    '.': (0, 0, 0, 0),
}

# ---------------- Carp Diem: angry fish blunderbuss ----------------
FISH_PAL = dict(COMMON, **{
    'R': (226, 90, 70, 255),    # salmon body
    'r': (168, 52, 52, 255),    # body shade
    'P': (245, 150, 118, 255),  # body highlight
    'W': (242, 228, 205, 255),  # belly
    'w': (208, 188, 160, 255),  # belly shade
    'Y': (240, 180, 60, 255),   # fins
    'y': (188, 128, 40, 255),   # fin shade
    'E': (250, 250, 250, 255),  # eye white
    'p': (20, 12, 20, 255),     # pupil
    'C': (78, 20, 34, 255),     # mouth interior
    'T': (242, 228, 205, 255),  # teeth
})
FISH = [
    "............oooooo",
    "...........oYYYYYYo",
    "..oo......oYYYPPYYYo",
    ".oRoo...ooRRRRRRRRRRoo",
    ".oRRRo.oRPPPPRRRRRRRRRooooo",
    "..oRRRoRPPRRRRRRRRRRRRrRRRRooooooo",
    "..oRRRRRRRRRRRRRRRRRRRrREpRRRRRRRRRo",
    ".oRRRRoRRRRRRRRRRRRRRRrRooRRoooooWoo",
    ".oRRo.oRWWWWWWWWWWWWWWrRRRoCCCCCCCo",
    ".oo....oWWWWWWWWWWWWWWwWoCCCCCCoo",
    "........ooooooYYoooooooooWoCCoo",
    "..............oYYo......oRRRoo",
    "...............oyYo......ooo",
    "................oo",
]

# ---------------- The Underkey: giant dungeon key gun ----------------
KEY_PAL = dict(COMMON, **{
    'G': (230, 180, 70, 255),   # gold
    'g': (172, 120, 42, 255),   # gold shade
    'H': (252, 224, 140, 255),  # gold highlight
    'd': (120, 78, 30, 255),    # gold deep shade
    'T': (86, 224, 202, 255),   # soul gem
    't': (40, 152, 140, 255),   # gem shade
    'S': (14, 8, 16, 255),      # ring hole
})
KEY = [
    "...ooooo..........................",
    "..oHHHHGo.........................",
    ".oHGoooGGo........................",
    ".oHo...oGgo.......................",
    ".oHoTToooGooooooooooooooooooooooo.",
    ".oHoTtToGHHHHHHHHHHHHHHHHHHGGoHGo.",
    ".oGoottooGGGGGGGGGGGGGGGGGGggoGgo.",
    ".oGgo..oGgo...ooooo..ooooooooooo..",
    ".ogGoooGgo....oGGgo..oGGgo........",
    "..oggGggo.....oGgo...oGgo.........",
    "...ooooo......ogo....ogo..........",
    "..............oo.....oo...........",
]

# ---------------- Mimic Bite: snapping chest pistol ----------------
MIMIC_PAL = dict(COMMON, **{
    'B': (154, 96, 56, 255),    # wood
    'b': (104, 62, 36, 255),    # wood shade
    'H': (196, 138, 86, 255),   # wood highlight
    'G': (230, 180, 70, 255),   # gold trim
    'g': (172, 120, 42, 255),   # gold shade
    'W': (245, 240, 228, 255),  # teeth
    'S': (44, 18, 38, 255),     # maw
    'T': (232, 108, 142, 255),  # tongue
    't': (178, 66, 104, 255),   # tongue shade
    'E': (124, 232, 255, 255),  # eye glow
})
MIMIC = [
    "....ooooooooooooo.........",
    "...oHHHBBBBBBBHHBo........",
    "..oHBBBBBoEEoBBBBBo.......",
    "..oGGGGGGoEEoGGGGGo.......",
    "..oSWWoWWoSSoWWoWSSo......",
    "..oSoSSSSSSSSSSSSSSo......",
    "..oSSSSSSSSSSSSSSSSSo.....",
    "..oSWoWWoWWoWWoWoSSSo.....",
    "..oGGGGGGGGGGGGGGGGo......",
    "...oBBBBTTBBBBBBBBo.......",
    "....ooooTtoooooooo........",
    "......oTTto...............",
    ".....oTTto................",
    ".....oTTTo................",
    "......ooo.................",
]

# ---------------- Boomerang: white with red lines ----------------
BOOM_PAL = dict(COMMON, **{
    'W': (238, 232, 216, 255),  # bone white
    'w': (196, 188, 168, 255),  # shade
    'R': (222, 62, 84, 255),    # glowing rune red
    'r': (150, 32, 34, 255),    # red shade
    'C': (86, 224, 202, 255),   # soul gem
    'v': (124, 232, 255, 80),   # faint soul glow
})
BOOMERANG = [
    ".ooo",
    "oWWWoo",
    "oRRWWWoo",
    "oRRWWWWWoo",
    ".ooWWWWWWWoo",
    "..ooWRRWWWWWoo",
    "....ooWRRWWWWWo",
    "......ooWWCCWWWo",
    "......ooWWCCWWWo",
    "....ooWRRWWWWWo",
    "..ooWRRWWWWWoo",
    ".ooWWWWWWWoo",
    "oRRWWWWWoo",
    "oRRWWWoo",
    "oWWWoo",
    ".ooo",
]

# ---------------- Crossbow: wood tiller, steel limbs, loaded bolt ----------------
XBOW_PAL = dict(COMMON, **{
    'B': (112, 76, 98, 255),    # cursed wood
    'b': (74, 48, 66, 255),     # wood shade
    'H': (156, 108, 132, 255),  # wood highlight
    'S': (108, 116, 140, 255),  # dark iron
    's': (64, 70, 92, 255),     # iron shade
    'T': (124, 232, 255, 255),  # soul string
    'A': (212, 222, 236, 255),  # spectral bolt shaft
    'G': (230, 180, 70, 255),   # gold fitting
    'C': (86, 224, 202, 255),   # soul crystal
    'v': (124, 232, 255, 80),   # faint soul glow
})
def crossbow_grid():
    """Top-view crossbow: wood stock, steel limbs sweeping back, straight string, bolt."""
    W, H, MID = 34, 17, 8
    g = [['.'] * W for _ in range(H)]
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = c
    def outline_around(cells):
        for x, y in list(cells):
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if 0 <= x+dx < W and 0 <= y+dy < H and g[y+dy][x+dx] == '.':
                        g[y+dy][x+dx] = 'o'
    body = set()
    # stock: rows 7-9, x1-24; butt block x1-3 rows 6-10
    for x in range(1, 25):
        for y in (7, 8, 9):
            put(x, y, 'H' if y == 7 else ('B' if y == 8 else 'b')); body.add((x, y))
    for x in range(1, 4):
        for y in (6, 10):
            put(x, y, 'B'); body.add((x, y))
    # grip below stock + gold trigger
    for y in range(10, 14):
        for x in (10, 11):
            put(x, y, 'b' if y > 11 else 'B'); body.add((x, y))
    put(12, 10, 'G'); body.add((12, 10))
    # limbs: from mount (25,MID) sweeping back to tips (19,2)/(19,14)
    limb = [(25, 7), (24, 6), (23, 6), (23, 5), (22, 5), (22, 4), (21, 4), (21, 3), (20, 3), (20, 2), (19, 2)]
    for x, y in limb:
        put(x, y, 'S'); body.add((x, y))
        put(x, y + 1, 's'); body.add((x, y + 1))
        put(x, 2 * MID - y, 's'); body.add((x, 2 * MID - y))
        put(x, 2 * MID - y - 1, 'S'); body.add((x, 2 * MID - y - 1))
    for y in (7, 8, 9):
        put(25, y, 'S' if y < 9 else 's'); body.add((25, y))
    outline_around(body)
    # string: vertical, tied at limb tips, passing behind the stock
    for y in range(3, 14):
        if g[y][18] in ('.', 'o'):
            put(18, y, 'T')
    put(19, 2, 'S'); put(18, 2, 'T'); put(18, 14, 'T')
    # rune dots on the stock
    put(6, 8, 'C'); put(8, 8, 'C')
    # soul crystal in the limb mount
    put(25, 8, 'C')
    # bolt: rides the rail past the bow, soul-crystal head
    for x in range(26, 31):
        put(x, 8, 'A')
    put(31, 8, 'C'); put(32, 8, 'C')
    put(30, 7, 'o'); put(31, 7, 'o'); put(32, 7, 'o')
    put(30, 9, 'o'); put(31, 9, 'o'); put(32, 9, 'o')
    put(33, 8, 'o')
    return ["".join(r) for r in g]

CROSSBOW = crossbow_grid()

# ---------------- Longbow: tall wood arc, nocked arrow ----------------
BOW_PAL = dict(COMMON, **{
    'B': (112, 76, 98, 255),    # cursed wood
    'b': (74, 48, 66, 255),     # wood shade / knots
    'H': (156, 108, 132, 255),  # wood highlight
    'T': (124, 232, 255, 255),  # soul string
    'A': (212, 222, 236, 255),  # spectral arrow shaft
    'S': (86, 224, 202, 255),   # soul crystal head
    'R': (150, 238, 255, 255),  # spectral fletching
    'G': (230, 180, 70, 255),   # grip wrap
    'g': (172, 120, 42, 255),   # grip wrap shade
    'v': (124, 232, 255, 80),   # faint soul glow
})
def longbow_grid():
    """Vertical longbow with straight string and nocked arrow pointing right."""
    W, H = 19, 27
    MID = 13
    g = [['.'] * W for _ in range(H)]
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = c
    # smooth arc offsets, tips row 0/26 at x5, belly x11 at middle
    offs = [5, 6, 7, 8, 9, 9, 10, 10, 11, 11, 11, 11, 11, 11]
    offs = offs + offs[-2::-1]
    for y, off in enumerate(offs):
        tip = y in (0, H - 1)
        put(off, y, 'o')
        put(off + 1, y, 'B' if tip else 'H')
        if not tip:
            put(off + 2, y, 'B')
        put(off + (2 if tip else 3), y, 'o')
    # extra outline caps at tips
    put(4, 0, 'o'); put(4, H - 1, 'o')
    # knots in the cursed wood
    for y in (5, 8, 18, 21):
        put(offs[y] + 2, y, 'b')
    # gold grip wrap over the belly
    for y in range(11, 16):
        put(offs[y] + 1, y, 'G'); put(offs[y] + 2, y, 'g')
    # string: straight, tied at tips
    for y in range(1, H - 1):
        put(4, y, 'T')
    # arrow at centre: fletch, shaft, steel head past the bow
    put(1, MID - 1, 'R'); put(2, MID - 1, 'R')
    put(1, MID + 1, 'R'); put(2, MID + 1, 'R')
    for x in range(1, 4):
        put(x, MID, 'R')
    for x in range(4, 15):
        put(x, MID, 'A')
    put(15, MID, 'S'); put(16, MID, 'S'); put(17, MID, 'S')
    put(15, MID - 1, 'o'); put(16, MID - 1, 'o')
    put(15, MID + 1, 'o'); put(16, MID + 1, 'o')
    put(17, MID - 1, 'o'); put(17, MID + 1, 'o'); put(18, MID, 'o')
    # outline the arrow shaft/fletch
    for x in range(0, 15):
        for dy in (-1, 1):
            if g[MID + dy][x] == '.':
                put(x, MID + dy, 'o')
    put(0, MID, 'o')
    for x, y in [(0, MID - 2), (1, MID - 2), (2, MID - 2), (0, MID + 2), (1, MID + 2), (2, MID + 2), (3, MID - 1), (3, MID + 1)]:
        if g[y][x] == '.':
            put(x, y, 'o')
    return ["".join(r) for r in g]

LONGBOW = longbow_grid()

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

# ---------------- projectiles: spectral arrow (longbow) + soul bolt (crossbow) ----------------
ARROW_PROJ = [
    "oRRo........oo..",
    "oRAAAAAAAAAASSSo",
    "oRRo........oo..",
]
BOLT_PROJ = [
    ".ooooooooo..",
    "oAAAAAAACCCo",
    ".ooooooooo..",
]

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

sprites = [
    ("carp_diem.png", FISH, FISH_PAL),
    ("the_underkey.png", KEY, KEY_PAL),
    ("mimic_bite.png", MIMIC, MIMIC_PAL),
    ("boomerang.png", BOOMERANG, BOOM_PAL),
    ("crossbow.png", add_glow(CROSSBOW, {'T', 'C'}), XBOW_PAL),
    ("longbow.png", add_glow(LONGBOW, {'T', 'S', 'R'}), BOW_PAL),
    ("projectile_arrow.png", add_glow(ARROW_PROJ, {'S', 'R'}), BOW_PAL),
    ("projectile_bolt.png", add_glow(BOLT_PROJ, {'C'}), XBOW_PAL),
]
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
prev.save(os.path.join(SP, "weapons_preview.png"))
print("done", [(n, i.size) for (n, _, _), i in zip(sprites, imgs)])
