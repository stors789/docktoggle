#!/usr/bin/env python3
"""Generate DockToggle app icon (Dock rectangle + downward arrow)"""

import math
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent / "Resources"
ICONSET = OUT / "DockToggle.iconset"

SIZES = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}

BLUE_TOP = (0x5B, 0x8E, 0xFA)
BLUE_BOT = (0x3B, 0x5D, 0xE7)
WHITE = (255, 255, 255)


def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    S = size

    # ---------- rounded rect (Dock shape) ----------
    pad = S * 0.08
    rx = pad
    ry = S * 0.28
    rw = S - pad * 2
    rh = S * 0.44
    cr = rh * 0.35

    img_rect = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_rect = ImageDraw.Draw(img_rect)

    for i in range(int(rh)):
        t = i / (rh - 1) if rh > 1 else 0
        color = lerp_color(BLUE_TOP, BLUE_BOT, t)
        y = ry + i
        x_l = rx
        x_r = rx + rw
        if i < cr:
            dy = cr - i
            inset = cr - math.sqrt(max(0, cr * cr - dy * dy))
            x_l = rx + inset
            x_r = rx + rw - inset
        elif i > rh - cr:
            dy = i - (rh - cr)
            inset = cr - math.sqrt(max(0, cr * cr - dy * dy))
            x_l = rx + inset
            x_r = rx + rw - inset
        if x_l < x_r:
            draw_rect.rectangle([x_l, y, x_r, y + 1], fill=color)

    # ---------- downward chevron ----------
    img_arrow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    draw_arrow = ImageDraw.Draw(img_arrow)

    cx = S / 2
    aw = S * 0.18
    ah = S * 0.12
    top_y = ry + rh / 2 - ah * 0.3

    left_top = (cx - aw, top_y)
    right_top = (cx + aw, top_y)
    tip = (cx, top_y + ah)

    lw = max(2, S * 0.06)
    draw_arrow.line([left_top, tip], fill=WHITE, width=int(lw))
    draw_arrow.line([right_top, tip], fill=WHITE, width=int(lw))

    # ---------- composite ----------
    img.paste(img_rect, (0, 0), img_rect)
    img.paste(img_arrow, (0, 0), img_arrow)

    return img


def main():
    ICONSET.mkdir(parents=True, exist_ok=True)
    for name, size in SIZES.items():
        img = draw_icon(size)
        path = ICONSET / name
        img.save(path)
        print(f"  {name} ({size}x{size})")

    print(f"\nIcons written to {ICONSET}")
    print("Next: run  iconutil -c icns DockToggle.iconset")


if __name__ == "__main__":
    main()
