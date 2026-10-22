"""
Creative icon concepts for 掌上新理工 (HarmonyOS).

Draws several original vector-style marks with Pillow and exports them as
transparent PNGs into docs/brand/concepts/. Nothing here is a copy of an
existing asset: every concept is composed from primitives (arcs, polygons,
gradients) so it stays reproducible and editable.

Usage:
    python tools/generate-icon-concepts.py
"""

from pathlib import Path
import math
import json
import hashlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'brand' / 'concepts'
OUT.mkdir(parents=True, exist_ok=True)

SS = 4  # supersampling factor for clean edges

INDIGO = (49, 94, 218)
CYAN = (18, 181, 201)
VIOLET = (123, 92, 230)
NIGHT = (8, 15, 34)
GOLD = (255, 196, 92)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def vertical_gradient(size, top, bottom):
    """Smooth vertical gradient image."""
    grad = Image.new('RGB', (1, size[1]))
    px = grad.load()
    for y in range(size[1]):
        px[0, y] = lerp(top, bottom, y / max(1, size[1] - 1))
    return grad.resize(size, Image.BILINEAR)


def radial_glow(size, center, radius, color, strength=1.0):
    """Additive radial light bloom as an RGBA layer."""
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    px = layer.load()
    cx, cy = center
    for y in range(size[1]):
        for x in range(size[0]):
            d = math.hypot(x - cx, y - cy) / radius
            if d >= 1.0:
                continue
            falloff = (1.0 - d) ** 2
            a = int(255 * falloff * strength)
            px[x, y] = (color[0], color[1], color[2], a)
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.08))


def grain(size, amount=6):
    """Very light noise so gradients do not band."""
    layer = Image.new('RGBA', size, (0, 0, 0, 0))
    px = layer.load()
    seed = 20261022
    for y in range(size[1]):
        for x in range(size[0]):
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF
            n = (seed >> 16) % (amount * 2 + 1) - amount
            if n:
                v = 128 + n
                px[x, y] = (v, v, v, 10)
    return layer


def save(img, name):
    path = OUT / name
    img.save(path, optimize=True)
    return {
        'name': name,
        'bytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'size': list(img.size),
    }


def canvas(size):
    """Night base with indigo/cyan/violet blooms, the app's ambient language."""
    base = vertical_gradient((size, size), (13, 22, 52), (5, 9, 22)).convert('RGBA')
    base.alpha_composite(radial_glow((size, size), (int(size * 0.18), int(size * 0.16)),
                                     size * 0.78, INDIGO, 0.55))
    base.alpha_composite(radial_glow((size, size), (int(size * 0.92), int(size * 0.30)),
                                     size * 0.62, CYAN, 0.38))
    base.alpha_composite(radial_glow((size, size), (int(size * 0.26), int(size * 0.94)),
                                     size * 0.66, VIOLET, 0.42))
    return base


# --- concept 1: "课表之环" ---------------------------------------------
# A schedule ring: the arc reads as a clock, the gap reads as an open slot,
# and the ascending dots are ten class periods climbing to the ninth and tenth.
def concept_schedule_ring(size):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    c = size / 2
    r = size * 0.31
    lw = int(size * 0.062)

    # track
    d.ellipse([c - r, c - r, c + r, c + r], outline=(255, 255, 255, 40), width=lw)
    # progress arc from top clockwise ~300 degrees
    d.arc([c - r, c - r, c + r, c + r], start=-96, end=196,
          fill=lerp(INDIGO, CYAN, 0.5) + (235,), width=lw)
    # rounded cap
    cap = (c + r * math.cos(math.radians(-96)), c + r * math.sin(math.radians(-96)))
    d.ellipse([cap[0] - lw / 2, cap[1] - lw / 2, cap[0] + lw / 2, cap[1] + lw / 2],
              fill=lerp(INDIGO, CYAN, 0.5) + (255,))

    # ten periods as a rising staircase of dots inside the ring
    for i in range(10):
        a = math.radians(-90 + i * 26)
        rr = r * 0.52
        x = c + rr * math.cos(a) * 1.25
        y = c + rr * math.sin(a)
        t = i / 9
        col = lerp(INDIGO, VIOLET, t) if i < 8 else lerp(VIOLET, GOLD, (i - 8) / 1)
        rad = size * (0.020 + 0.008 * t)
        d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=col + (255,))

    img.alpha_composite(grain((size, size), 5))
    return img


