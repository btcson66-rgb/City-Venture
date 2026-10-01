"""Proportional sprite packing and emission extraction, not illustration painting."""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/art_sources/street_environment_20261001'
ASSETS = ROOT / 'game/assets'


def transform_rect(rect, ratio, offset, crop):
    x0, y0, x1, y1 = rect
    return [round(((x0 - crop[0]) * ratio + offset[0]) / 4),
            round(((y0 - crop[1]) * ratio + offset[1]) / 4),
            round((x1 - x0) * ratio / 4), round((y1 - y0) * ratio / 4)]


def run():
    definitions = json.loads((SOURCE / 'layout.json').read_text(encoding='utf-8'))
    manifest = []
    transforms = {}
    meta_path = ASSETS / 'buildings/buildings_meta.json'
    building_meta = json.loads(meta_path.read_text(encoding='utf-8'))
    sprite_path = ASSETS / 'sprite_meta.json'
    sprite_meta = json.loads(sprite_path.read_text(encoding='utf-8'))
    for name, definition in definitions.items():
        original = Image.open(SOURCE / 'originals' / (name + '.png')).convert('RGBA')
        crop = original.getchannel('A').point(lambda a: 255 if a > 96 else 0).getbbox()
        art = original.crop(crop)
        folder = definition['folder']
        logical = Image.open(ASSETS / folder / (name + '.png')).size
        w, h = [v * 4 for v in logical]
        ratio = min(w / art.width, h / art.height)
        resized = art.resize((round(art.width * ratio), round(art.height * ratio)), Image.Resampling.LANCZOS)
        offset = ((w - resized.width) // 2, h - resized.height)
        packed = Image.new('RGBA', (w, h))
        packed.alpha_composite(resized, offset)
        variants = {'': packed}
        if definition.get('emit'):
            source = np.asarray(original).copy()
            rgb = source[:, :, :3].astype(float)
            warm = (rgb[:, :, 0] > 205) & (rgb[:, :, 1] > 135) & (rgb[:, :, 0] > rgb[:, :, 1] * 1.12) & (rgb[:, :, 2] < rgb[:, :, 1] * .82)
            region = np.zeros(warm.shape, dtype=bool)
            for rect in definition['emit']:
                x0, y0, x1, y1 = rect
                region[y0:y1, x0:x1] = True
            source[:, :, 3] = np.where(warm & region, source[:, :, 3], 0)
            lamp = Image.fromarray(source).crop(crop).resize(resized.size, Image.Resampling.LANCZOS)
            emission = Image.new('RGBA', (w, h))
            emission.alpha_composite(lamp, offset)
            variants['_lights'] = emission
            assert emission.getchannel('A').getbbox(), name
            if folder == 'props':
                a = np.asarray(emission.getchannel('A')).astype(float)
                yy, xx = np.indices(a.shape)
                glow = [round(float((xx * a).sum() / a.sum()) / 4), round(float((yy * a).sum() / a.sum()) / 4)]
                sprite_meta.setdefault('props/' + name, {})['glow'] = glow
        if folder == 'buildings':
            for field in ['door', 'sign']:
                if field in definition:
                    building_meta[name][field] = transform_rect(definition[field], ratio, offset, crop)
        for suffix, im in variants.items():
            for prefix, bitmap in [(folder, im.resize(logical, Image.Resampling.LANCZOS)), ('world_detail/' + folder, im)]:
                path = ASSETS / prefix / (name + suffix + '.png')
                path.parent.mkdir(parents=True, exist_ok=True)
                bitmap.save(path)
                manifest.append({'path': path.relative_to(ROOT).as_posix(), 'size': list(bitmap.size), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
        transforms[name] = {'crop': crop, 'ratio': ratio, 'offset': offset, 'logical': logical}
    meta_path.write_text(json.dumps(building_meta, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    sprite_path.write_text(json.dumps(sprite_meta, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    (SOURCE / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (SOURCE / 'transforms.json').write_text(json.dumps(transforms, indent=2) + '\n', encoding='utf-8')
    print(f'street_environment_pack: {len(definitions)} originals, {len(manifest)} PNG; footprints retained, door/sign/glow metadata aligned')


if __name__ == '__main__':
    run()
