#!/usr/bin/env python3
"""Generate the clasper app icon (icon-1024.png + AppIcon.icns).

A white pixel-art arcade-style ghost (a nod to Ghostty) on a black
squircle tile. The tall rectangular eye gaps and chunky 2x2 side arms
borrow from the Claude Code startup mascot. The pixel grid below is our
own drawing.

Usage:  uv run --with pillow python assets/make_icon.py
"""
import math
import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent

GHOST = [
    "......######......",
    "....##########....",
    "...############...",
    "..##############..",
    "..##############..",
    "..###..####..###..",  # eye gaps: tall 2x3 rectangles, like the mascot's
    "..###..####..###..",
    "..###..####..###..",
    "##################",  # 2x2 arms
    "##################",
    "..##############..",
    "..##############..",
    "..##.###..###.##..",  # wavy 4-point skirt
    "..#...##..##...#..",
]

SIZE = 1024
TILE = 824
N = 5.0            # superellipse exponent for the squircle
TOP = (0x0D, 0x0D, 0x0D)
BOTTOM = (0x00, 0x00, 0x00)
WHITE = (0xF5, 0xF5, 0xF5, 255)
PX = 30            # ghost pixel size (18 cols -> 540px, ~66% of tile)
LIFT = 10          # optical centring: nudge the ghost up a hair
SS = 4             # supersampling for smooth tile edges


def squircle_mask(size, cx, cy, half, n, offset=(0, 0)):
    big = size * SS
    pts = []
    for i in range(1440):
        t = 2 * math.pi * i / 1440
        c, s = math.cos(t), math.sin(t)
        x = half * math.copysign(abs(c) ** (2 / n), c)
        y = half * math.copysign(abs(s) ** (2 / n), s)
        pts.append(((cx + x + offset[0]) * SS, (cy + y + offset[1]) * SS))
    img = Image.new("L", (big, big), 0)
    ImageDraw.Draw(img).polygon(pts, fill=255)
    return img.resize((size, size), Image.LANCZOS)


def grid():
    rows = [r.ljust(18, ".")[:18] for r in GHOST]
    return [[ch == "#" for ch in r] for r in rows]


def build():
    c = SIZE / 2
    half = TILE / 2
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # soft drop shadow
    shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow.putalpha(squircle_mask(SIZE, c, c, half, N, (0, 12)).point(lambda a: a * 0.5))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(16)))

    # near-black tile with a very subtle vertical gradient
    grad = Image.new("RGBA", (SIZE, SIZE))
    gd = ImageDraw.Draw(grad)
    m = c - half
    for y in range(SIZE):
        t = min(max((y - m) / TILE, 0), 1)
        col = tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM))
        gd.line([(0, y), (SIZE, y)], fill=col + (255,))
    tile = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    tile.paste(grad, (0, 0), squircle_mask(SIZE, c, c, half, N))
    canvas.alpha_composite(tile)

    # ghost: crisp square pixels
    g = grid()
    gw, gh = len(g[0]), len(g)
    ox = round(c - gw * PX / 2)
    oy = round(c - gh * PX / 2) - LIFT
    d = ImageDraw.Draw(canvas)
    for y, row in enumerate(g):
        for x, on in enumerate(row):
            if on:
                d.rectangle((ox + x * PX, oy + y * PX,
                             ox + (x + 1) * PX - 1, oy + (y + 1) * PX - 1), fill=WHITE)
    return canvas, g


def main():
    img, g = build()
    out = HERE / "icon-1024.png"
    img.save(out)
    print("\n".join("".join("#" if v else "." for v in r) for r in g))

    tmp = Path(tempfile.mkdtemp())
    iconset = tmp / "AppIcon.iconset"
    iconset.mkdir()
    for s in (16, 32, 128, 256, 512):
        img.resize((s, s), Image.LANCZOS).save(iconset / f"icon_{s}x{s}.png")
        img.resize((s * 2, s * 2), Image.LANCZOS).save(iconset / f"icon_{s}x{s}@2x.png")
    subprocess.run(["iconutil", "-c", "icns", str(iconset),
                    "-o", str(HERE / "AppIcon.icns")], check=True)
    shutil.rmtree(tmp)
    print("wrote", out, "and", HERE / "AppIcon.icns")


if __name__ == "__main__":
    main()
