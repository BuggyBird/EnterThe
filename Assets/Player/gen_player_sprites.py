# -*- coding: utf-8 -*-
"""Generate 32x32 pixel player sprite sheets for Underhalls (dark fantasy dungeon).
Character: hooded gravekeeper with glowing cyan eyes (matches soul_pistol theme).
Outputs per-animation horizontal strips + a scaled preview sheet.
"""
from PIL import Image, ImageDraw
import math, os

OUT = r"C:\Users\siebe\Documents\claude-test\Assets\Player"
PREVIEW = r"C:\Users\siebe\AppData\Local\Temp\claude\C--Users-siebe-Documents-claude-test\c5068587-89ad-4eab-b9fd-a8437c533f13\scratchpad\preview.png"
os.makedirs(OUT, exist_ok=True)

PAL = {
    'o': (18, 14, 26, 255),    # outline near-black
    'M': (61, 52, 82, 255),    # cloak mid
    'L': (88, 76, 116, 255),   # cloak light
    'D': (42, 36, 56, 255),    # cloak dark
    'S': (10, 8, 16, 255),     # hood inner shadow
    'E': (124, 232, 255, 255), # eye glow cyan
    'e': (58, 120, 140, 255),  # eye dim
    'W': (235, 252, 255, 255), # eye flash white
    'F': (184, 169, 156, 255), # pale skin
    'A': (74, 59, 46, 255),    # leather armor
    'a': (52, 41, 32, 255),    # leather dark
    'B': (92, 71, 50, 255),    # belt
    'b': (201, 168, 106, 255), # buckle gold
    'G': (30, 24, 18, 255),    # boot dark
    'g': (61, 48, 36, 255),    # boot mid
    'w': (124, 232, 255, 180), # wisp translucent
    'v': (124, 232, 255, 90),  # wisp faint
    '.': (0, 0, 0, 0),
}

BASE = [
    "................................",
    "................................",
    "................................",
    "..............oo................",
    ".............oMMo...............",
    "............oMLMMo..............",
    "...........oMLLMMMo.............",
    "..........oMLLMMMMMo............",
    ".........oMLSSSSSSMMo...........",
    ".........oLSSSSSSSSMo...........",
    ".........oLSESSSSESMo...........",
    ".........oLSSSSSSSSMo...........",
    ".........oMLSSSSSSMMo...........",
    "..........oMLSSSSMMo............",
    "..........ooMMbbMMoo............",
    ".........oMMLMMMMMMMo...........",
    "........oMLLMMaAAaMMMo..........",
    "........oMLMMaAAAaMMMo..........",
    "........oMLMMaAAAaMMMo..........",
    "........oMLBBBBbBBBBMo..........",
    "........oMLMMMaAaMMMMo..........",
    "........oMLMMMMaMMMMMo..........",
    "........oMLMMMMMMMMMMo..........",
    ".......oMLLMMMMMMMMMDMo.........",
    ".......oMLMMMMMMMMMMDMo.........",
    ".......oMLMMDMMMMDMMDMo.........",
    ".......ooooooooooooooo..........",
    "..........oGGo..oGGo............",
    "..........oGgGooGgGo............",
    "...........oo....oo.............",
    "................................",
    "................................",
]

def grid(rows):
    g = [list(r) for r in rows]
    assert len(g) == 32 and all(len(r) == 32 for r in g), [len(r) for r in g]
    return g

def copy(g):
    return [row[:] for row in g]

def blank():
    return [['.'] * 32 for _ in range(32)]

def shift(g, dx, dy):
    ng = blank()
    for y in range(32):
        for x in range(32):
            c = g[y][x]
            if c == '.':
                continue
            nx, ny = x + dx, y + dy
            if 0 <= nx < 32 and 0 <= ny < 32:
                ng[ny][nx] = c
    return ng

def squash(g, rows_to_remove):
    """Remove given row indices, shifting everything above down (feet stay planted)."""
    ng = copy(g)
    for y in sorted(rows_to_remove):
        for yy in range(y, 0, -1):
            ng[yy] = ng[yy - 1][:]
        ng[0] = ['.'] * 32
    return ng

def swap(g, mapping):
    ng = copy(g)
    for y in range(32):
        for x in range(32):
            if ng[y][x] in mapping:
                ng[y][x] = mapping[ng[y][x]]
    return ng

def put(g, x, y, c):
    if 0 <= x < 32 and 0 <= y < 32:
        g[y][x] = c

def render(g):
    img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    px = img.load()
    for y in range(32):
        for x in range(32):
            px[x, y] = PAL[g[y][x]]
    return img