# --- concept 2: "天山书页" ----------------------------------------------
# An open book whose two pages sweep up into a Tian Shan ridge, with a
# schedule ribbon threading through the gutter.
def concept_tianshan_book(size):
    img = canvas(size)
    d = ImageDraw.Draw(img)

    cx, cy = size * 0.5, size * 0.60
    w = size * 0.62
    h = size * 0.30

    # ribbon of light through the gutter
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.polygon([(cx - size * 0.035, cy - h * 0.9), (cx + size * 0.035, cy - h * 0.9),
                (cx + size * 0.012, cy + h * 0.75), (cx - size * 0.012, cy + h * 0.75)],
               fill=lerp(CYAN, VIOLET, 0.5) + (200,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(size * 0.03)))

    # ridge: Tian Shan peaks above the book
    ridge = [(size * 0.16, cy - h * 0.10), (size * 0.34, cy - h * 1.15),
             (size * 0.46, cy - h * 0.52), (size * 0.58, cy - h * 1.32),
             (size * 0.72, cy - h * 0.62), (size * 0.86, cy - h * 0.18)]
    d.polygon(ridge, fill=(226, 238, 255, 235))
    # lit left face of the tallest peak
    d.polygon([(size * 0.16, cy - h * 0.10), (size * 0.34, cy - h * 1.15),
               (size * 0.40, cy - h * 0.30)], fill=(255, 255, 255, 235))

    # the open book: two pages as shallow wedges
    left = [(cx, cy - h * 0.18), (cx - w * 0.5, cy - h * 0.30),
            (cx - w * 0.5, cy + h * 0.34), (cx, cy + h * 0.30)]
    right = [(cx, cy - h * 0.18), (cx + w * 0.5, cy - h * 0.30),
             (cx + w * 0.5, cy + h * 0.34), (cx, cy + h * 0.30)]
    d.polygon(left, fill=(240, 246, 255, 240))
    d.polygon(right, fill=(198, 214, 244, 240))
    # page lines
    for i in range(4):
        y = cy - h * 0.02 + i * h * 0.16
        d.line([(cx - w * 0.44, y - h * 0.06), (cx - w * 0.06, y + h * 0.02)],
               fill=(70, 96, 160, 120), width=max(1, int(size * 0.006)))
        d.line([(cx + w * 0.06, y + h * 0.02), (cx + w * 0.44, y - h * 0.06)],
               fill=(70, 96, 160, 120), width=max(1, int(size * 0.006)))

    img.alpha_composite(grain((size, size), 5))
    return img


# --- concept 3: "掌心光感" ---------------------------------------------
# A translucent glass palm holding a glowing schedule chip: the app's
# liquid-glass direction rendered as a single mark.
def concept_glass_palm(size):
    img = canvas(size)
    d = ImageDraw.Draw(img)

    cx, cy = size * 0.5, size * 0.54
    # glass disc
    r = size * 0.30
    glass = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255, 46))
    gd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 120),
               width=max(2, int(size * 0.012)))
    # inner rim light
    gd.arc([cx - r * 0.86, cy - r * 0.86, cx + r * 0.86, cy + r * 0.86],
           start=200, end=340, fill=lerp(CYAN, VIOLET, 0.4) + (190,),
           width=max(2, int(size * 0.016)))
    img.alpha_composite(glass.filter(ImageFilter.GaussianBlur(size * 0.004)))

    # a "chip" card inside, glowing
    cw, ch = size * 0.30, size * 0.21
    chip = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(chip)
    cd.rounded_rectangle([cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2],
                         radius=size * 0.035, fill=(255, 255, 255, 235))
    cd.rounded_rectangle([cx - cw / 2, cy - ch / 2, cx + cw / 2, cy + ch / 2],
                         radius=size * 0.035, outline=lerp(INDIGO, VIOLET, 0.5) + (255,),
                         width=max(2, int(size * 0.010)))
    # chip content: a time bar and two lines
    cd.rounded_rectangle([cx - cw * 0.30, cy - ch * 0.20, cx + cw * 0.06, cy - ch * 0.02],
                         radius=size * 0.008, fill=lerp(INDIGO, CYAN, 0.35) + (255,))
    cd.rounded_rectangle([cx - cw * 0.30, cy + ch * 0.08, cx + cw * 0.30, cy + ch * 0.18],
                         radius=size * 0.006, fill=(150, 170, 210, 220))
    cd.rounded_rectangle([cx - cw * 0.30, cy + ch * 0.28, cx + cw * 0.12, cy + ch * 0.36],
                         radius=size * 0.005, fill=(180, 196, 226, 190))
    img.alpha_composite(chip)

    # palm: three upward fingers + thumb arc, drawn as a rounded cradle
    pd = ImageDraw.Draw(img)
    pw = max(3, int(size * 0.026))
    for i, (dx, top) in enumerate([(-0.17, -0.30), (-0.02, -0.38), (0.13, -0.30)]):
        x = cx + dx * size
        y0 = cy + top * size
        y1 = cy + size * 0.14
        pd.line([(x, y0), (x, y1)], fill=(255, 255, 255, 205), width=pw)
        pd.ellipse([x - pw / 2, y0 - pw / 2, x + pw / 2, y0 + pw / 2],
                   fill=(255, 255, 255, 225))
    # thumb
    pd.arc([cx - size * 0.30, cy - size * 0.06, cx + size * 0.16, cy + size * 0.34],
           start=120, end=250, fill=(255, 255, 255, 200), width=pw)

    img.alpha_composite(grain((size, size), 5))
    return img


