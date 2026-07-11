#!/usr/bin/env python3
# Regenerate the 3D navigation-arrow SPRITE SHEET -> EasyMountFarmer/Media/arrow.tga
#
# It's a "crazy-taxi" arrow: one properly-rendered 3D arrow per rotation (fixed
# angled camera) so the perspective holds in every direction (incl. pointing back
# toward you). Grayscale, so Navigation/Arrow.lua tints it by distance. 8x8 = 64
# frames in a 1024x1024 pow2 sheet, frame 0 = pointing away (up on screen).
#
# COLS/ROWS/FRAMES here MUST match the constants in Navigation/Arrow.lua.
# Requires Pillow (`pip install pillow`). Run: python3 scripts/gen-arrow.py

import os, math
from PIL import Image, ImageDraw

SHEET = 1024
COLS = ROWS = 8
FRAMES = COLS * ROWS
CELL = SHEET // COLS
SS = 3
CN = CELL * SS
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "EasyMountFarmer", "Media")
os.makedirs(OUT, exist_ok=True)

# Chunky arrow, short shaft (ground plane, +y = forward), recentred around origin.
_RAW = [(0.00, 1.00), (0.64, 0.16), (0.25, 0.16), (0.25, -0.40),
        (-0.25, -0.40), (-0.25, 0.16), (-0.64, 0.16)]
_CY = (max(p[1] for p in _RAW) + min(p[1] for p in _RAW)) / 2
OUTLINE = [(x, y - _CY) for (x, y) in _RAW]
THICK = 0.22                                    # extrusion height (z)

PHI = math.radians(34)                          # low camera => strong "forward" perspective
SINP, COSP = math.sin(PHI), math.cos(PHI)
_L = (-0.35, 0.42, 0.84)
_ln = math.sqrt(sum(c * c for c in _L))
LIGHT = tuple(c / _ln for c in _L)

ARROW_SCALE = 0.46 * CN
CX, CY = CN / 2, CN / 2

def rot(x, y, a):
    ca, sa = math.cos(a), math.sin(a)
    return (x * ca - y * sa, x * sa + y * ca)

def project(x, y, z):
    return (CX + x * ARROW_SCALE, CY - (y * SINP + z * COSP) * ARROW_SCALE)

def render_frame(angle):
    img = Image.new("RGBA", (CN, CN), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    pts = [rot(x, y, angle) for (x, y) in OUTLINE]
    n = len(pts)
    top_s = [project(x, y, THICK) for (x, y) in pts]
    bot_s = [project(x, y, 0.0) for (x, y) in pts]

    walls = []
    for i in range(n):
        j = (i + 1) % n
        ex, ey = pts[j][0] - pts[i][0], pts[j][1] - pts[i][1]
        nx, ny = ey, -ex
        ln = math.hypot(nx, ny) or 1
        nx, ny = nx / ln, ny / ln
        mx, my = (pts[i][0] + pts[j][0]) / 2, (pts[i][1] + pts[j][1]) / 2
        if nx * mx + ny * my < 0:
            nx, ny = -nx, -ny
        b = 0.22 + 0.5 * max(0.0, nx * LIGHT[0] + ny * LIGHT[1])
        walls.append((my, [top_s[i], top_s[j], bot_s[j], bot_s[i]], b))

    walls.sort(key=lambda w: -w[0])                      # far (large y) first
    for _, quad, b in walls:
        v = int(255 * b)
        dr.polygon(quad, fill=(v, v, v, 255))

    v = int(255 * min(1.0, 0.60 + 0.4 * LIGHT[2]))       # top face: bright, constant
    dr.polygon(top_s, fill=(v, v, v, 255))
    dr.line(top_s + [top_s[0]], fill=(int(v * 0.42),) * 3 + (255,),
            width=max(1, int(CN * 0.012)))               # dark rim
    return img.resize((CELL, CELL), Image.LANCZOS)

sheet = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
for f in range(FRAMES):
    cell = render_frame((f / FRAMES) * 2 * math.pi)      # CCW with increasing index
    sheet.alpha_composite(cell, ((f % COLS) * CELL, (f // COLS) * CELL))
sheet.save(os.path.join(OUT, "arrow.tga"))
print("wrote %s (%dx%d, %d frames)" % (os.path.join(OUT, "arrow.tga"), SHEET, SHEET, FRAMES))
