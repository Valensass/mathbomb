"""Generate the BOMB MATH launcher icon (no external assets).

Run with a Pillow-enabled Python:
  python tool/generate_icon.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
BG_TOP = (10, 20, 28)
BG_BOTTOM = (3, 6, 9)
AMBER = (255, 196, 61)
AMBER_DARK = (196, 128, 16)
AMBER_LIGHT = (255, 224, 140)
COPPER = (183, 139, 92)
COPPER_LIGHT = (232, 192, 142)


def bezier(p0, p1, p2, steps=80):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t**2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t**2 * p2[1]
        pts.append((x, y))
    return pts


def main():
    img = Image.new("RGBA", (SIZE, SIZE), BG_BOTTOM + (255,))
    draw = ImageDraw.Draw(img, "RGBA")

    # Vertical background gradient.
    for y in range(SIZE):
        t = y / (SIZE - 1)
        color = tuple(
            int(BG_TOP[i] * (1 - t) + BG_BOTTOM[i] * t) for i in range(3)
        )
        draw.line([(0, y), (SIZE, y)], fill=color + (255,))

    # Faint technical grid.
    grid = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    for i in range(0, SIZE + 1, 64):
        gd.line([(i, 0), (i, SIZE)], fill=(57, 232, 210, 12), width=2)
        gd.line([(0, i), (SIZE, i)], fill=(57, 232, 210, 12), width=2)
    img = Image.alpha_composite(img, grid)
    draw = ImageDraw.Draw(img, "RGBA")

    # Glow behind the bomb.
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r in range(430, 120, -10):
        a = int(2 + 10 * (1 - (r - 120) / 310))
        gd.ellipse(
            [512 - r, 600 - r, 512 + r, 600 + r],
            fill=(255, 196, 61, a),
        )
    glow = glow.filter(ImageFilter.GaussianBlur(28))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img, "RGBA")

    cx, cy, R = 512, 590, 270

    # Fuse (draw first so it sits behind the body).
    pts = bezier((660, 380), (760, 250), (840, 190))
    draw.line(pts, fill=(40, 28, 16, 255), width=40, joint="curve")
    draw.line(pts, fill=COPPER, width=26, joint="curve")
    draw.line([(p[0] - 4, p[1] - 6) for p in pts], fill=COPPER_LIGHT, width=7)

    # Spark burst at the fuse tip.
    sx, sy = 840, 188
    for angle in range(0, 360, 30):
        a = math.radians(angle)
        length = 58 if angle % 60 == 0 else 34
        draw.line(
            [
                (sx + math.cos(a) * 16, sy + math.sin(a) * 16),
                (sx + math.cos(a) * length, sy + math.sin(a) * length),
            ],
            fill=(255, 240, 200, 230),
            width=8,
        )
    draw.ellipse([sx - 26, sy - 26, sx + 26, sy + 26], fill=(255, 248, 220, 255))
    draw.ellipse([sx - 16, sy - 16, sx + 16, sy + 16], fill=AMBER + (255,))

    # Bomb body: dark rim, amber body, shaded bottom.
    draw.ellipse([cx - R - 18, cy - R - 18, cx + R + 18, cy + R + 18],
                 fill=(20, 24, 28, 255))
    draw.ellipse([cx - R - 8, cy - R - 8, cx + R + 8, cy + R + 8],
                 fill=AMBER_DARK + (255,))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], fill=AMBER + (255,))

    # Bottom shading crescent.
    shade = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.ellipse([cx - R, cy - R + 40, cx + R, cy + R + 90],
               fill=(150, 90, 0, 90))
    mask = Image.new("L", (SIZE, SIZE), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([cx - R, cy - R, cx + R, cy + R], fill=255)
    img = Image.composite(
        Image.alpha_composite(img, shade),
        img,
        mask.filter(ImageFilter.GaussianBlur(30)),
    )
    draw = ImageDraw.Draw(img, "RGBA")

    # Top-left highlight (soft, low alpha).
    hi = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hi)
    hd.ellipse([cx - 205, cy - 215, cx + 30, cy - 15],
               fill=(255, 255, 255, 62))
    hi = hi.filter(ImageFilter.GaussianBlur(34))
    img = Image.alpha_composite(img, hi)
    draw = ImageDraw.Draw(img, "RGBA")

    # Detonator cap: dark body with hazard chevrons.
    cap_top, cap_bottom = cy - R - 46, cy - R + 34
    draw.rounded_rectangle(
        [cx - 104, cap_top, cx + 104, cap_bottom],
        radius=26,
        fill=(16, 24, 31, 255),
        outline=(6, 9, 12, 255),
        width=6,
    )
    for i in range(-78, 78, 26):
        draw.polygon(
            [
                (cx + i, cap_bottom - 8),
                (cx + i + 11, cap_bottom - 8),
                (cx + i + 34, cap_top + 10),
                (cx + i + 23, cap_top + 10),
            ],
            fill=(255, 196, 61, 235),
        )
    draw.rounded_rectangle(
        [cx - 104, cap_top, cx + 104, cap_bottom],
        radius=26,
        outline=(255, 196, 61, 150),
        width=3,
    )

    # Small dark "screen" with a minus sign, hinting at the game.
    draw.rounded_rectangle(
        [cx - 120, cy - 42, cx + 120, cy + 56],
        radius=18,
        fill=(4, 18, 13, 255),
        outline=(255, 196, 61, 160),
        width=4,
    )
    draw.rounded_rectangle(
        [cx - 44, cy + 2, cx + 44, cy + 16],
        radius=7,
        fill=(255, 196, 61, 235),
    )

    os.makedirs("assets/icon", exist_ok=True)
    img.save("assets/icon/app_icon.png")

    res = "android/app/src/main/res"
    sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for folder, px in sizes.items():
        out = os.path.join(res, f"mipmap-{folder}", "ic_launcher.png")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        img.resize((px, px), Image.LANCZOS).save(out, optimize=True)
        print(f"  {out}  {px}x{px}")
    print("Wrote assets/icon/app_icon.png (1024x1024)")


if __name__ == "__main__":
    main()
