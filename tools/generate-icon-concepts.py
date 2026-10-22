"""
Icon concept drafting for 掌上新理工 (HarmonyOS).

Draws original vector-style marks with Pillow and exports them as PNGs into
docs/brand/concepts/. Every mark is composed from primitives (polygons, lines,
gradients) so the result stays reproducible and editable.

Constraints applied to every mark:
- The background is a single flat RGB(8,29,89) fill, matching the shipping
  icon exactly, so the launcher does not show a colour shift when the icon is
  replaced. The "liquid glass" quality lives in the subject's translucency and
  highlights, not in a busy gradient backdrop.
- Output is exported as RGB with no alpha channel, like the shipping icon, so
  the launcher renders it identically on any wallpaper or theme.
- One clear focal point per mark, with no scattered decorative specks.
- Subject kept to roughly 70% of the canvas so circular and squircle masks do
  not clip it, and the subject must stay readable at 48px.
- Everything is drawn at 4x and downsampled, so edges stay clean.

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

SS = 4  # supersampling factor

# Flat launcher background, byte-identical to the shipping icon.
BG = (8, 29, 89)
RING_BASE = (44, 111, 214)
RING_LIVE = (18, 181, 201)
COOL_WHITE = (232, 240, 255)
AMBER = (255, 196, 92)
VIOLET = (123, 92, 230)
SNOW = (226, 238, 255)
CYAN_EDGE = (120, 214, 232)


def vertical_gradient(size, top, bottom, alpha_top=255, alpha_bottom=255):
    """Vertical gradient strip resized to the full canvas."""
    grad = Image.new('RGBA', (1, size[1]))
    px = grad.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        c = tuple(int(round(top[i] + (bottom[i] - top[i]) * t)) for i in range(3))
        a = int(round(alpha_top + (alpha_bottom - alpha_top) * t))
        px[0, y] = c + (a,)
    return grad.resize(size, Image.BILINEAR)


def base_canvas(size):
    """Flat launcher background. No gradient, no glow, no alpha."""
    return Image.new('RGB', (size, size), BG)


def save(img, name):
    """Export as RGB so the PNG carries no alpha channel."""
    rgb = img.convert('RGB')
    path = OUT / name
    rgb.save(path, optimize=True)
    return {
        'name': name,
        'bytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'size': list(rgb.size),
        'mode': rgb.mode,
    }


# --- concept: "天山书页" ------------------------------------------------
# A sharp Tian Shan ridge rising straight out of an open book. The ridge keeps
# the Xinjiang Institute of Technology symbol; the book keeps the current
# icon's "study" meaning; the two are one connected silhouette.
def concept_tianshan_book(size):
    img = base_canvas(size)
    d = ImageDraw.Draw(img)

    cx = size * 0.5
    # The subject spans ~70% of the canvas width.
    half = size * 0.350
    # The ridge base and the book share this line, so the two never separate.
    join_y = size * 0.560
    peak_y = size * 0.255

    # --- ridge: narrow apexes, and a clean straight base sitting on join_y
    peaks = [
        (cx - half * 0.94, join_y),
        (cx - half * 0.42, peak_y),
        (cx - half * 0.14, peak_y + size * 0.105),
        (cx + half * 0.20, peak_y - size * 0.022),
        (cx + half * 0.54, peak_y + size * 0.120),
        (cx + half * 0.96, join_y),
    ]
    d.polygon(peaks, fill=SNOW + (255,))
    # lit left flank of the tallest peak
    d.polygon([peaks[0], peaks[1], (cx - half * 0.30, peak_y + size * 0.150)],
              fill=(255, 255, 255, 255))
    # cool cyan hairline along the ridge
    d.line(peaks, fill=CYAN_EDGE + (200,), width=max(1, int(size * 0.011)), joint='curve')

    # --- open book: two pages meeting at a gutter, top edge anchored on join_y
    page_h = size * 0.130
    top = join_y - page_h * 0.30
    left_page = [
        (cx, join_y),
        (cx - half * 0.88, top),
        (cx - half * 0.88, top + page_h * 1.30),
        (cx, join_y + page_h * 1.05),
    ]
    right_page = [
        (cx, join_y),
        (cx + half * 0.88, top),
        (cx + half * 0.88, top + page_h * 1.30),
        (cx, join_y + page_h * 1.05),
    ]
    for page, a_top, a_bottom in ((left_page, 252, 195), (right_page, 238, 170)):
        mask = Image.new('L', (size, size), 0)
        ImageDraw.Draw(mask).polygon(page, fill=255)
        page_layer = vertical_gradient((size, size), (255, 255, 255), (255, 255, 255),
                                       a_top, a_bottom)
        page_layer.putalpha(mask)
        img.paste(page_layer.convert('RGB'), (0, 0), mask)
    d = ImageDraw.Draw(img)

    # page lines: thick enough (>=3px at 216) to survive downsampling
    line_w = max(1, int(size * 0.016))
    for i in range(3):
        y0 = top + page_h * (0.26 + i * 0.34)
        d.line([(cx - half * 0.76, y0 + page_h * 0.14), (cx - half * 0.14, y0 + page_h * 0.42)],
               fill=(52, 86, 152, 165), width=line_w)
        d.line([(cx + half * 0.14, y0 + page_h * 0.42), (cx + half * 0.76, y0 + page_h * 0.14)],
               fill=(52, 86, 152, 165), width=line_w)
    # the gutter, widened so it still reads at 48px
    d.line([(cx, join_y - page_h * 0.26), (cx, join_y + page_h * 1.00)],
           fill=(36, 64, 132, 205), width=max(1, int(size * 0.022)))
    # the book baseline
    d.line([(cx - half * 0.88, top + page_h * 1.30), (cx, join_y + page_h * 1.05),
            (cx + half * 0.88, top + page_h * 1.30)],
           fill=(255, 255, 255, 140), width=max(1, int(size * 0.011)), joint='curve')

    # --- one warm accent: an amber marker on the tallest peak
    pip = size * 0.030
    px, py = peaks[3]
    d.ellipse([px - pip, py - pip, px + pip, py + pip], fill=AMBER + (255,))
    return img


CONCEPTS = {
    'concept-tianshan-book.png': concept_tianshan_book,
}


def main():
    base = 1024
    records = []
    for name, fn in CONCEPTS.items():
        big = fn(base * SS).resize((base, base), Image.LANCZOS)
        records.append(save(big, name))
        records.append(save(big.resize((216, 216), Image.LANCZOS),
                            name.replace('.png', '-216.png')))
    manifest = OUT / 'concepts.json'
    manifest.write_text(json.dumps(records, indent=2), encoding='utf-8')
    print(json.dumps(records, indent=2))


if __name__ == '__main__':
    main()