# ---------------- IDLE (6 frames): breathing bob + blink + cloak sway ----------------
def idle_frames():
    frames = []
    base = grid(BASE)
    bob = squash(base, [22])  # 1px squash, feet planted
    f2 = copy(bob)
    # cloak hem sway on bob frames
    put(f2, 12, 25, 'M'); put(f2, 18, 25, 'D')
    blink = swap(base, {'E': 'S'})
    for f in [base, base, f2, f2, base, blink]:
        frames.append(copy(f))
    return frames

# ---------------- SHOOT (5 frames): raise -> recoil flash -> settle -> lower ----------------
def draw_arm(g, extended, hand_y=16, recoil=False):
    """Right-pointing sleeve arm from the shoulder, 2px thick."""
    if extended:
        for x in range(21, 26):
            put(g, x, hand_y - 1, 'o')
            put(g, x, hand_y, 'L' if hand_y % 2 else 'M')
            put(g, x, hand_y + 1, 'M')
            put(g, x, hand_y + 2, 'o')
        # hand: 2x2 pale fist
        put(g, 26, hand_y, 'F'); put(g, 26, hand_y + 1, 'F')
        put(g, 27, hand_y, 'F'); put(g, 27, hand_y + 1, 'F')
        put(g, 26, hand_y - 1, 'o'); put(g, 27, hand_y - 1, 'o')
        put(g, 26, hand_y + 2, 'o'); put(g, 27, hand_y + 2, 'o')
        put(g, 28, hand_y, 'o'); put(g, 28, hand_y + 1, 'o')
    else:
        # half raised, diagonal 2px sleeve
        pts = [(21, 18), (22, 17), (23, 16), (24, 15)]
        for x, y in pts:
            put(g, x, y, 'M'); put(g, x, y + 1, 'M')
            put(g, x, y - 1, 'o'); put(g, x, y + 2, 'o')
        put(g, 25, 14, 'F'); put(g, 25, 15, 'F')
        put(g, 25, 13, 'o'); put(g, 26, 14, 'o'); put(g, 26, 15, 'o'); put(g, 25, 16, 'o')

def shoot_frames():
    base = grid(BASE)
    frames = []
    # f0 raise
    f0 = copy(base)
    draw_arm(f0, extended=False)
    frames.append(f0)
    # f1 recoil: body kicked 1px left, eyes flash wide, hood flap
    f1 = shift(base, -1, 0)
    draw_arm(f1, extended=True, recoil=True)
    f1 = swap(f1, {'E': 'W'})
    # widen eyes 1px
    put(f1, 11, 10, 'W'); put(f1, 16, 10, 'W')
    frames.append(f1)
    # f2 settle, arm extended, eyes bright
    f2 = copy(base)
    draw_arm(f2, extended=True)
    frames.append(f2)
    # f3 arm retract
    f3 = copy(base)
    draw_arm(f3, extended=False)
    frames.append(f3)
    # f4 back to idle
    frames.append(copy(base))
    return frames

# ---------------- ROLL (8 frames): crouch -> spinning cloak ball -> recover ----------------
def crouch(eyes='E'):
    g = squash(grid(BASE), [5, 7, 21, 22])  # 4px squash
    if eyes != 'E':
        g = swap(g, {'E': eyes})
    return g

def ball(theta, cy):
    """Cloak ball with rotating swirl highlight + hood tip accent."""
    g = blank()
    cx = 16.0
    r = 8.0
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r - 1:
                # base fill with lower-right shading
                ang = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
                g[y][x] = 'D' if (ang > 0.4 and ang < 2.3 and d > r * 0.45) else 'M'
            elif d <= r:
                g[y][x] = 'o'
    # two spiral swirl arms of light cloak
    for arm in (0.0, math.pi):
        for t in [i * 0.16 for i in range(16)]:
            rr = 1.5 + t * 3.4
            if rr > r - 1.6:
                break
            a = theta + arm + t * 1.5
            x = int(cx + rr * math.cos(a))
            y = int(cy + rr * math.sin(a))
            put(g, x, y, 'L')
    # hood tip accent riding the rim
    a = theta
    x = int(cx + (r - 1.6) * math.cos(a)); y = int(cy + (r - 1.6) * math.sin(a))
    put(g, x, y, 'L')
    # boot flash opposite the hood tip
    x = int(cx + (r - 2.2) * math.cos(a + math.pi)); y = int(cy + (r - 2.2) * math.sin(a + math.pi))
    put(g, x, y, 'G')
    return g

