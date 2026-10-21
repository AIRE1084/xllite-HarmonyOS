"""Export the generated mountain/book concept with an opaque store background."""
from pathlib import Path
from PIL import Image
import hashlib
import json
import shutil
import sys

root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
assets = root / 'docs' / 'brand'
assets.mkdir(parents=True, exist_ok=True)
original = assets / 'mountain-book-generated.png'
if source.resolve() != original.resolve():
    shutil.copyfile(source, original)
im = Image.open(original).convert('RGBA')
# Keep the generated artwork separate; store exports must have a complete square background.
background = Image.new('RGBA', im.size, '#081D59')
background.alpha_composite(im)
icon = background.convert('RGB').resize((1024, 1024), Image.Resampling.LANCZOS)
out = assets / 'mountain-book-1024.png'
icon.save(out, optimize=True)
icon.resize((216, 216), Image.Resampling.LANCZOS).save(assets / 'mountain-book-216.png', optimize=True)
for relative in ['AppScope/resources/base/media/app_icon.png', 'entry/src/main/resources/base/media/icon.png']:
    shutil.copyfile(out, root / relative)
assert out.stat().st_size < 3 * 1024 * 1024
records = []
for relative in ['docs/brand/mountain-book-1024.png', 'AppScope/resources/base/media/app_icon.png', 'entry/src/main/resources/base/media/icon.png']:
    p = root / relative
    records.append({'path': relative, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'bytes': p.stat().st_size})
assert len({r['sha256'] for r in records}) == 1
(assets / 'icon-integrity.json').write_text(json.dumps(records, indent=2), encoding='utf-8')
print(json.dumps({'sourceSize': im.size, 'sourceAlpha': im.getextrema()[3], 'exports': records}, indent=2))
