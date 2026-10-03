"""Fail release packaging when a required artifact is absent or over its decimal MB budget."""
from pathlib import Path
import argparse
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    checks = [(args.root / 'build/web/index.pck', 160_000_000)]
    windows = sorted((args.root / 'dist').glob('CityVenture-*-Windows.zip'))
    if len(windows) != 1:
        print(f'FAIL: expected exactly one Windows release zip, found {len(windows)}')
        return 1
    checks.append((windows[0], 180_000_000))
    failed = False
    for path, limit in checks:
        if not path.is_file():
            print(f'FAIL: missing {path.relative_to(args.root)}')
            failed = True
            continue
        size = path.stat().st_size
        ok = size <= limit
        print(f'{"PASS" if ok else "FAIL"}: {path.relative_to(args.root)} '
              f'{size} bytes ({size / 1e6:.2f} MB) <= {limit / 1e6:.0f} MB')
        failed |= not ok
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
