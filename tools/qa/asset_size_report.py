"""Report actual Godot PCK payloads and conservative source-reference candidates.

Candidates are review hints, never permission to delete: Art.tex builds paths
dynamically, and its native texture still determines logical dimensions.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import re
import struct


def pck_entries(path):
    with path.open('rb') as stream:
        def number(fmt):
            size = struct.calcsize(fmt)
            data = stream.read(size)
            if len(data) != size:
                raise ValueError('Truncated PCK directory')
            return struct.unpack(fmt, data)[0]
        if stream.read(4) != b'GDPC':
            raise ValueError('Expected standalone Godot PCK')
        version = number('<I')
        if version not in (2, 3):
            raise ValueError(f'Unsupported PCK version {version}')
        stream.read(12)  # engine version
        flags = number('<I')
        number('<Q')  # file base
        directory = number('<Q') if version == 3 else None
        if flags & 1:
            raise ValueError('Encrypted directory is unsupported')
        stream.read(64)
        if directory is not None:
            stream.seek(directory)
        count = number('<I')
        entries = []
        for _ in range(count):
            length = number('<I')
            name = stream.read(length).rstrip(b'\0').decode('utf-8')
            number('<Q')  # offset
            size = number('<Q')
            stream.read(16)  # md5
            number('<I')  # flags
            entries.append({'packed_path': name, 'bytes': size})
        return entries


def report(root, pck):
    game = root / 'game'
    imports = {}
    for path in (game / 'assets').rglob('*.import'):
        content = path.read_text(encoding='utf-8')
        source = path.relative_to(game).as_posix().removesuffix('.import')
        for dest in re.findall(r'res://([^"\n]+)', content):
            if dest.startswith('.godot/imported/'):
                imports[dest] = source
    references = '\n'.join(p.read_text(encoding='utf-8', errors='replace')
                           for directory in ('scripts', 'autoload', 'data', 'scenes')
                           for p in (game / directory).rglob('*')
                           if p.suffix in ('.gd', '.json', '.tscn', '.tres'))
    references += '\n'.join(p.read_text(encoding='utf-8', errors='replace')
                            for p in [game / 'project.godot', game / 'export_presets.cfg'])
    references += '\n'.join(p.read_text(encoding='utf-8', errors='replace')
                            for p in (game / 'assets').rglob('*')
                            if p.suffix in ('.tres', '.tscn'))
    referenced_stems = set(re.findall(r'[A-Za-z0-9_-]+', references))
    folders, extensions = defaultdict(int), defaultdict(int)
    entries = pck_entries(pck)
    packed_sources = set()
    for item in entries:
        packed = item['packed_path'].removeprefix('res://')
        source = imports.get(packed, packed)
        item['source'] = source
        packed_sources.add(source)
        folders[str(Path(source).parent).replace('\\', '/')] += item['bytes']
        extensions[Path(source).suffix or '(none)'] += item['bytes']
    candidates, pairs, uncompressed, hashes = [], [], [], defaultdict(list)
    for source in sorted(packed_sources):
        path = game / source
        if not path.is_file() or not source.startswith('assets/'):
            continue
        key = source.removeprefix('assets/').removesuffix(path.suffix)
        native_key = key.removeprefix('world_detail/')
        # Stem checks intentionally over-count references rather than claim safety.
        if path.stem not in referenced_stems:
            candidates.append(source)
        if key.startswith('world_detail/') and 'assets/' + native_key + path.suffix in packed_sources:
            pairs.append({'detail': source, 'native': 'assets/' + native_key + path.suffix,
                          'note': 'Art.tex uses native dimensions; keep until lookup is explicitly verified'})
        if path.suffix.lower() in ('.wav', '.aiff', '.flac'):
            uncompressed.append(source)
        hashes[hashlib.sha256(path.read_bytes()).hexdigest()].append(source)
    return {'pck': str(pck), 'pck_bytes': pck.stat().st_size,
            'payload_bytes': sum(e['bytes'] for e in entries), 'entry_count': len(entries),
            'folders': dict(sorted(folders.items(), key=lambda x: -x[1])),
            'extensions': dict(sorted(extensions.items(), key=lambda x: -x[1])),
            'top50': sorted(entries, key=lambda e: -e['bytes'])[:50],
            'reference_candidates_NOT_PROVEN_UNUSED': candidates,
            'native_detail_pairs': pairs, 'uncompressed_audio': uncompressed,
            'identical_source_files': [v for v in hashes.values() if len(v) > 1]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--pck', type=Path)
    parser.add_argument('--json', type=Path)
    args = parser.parse_args()
    result = report(args.root, args.pck or args.root / 'build/web/index.pck')
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"PCK {result['pck_bytes']} bytes; payload {result['payload_bytes']} bytes; {result['entry_count']} entries")
    for group in ('folders', 'extensions'):
        print(group.upper())
        for name, size in result[group].items():
            print(f'{size:12d} {name}')
    print('TOP 50 (actual packed payload -> source)')
    for entry in result['top50']:
        print(f"{entry['bytes']:12d} {entry['packed_path']} -> {entry['source']}")
    for group in ('reference_candidates_NOT_PROVEN_UNUSED', 'native_detail_pairs', 'uncompressed_audio', 'identical_source_files'):
        print(f'{group}: {len(result[group])} (details in JSON)')


if __name__ == '__main__':
    main()
