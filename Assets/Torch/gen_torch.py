"""Generate torch.png: a 3-frame 32x32 wall-torch sprite sheet (96x32).

Pixel-art style matching the dungeon tiles: wooden handle in a metal sconce,
with a flame that sways across the frames so the sprite animates. Transparent
background; Godot's nearest filter keeps it crisp.

Run:  python gen_torch.py
"""
from PIL import Image, ImageDraw

FRAME = 32
FRAMES = 3

# Palette
OUTLINE = (43, 27, 16, 255)
WOOD = (122, 79, 40, 255)
WOOD_HI = (155, 106, 58, 255)
METAL = (96, 100, 112, 255)
METAL_HI = (138, 143, 152, 255)
FLAME_RIM = (214, 74, 34, 255)     # red-orange rim
FLAME_MID = (240, 143, 42, 255)    # orange
FLAME_CORE = (255, 210, 60, 255)   # yellow
FLAME_HOT = (255, 244, 178, 255)   # near-white heart
EMBER = (255, 190, 90, 255)


def ellipse(d, cx, cy, rx, ry, color):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=color)


def draw_frame(d, sway, lift):
    """One 32x32 torch. `sway` shifts the flame tip x, `lift` its height."""
    cx = 15.5

    # --- Handle: wooden stick with an outline and a lit left edge -------------
    d.rectangle((13, 17, 18, 28), fill=OUTLINE)
    d.rectangle((14, 18, 17, 27), fill=WOOD)
    d.rectangle((14, 18, 14, 27), fill=WOOD_HI)

    # --- Sconce cup: metal band holding the flame ----------------------------
    d.rectangle((11, 14, 20, 18), fill=OUTLINE)
    d.rectangle((12, 15, 19, 17), fill=METAL)
    d.rectangle((12, 15, 19, 15), fill=METAL_HI)

    # --- Flame: layered teardrop, swaying per frame --------------------------
    tip_x = cx + sway
    base_y = 14.0
    top_y = 5.0 - lift
    # rim (outermost)
    ellipse(d, cx, base_y - 3.0, 5.0, 5.5, FLAME_RIM)
    ellipse(d, (cx + tip_x) / 2.0, (base_y + top_y) / 2.0, 3.6, 4.6, FLAME_RIM)
    ellipse(d, tip_x, top_y + 2.0, 1.8, 2.4, FLAME_RIM)
    # mid
    ellipse(d, cx, base_y - 3.0, 3.8, 4.4, FLAME_MID)
    ellipse(d, (cx + tip_x) / 2.0, (base_y + top_y) / 2.0 + 0.5, 2.6, 3.4, FLAME_MID)
    ellipse(d, tip_x, top_y + 3.0, 1.1, 1.6, FLAME_MID)
    # core
    ellipse(d, cx, base_y - 3.5, 2.4, 3.0, FLAME_CORE)
    ellipse(d, (cx + tip_x) / 2.0, (base_y + top_y) / 2.0 + 1.5, 1.5, 2.0, FLAME_CORE)
    # hottest heart
    ellipse(d, cx, base_y - 3.0, 1.2, 1.6, FLAME_HOT)
    # a drifting ember pixel
    d.point((int(tip_x + sway), int(top_y - 1)), fill=EMBER)


def main():
    sheet = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
    # (sway, lift) per frame: lean left, upright/tall, lean right
    for i, (sway, lift) in enumerate([(-1.5, 0.0), (0.0, 1.0), (1.5, -0.5)]):
        frame = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
        draw_frame(ImageDraw.Draw(frame), sway, lift)
        sheet.paste(frame, (i * FRAME, 0))
    sheet.save("torch.png")
    print("wrote torch.png (%dx%d)" % sheet.size)


if __name__ == "__main__":
    main()
