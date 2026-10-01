"""Technical crop, proportional packing and tint/emission separation of vehicle originals.

No illustration is drawn here. Every sprite comes from the preserved generated originals.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/art_sources/city_traffic_20261001'
ASSETS = ROOT / 'game/assets'


def objects(im):
    alpha = np.asarray(im.getchannel('A'))
    columns = (alpha > 96).sum(axis=0) > 8
    runs = []
    start = None
    for x, occupied in enumerate(list(columns) + [False]):
        if occupied and start is None:
            start = x
        if not occupied and start is not None:
            if x - start > 30:
                runs.append((start, x))
            start = None
    boxes = []
    for left, right in runs:
        cell = im.crop((left, 0, right, im.height))
        box = cell.getchannel('A').point(lambda a: 255 if a > 96 else 0).getbbox()
        if box:
            boxes.append((left + box[0], box[1], left + box[2], box[3]))
    return boxes


def fit(im, size):
    # Preserve real vehicle proportions, align tyres to the same design baseline.
    w, h = size
    ratio = min((w - 8) / im.width, (h - 8) / im.height)
    im = im.resize((round(im.width * ratio), round(im.height * ratio)), Image.Resampling.LANCZOS)
    result = Image.new('RGBA', size)
    result.alpha_composite(im, ((w - im.width) // 2, h - 4 - im.height))
    return result


def layers(im, name, view):
    a = np.asarray(im).copy()
    rgb = a[:, :, :3].astype(np.int16)
    bright = rgb.mean(axis=2)
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    # Neutral paint is tintable. Navy glass, dark rubber, grille and warm lamps stay fixed.
    paint = (bright > 108) & (spread < 42)
    if view == 'side':
        # Wheel hubs are always silver even when the paint becomes blue / taxi gold.
        box = im.getchannel('A').point(lambda a: 255 if a > 96 else 0).getbbox()
        x0, y0, x1, y1 = box
        wheels = {'sedan': (.20, .81, .82, .20), 'compact': (.21, .815, .81, .22),
                  'taxi': (.20, .81, .82, .20), 'van': (.21, .79, .84, .18),
                  'bus': (.237, .72, .84, .18)}[name]
        yy, xx = np.indices(paint.shape)
        radius = (y1 - y0) * wheels[3]
        for cx in wheels[:2]:
            wheel = ((xx - (x0 + (x1 - x0) * cx)) ** 2 + (yy - (y0 + (y1 - y0) * wheels[2])) ** 2) < radius ** 2
            paint &= ~wheel
    body = a.copy()
    grey = np.rint(bright).astype(np.uint8)
    body[:, :, :3] = grey[:, :, None]
    body[:, :, 3] = np.where(paint, a[:, :, 3], 0)
    detail = a.copy()
    detail[:, :, 3] = np.where(paint, 0, a[:, :, 3])
    warm = (rgb[:, :, 0] > 120) & (rgb[:, :, 0] > rgb[:, :, 1] * 1.22) & (rgb[:, :, 0] > rgb[:, :, 2] * 1.45)
    # Emission only, no paint / rubber / glass / car silhouette in the light mask.
    emission = a.copy()
    emission[:, :, 3] = np.where(warm, a[:, :, 3], 0)
    return dict(body=Image.fromarray(body), detail=Image.fromarray(detail), lights=Image.fromarray(emission))


def run():
    inputs = json.loads((SOURCE / 'sources.json').read_text(encoding='utf-8'))
    manifest = []
    crops = {}
    for name, source in inputs.items():
        im = Image.open(SOURCE / source['file']).convert('RGBA')
        boxes = objects(im)
        views = ['side', 'front', 'back'] if name in ['sedan', 'compact'] else ['side']
        assert len(boxes) == len(views), (name, boxes)
        crops[name] = boxes
        for view, box in zip(views, boxes):
            base = f'{name}_{view}' if name != 'metro' else 'metro_train'
            old = ASSETS / 'vehicles' / (base + ('_body' if name != 'metro' else '') + '.png')
            logical = Image.open(old).size
            packed = fit(im.crop(box), tuple(d * 4 for d in logical))
            variants = layers(packed, name, view) if name != 'metro' else {'': packed}
            for suffix, art in variants.items():
                key = base + ('_' + suffix if suffix else '')
                native = art.resize(logical, Image.Resampling.LANCZOS)
                for folder, bitmap in [('vehicles', native), ('world_detail/vehicles', art)]:
                    path = ASSETS / folder / (key + '.png')
                    path.parent.mkdir(parents=True, exist_ok=True)
                    bitmap.save(path)
                    manifest.append({'path': path.relative_to(ROOT).as_posix(), 'size': list(bitmap.size), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    (SOURCE / 'crops.json').write_text(json.dumps(crops, indent=2) + '\n', encoding='utf-8')
    (SOURCE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'traffic_pack: {len(manifest)} PNG assets; existing logical footprints retained')


if __name__ == '__main__':
    run()