# --- concept 4: "灵动胶囊" ----------------------------------------------
# A dynamic-island style pill with a live countdown, echoing the live view.
def concept_dynamic_island(size):
    img = canvas(size)
    d = ImageDraw.Draw(img)

    cx, cy = size * 0.5, size * 0.5
    pw, ph = size * 0.56, size * 0.20
    pill = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pill)
    pd.rounded_rectangle([cx - pw / 2, cy - ph / 2, cx + pw / 2, cy + ph / 2],
                         radius=ph / 2, fill=(6, 10, 22, 255))
    pd.rounded_rectangle([cx - pw / 2, cy - ph / 2, cx + pw / 2, cy + ph / 2],
                         radius=ph / 2, outline=(255, 255, 255, 70), width=max(2, int(size * 0.008)))
    img.alpha_composite(pill)

    # leading glyph: a tiny Tian Shan triangle
    gx = cx - pw * 0.33
    gs = size * 0.055
    d.polygon([(gx, cy + gs * 0.75), (gx + gs, cy - gs * 0.85), (gx + gs * 2, cy + gs * 0.75)],
              fill=lerp(INDIGO, CYAN, 0.4) + (255,))

    # countdown: ten tick marks, the last two gold (evening study)
    for i in range(10):
        x = cx - pw * 0.14 + i * (pw * 0.028)
        top = cy - size * 0.045
        bot = cy + size * 0.045
        if i < 8:
            col = lerp(INDIGO, VIOLET, i / 8) + (255,)
            d.line([(x, top), (x, bot)], fill=col, width=max(2, int(size * 0.010)))
        else:
            d.line([(x, top), (x, bot)], fill=GOLD + (255,), width=max(2, int(size * 0.012)))
    # sweeping hand
    d.arc([cx - pw * 0.22, cy - size * 0.085, cx + pw * 0.22, cy + size * 0.085],
          start=-92, end=40, fill=lerp(CYAN, VIOLET, 0.5) + (230,),
          width=max(2, int(size * 0.014)))

    img.alpha_composite(grain((size, size), 5))
    return img


CONCEPTS = {
    'concept-1-schedule-ring.png': concept_schedule_ring,
    'concept-2-tianshan-book.png': concept_tianshan_book,
    'concept-3-glass-palm.png': concept_glass_palm,
    'concept-4-dynamic-island.png': concept_dynamic_island,
}


def main():
    base = 1024
    records = []
    for name, fn in CONCEPTS.items():
        img = fn(base * SS // SS).convert('RGBA')
        # downsample for clean anti-aliased edges
        img = img.resize((base, base), Image.LANCZOS)
        records.append(save(img, name))
        # 216px preview for quick comparison
        records.append(save(img.resize((216, 216), Image.LANCZOS),
                            name.replace('.png', '-216.png')))
    manifest = OUT / 'concepts.json'
    manifest.write_text(json.dumps(records, indent=2), encoding='utf-8')
    print(json.dumps(records, indent=2))


if __name__ == '__main__':
    main()