def roll_frames():
    frames = [crouch()]
    centers = [20.5, 19.5, 19.0, 19.0, 19.5, 20.5]
    for i, cy in enumerate(centers):
        b = ball(theta=i * (math.tau / 6) - math.pi / 2, cy=cy)
        if i < 2:
            # eye glow still visible as the face tucks under
            ey = int(cy) + (2 if i == 0 else 4)
            put(b, 14, ey, 'E'); put(b, 18, ey, 'E')
        frames.append(b)
    frames.append(crouch())
    return frames

# ---------------- DEATH (8 frames) ----------------
FALL = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "..................oooo..........",
    ".................oMMMMo.........",
    "................oMLMMMMo........",
    "...............oMLSSSSMo........",
    "..............oMSSeSeSMo........",
    ".............oMLSSSSSMo.........",
    "............oMLMMSFSMo..........",
    "..........ooMLMMaAaMo...........",
    ".......ooMMLMMaAAAaMo...........",
    ".....ooMMLMMMBBbBBMo............",
    "....oGgMMLMMMMaAaMo.............",
    "...oGGgMMLMMMMMMMo..............",
    "....ooooooooooooo...............",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]

LYING = [
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "....................oooo........",
    "...................oMMMMo.......",
    "..........ooooooooMMLSSSMo......",
    ".......oooMMMMMMMMMLSeeSMo......",
    ".....ooGgMAAMMMMMMMMLSSSMo......",
    "....oGGgMABbAMMMMMMMMMMMo.......",
    ".....ooooooooooooooooooo........",
    "................................",
    "................................",
    "................................",
]

def death_frames():
    base = grid(BASE)
    frames = []
    # f0 hit flash: whole body flashes pale, eyes white
    f0 = swap(base, {'M': 'L', 'D': 'M', 'S': 'D', 'E': 'W'})
    f0 = shift(f0, -1, 0)
    frames.append(f0)
    # f1 stagger: lean back, eyes dim
    f1 = shift(swap(base, {'E': 'e'}), -1, 0)
    # tilt hood: nudge top rows further left
    top = blank()
    for y in range(0, 14):
        top[y] = f1[y][:]
        f1[y] = ['.'] * 32
    top = shift(top, -1, 1)
    for y in range(32):
        for x in range(32):
            if top[y][x] != '.':
                f1[y][x] = top[y][x]
    frames.append(f1)
    # f2 knees: heavy squash, dim eyes
    f2 = squash(swap(base, {'E': 'e'}), [5, 6, 16, 18, 20, 22])
    frames.append(f2)
    # f3 falling forward
    frames.append(grid(FALL))
    # f4 lying, eyes dim
    frames.append(grid(LYING))
    # f5 lying, eyes out
    f5 = swap(grid(LYING), {'e': 'S'})
    frames.append(f5)
    # f6 soul wisp rising
    f6 = copy(f5)
    for x, y, c in [(21, 18, 'w'), (22, 17, 'w'), (21, 16, 'w'), (22, 19, 'v'), (20, 15, 'v'), (22, 14, 'v')]:
        put(f6, x, y, c)
    frames.append(f6)
    # f7 wisp higher + fading heap
    f7 = swap(f5, {'M': 'D', 'L': 'M'})
    for x, y, c in [(21, 11, 'w'), (22, 10, 'v'), (21, 8, 'v'), (20, 12, 'v')]:
        put(f7, x, y, c)
    frames.append(f7)
    return frames

# ---------------- output ----------------
def save_strip(name, frames):
    strip = Image.new("RGBA", (32 * len(frames), 32), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(render(f), (i * 32, 0))
    strip.save(os.path.join(OUT, name))
    return strip

anims = {
    "player_idle.png": idle_frames(),
    "player_shoot.png": shoot_frames(),
    "player_roll.png": roll_frames(),
    "player_death.png": death_frames(),
}

strips = {name: save_strip(name, frames) for name, frames in anims.items()}

# preview: all strips stacked, scaled 6x on dungeon-dark bg
SCALE = 6
pad = 12
w = max(s.width for s in strips.values()) * SCALE + pad * 2
h = sum(s.height * SCALE + pad for s in strips.values()) + pad
prev = Image.new("RGBA", (w, h), (24, 20, 32, 255))
d = ImageDraw.Draw(prev)
y = pad
for name, s in strips.items():
    big = s.resize((s.width * SCALE, s.height * SCALE), Image.NEAREST)
    prev.paste(big, (pad, y), big)
    y += big.height + pad
prev.save(PREVIEW)
print("done", {n: (s.width, s.height) for n, s in strips.items()})
