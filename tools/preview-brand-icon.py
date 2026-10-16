"""Offline size and mask preflight, not a platform screenshot."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / 'docs/brand/mountain-book-1024.png').convert('RGBA')
assert source.size == (1024, 1024)
assert source.getchannel('A').getextrema() == (255, 255), 'Source must be opaque'
canvas = Image.new('RGB', (1000, 560), '#eef2fa')
draw = ImageDraw.Draw(canvas)
draw.text((32, 24), 'OFFLINE PREFLIGHT - NOT A DEVICE SCREENSHOT', fill='#152039')
for column, size in enumerate((24, 32, 48, 64)):
    x = 48 + column * 240
    small = source.resize((size, size), Image.Resampling.LANCZOS)
    canvas.paste(small, (x, 90), small)
    draw.text((x, 166), f'{size}px actual size', fill='#152039')
    for row, shape in enumerate(('circle', 'rounded')):
        tile = source.resize((144, 144), Image.Resampling.LANCZOS)
        mask = Image.new('L', tile.size, 0)
        painter = ImageDraw.Draw(mask)
        if shape == 'circle':
            painter.ellipse((0, 0, 143, 143), fill=255)
        else:
            painter.rounded_rectangle((0, 0, 143, 143), radius=36, fill=255)
        y = 214 + row * 170
        canvas.paste(tile, (x, y), mask)
        draw.text((x + 150, y + 64), shape, fill='#152039')
output = ROOT / 'docs/brand/mountain-book-preflight.png'
canvas.save(output)
print('Opaque source verified; wrote ' + str(output))
