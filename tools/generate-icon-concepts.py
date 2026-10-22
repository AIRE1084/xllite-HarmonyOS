"""
Creative icon concepts for 掌上新理工 (HarmonyOS).

Draws original vector-style marks with Pillow and exports them as PNGs into
docs/brand/concepts/. Every concept is composed from primitives (arcs, polygons,
gradients) so the result stays reproducible and editable.

Design constraints applied after the first review round:
- Solid deep-indigo background, matching the shipping icon (#081D59), so the
  launcher does not show a background colour jump when the icon is replaced.
  The "liquid glass" quality lives in the subject's translucency and highlights,
  not in a busy gradient backdrop.
- One focal point per icon, no scattered decorative specks.
- Subject kept to roughly 70% of the canvas so circular and squircle masks do
  not clip it.
- Everything is drawn at 4x and downsampled, so edges are clean.

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

# Solid launcher background, identical family to the shipping icon.
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
    """Solid indigo launcher background with a very soft top-left lift."""
    base = Image.new('RGBA', (size, size), BG + (255,))
    lift = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(lift)
    r = int(size * 0.62)
    d.ellipse([int(size * 0.10) - r, int(size * 0.04) - r,
               int(size * 0.10) + r, int(size * 0.04) + r],
              fill=(255, 255, 255, 20))
    base.alpha_composite(lift.filter(ImageFilter.GaussianBlur(size * 0.16)))
    return base


def glass_white(size, top_alpha=255, bottom_alpha=180):
    """White with a vertical transparency falloff, used for glassy subjects."""
    return vertical_gradient((size, size), (255, 255, 255), (255, 255, 255),
                             top_alpha, bottom_alpha)


def save(img, name):
    path = OUT / name
    img.save(path, optimize=True)
    return {
        'name': name,
        'bytes': path.stat().st_size,
        'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        'size': list(img.size),
    }


# --- concept 1: "课表之环" ---------------------------------------------
# A thick schedule ring with one hand and one amber pip. The ring is the
# timetable made circular; the hand is "the next class"; the pip is "now".
def concept_schedule_ring(size):
    img = base_canvas(size)
    d = ImageDraw.Draw(img)

    c = size * 0.5
    r = size * 0.350
    lw = int(size * 0.111)          # 24px at 216 -> readable weight
    box = [c - r, c - r, c + r, c + r]

    # base ring, slightly translucent so it reads as glass
    d.ellipse(box, outline=RING_BASE + (215,), width=lw)
    # live arc sweeping clockwise from 12 o'clock
    d.arc(box, start=-90, end=150, fill=RING_LIVE + (255,), width=lw)
    # rounded leading cap on the live arc
    ex = c + r * math.cos(math.radians(150))
    ey = c + r * math.sin(math.radians(150))
    d.ellipse([ex - lw / 2, ey - lw / 2, ex + lw / 2, ey + lw / 2], fill=RING_LIVE + (255,))
    # subtle inner rim highlight
    d.arc([c - r + lw * 0.9, c - r + lw * 0.9, c + r - lw * 0.9, c + r - lw * 0.9],
          start=200, end=340, fill=(255, 255, 255, 60), width=max(1, int(size * 0.008)))

    # single hand, from the centre towards 1 o'clock
    a = math.radians(60)
    hand_len = r * 0.70
    hx, hy = c + hand_len * math.cos(a), c + hand_len * math.sin(a)
    hand_w = int(lw * 1.30)
    d.line([(c, c), (hx, hy)], fill=COOL_WHITE + (255,), width=hand_w)
    d.ellipse([c - hand_w / 2, c - hand_w / 2, c + hand_w / 2, c + hand_w / 2],
              fill=COOL_WHITE + (255,))

    # the single warm focal point: an amber pip at the hand tip
    pip = size * 0.033
    d.ellipse([hx - pip, hy - pip, hx + pip, hy + pip], fill=AMBER + (255,))
    d.ellipse([hx - pip * 1.9, hy - pip * 1.9, hx + pip * 1.9, hy + pip * 1.9],
              outline=AMBER + (70,), width=max(1, int(size * 0.006)))

    return img


# --- concept 2: "天山书页" ----------------------------------------------
# A sharp Tian Shan ridge rising out of an open book. The ridge keeps the
# Xinjiang Institute of Technology symbol; the book keeps the current icon's
# "study" meaning. The two are separated by real negative space.
def concept_tianshan_book(size):
    img = base_canvas(size)
    d = ImageDraw.Draw(img)

    cx = size * 0.5
    ridge_y = size * 0.30          # peaks reach this high
    book_y = size * 0.545          # book gutter sits here
    half = size * 0.335            # half width of the whole subject

    # --- sharp ridge: narrow apexes, not rounded hills
    peaks = [
        (cx - half * 0.92, ridge_y + size * 0.135),
        (cx - half * 0.40, ridge_y),
        (cx - half * 0.12, ridge_y + size * 0.085),
        (cx + half * 0.18, ridge_y - size * 0.028),
        (cx + half * 0.52, ridge_y + size * 0.105),
        (cx + half * 0.94, ridge_y + size * 0.150),
    ]
    d.polygon(peaks, fill=SNOW + (252,))
    # lit left flank of the tallest peak
    d.polygon([peaks[0], peaks[1], (cx - half * 0.30, ridge_y + size * 0.105)],
              fill=(255, 255, 255, 255))
    # cool cyan hairline along the ridge so it belongs to the glass language
    d.line(peaks, fill=CYAN_EDGE + (190,), width=max(1, int(size * 0.010)), joint='curve')

    # --- open book: two clearly separated pages meeting at a gutter
    page_h = size * 0.115
    top = book_y - page_h * 0.42
    left_page = [
        (cx, book_y),
        (cx - half * 0.86, top),
        (cx - half * 0.86, top + page_h * 1.55),
        (cx, book_y + page_h * 1.35),
    ]
    right_page = [
        (cx, book_y),
        (cx + half * 0.86, top),
        (cx + half * 0.86, top + page_h * 1.55),
        (cx, book_y + page_h * 1.35),
    ]
    # Fill the pages through a mask so the white can fade out downwards
    # (a solid fill would turn the lower half into a featureless white slab).
    for page, a_top, a_bottom in ((left_page, 250, 185), (right_page, 232, 160)):
        mask = Image.new('L', (size, size), 0)
        ImageDraw.Draw(mask).polygon(page, fill=255)
        page_layer = vertical_gradient((size, size), (255, 255, 255), (255, 255, 255),
                                       a_top, a_bottom)
        page_layer.putalpha(mask)
        img.alpha_composite(page_layer)
    d = ImageDraw.Draw(img)
    # page lines, kept short so they read as pages and not as a solid block
    for i in range(3):
        y0 = top + page_h * (0.30 + i * 0.36)
        d.line([(cx - half * 0.74, y0 + page_h * 0.16), (cx - half * 0.12, y0 + page_h * 0.46)],
               fill=(58, 92, 160, 150), width=max(1, int(size * 0.009)))
        d.line([(cx + half * 0.12, y0 + page_h * 0.46), (cx + half * 0.74, y0 + page_h * 0.16)],
               fill=(58, 92, 160, 150), width=max(1, int(size * 0.009)))
    # the gutter
    d.line([(cx, book_y - page_h * 0.36), (cx, book_y + page_h * 1.30)],
           fill=(40, 70, 140, 190), width=max(1, int(size * 0.011)))
    # bottom edge of the book
    d.line([(cx - half * 0.86, top + page_h * 1.55), (cx, book_y + page_h * 1.35),
            (cx + half * 0.86, top + page_h * 1.55)],
           fill=(255, 255, 255, 120), width=max(1, int(size * 0.010)), joint='curve')

    return img


# --- concept 3: "一周课表" ----------------------------------------------
# A seven-column timetable grid with one cell lit. The grid is the schedule
# seen from above and reads instantly even at launcher size.
def concept_week_grid(size):
    img = base_canvas(size)
    d = ImageDraw.Draw(img)

    cols, rows = 7, 3
    left = size * 0.20
    right = size * 0.80
    top = size * 0.28
    bottom = size * 0.72
    gap_x = size * 0.014
    gap_y = size * 0.020
    cell_w = (right - left - gap_x * (cols - 1)) / cols
    cell_h = (bottom - top - gap_y * (rows - 1)) / rows
    radius = size * 0.018

    # the lit cell: Tuesday of the middle row, drawn first as a soft halo
    lit_col, lit_row = 1, 1
    lx = left + lit_col * (cell_w + gap_x)
    ly = top + lit_row * (cell_h + gap_y)
    halo = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.rounded_rectangle([lx - size * 0.022, ly - size * 0.022,
                           lx + cell_w + size * 0.022, ly + cell_h + size * 0.022],
                          radius=radius * 1.8, fill=RING_LIVE + (120,))
    img.alpha_composite(halo.filter(ImageFilter.GaussianBlur(size * 0.022)))

    for r in range(rows):
        for c in range(cols):
            x0 = left + c * (cell_w + gap_x)
            y0 = top + r * (cell_h + gap_y)
            x1, y1 = x0 + cell_w, y0 + cell_h
            if r == lit_row and c == lit_col:
                d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=RING_LIVE + (255,))
                d.rounded_rectangle([x0, y0, x1, y1], radius=radius,
                                    outline=(255, 255, 255, 210),
                                    width=max(1, int(size * 0.007)))
            else:
                d.rounded_rectangle([x0, y0, x1, y1], radius=radius,
                                    fill=(255, 255, 255, 62))
                d.rounded_rectangle([x0, y0, x1, y1], radius=radius,
                                    outline=(255, 255, 255, 105),
                                    width=max(1, int(size * 0.005)))
    # header ticks: seven days
    for c in range(cols):
        x0 = left + c * (cell_w + gap_x)
        w = size * (0.030 if c != 0 else 0.022)
        d.rounded_rectangle([x0 + (cell_w - w) / 2, size * 0.215, x0 + (cell_w + w) / 2, size * 0.245],
                            radius=size * 0.012,
                            fill=(AMBER + (255,)) if c == lit_col else (255, 255, 255, 120))
    return img


CONCEPTS = {
    'concept-1-schedule-ring.png': concept_schedule_ring,
    'concept-2-tianshan-book.png': concept_tianshan_book,
    'concept-3-week-grid.png': concept_week_grid,
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
