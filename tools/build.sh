#!/bin/bash
# Build CITY VENTURE: regenerate placeholder art, import, run tests, export Windows (+ Linux smoke build).
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 tools/art/gen_placeholders.py
python3 tools/gen_districts.py
cd game
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn -- --junit="$ROOT/evidence/vs001/test-reports/unit.xml"
mkdir -p ../build/windows ../build/linux
godot --headless --path . --export-release "Windows Desktop" ../build/windows/CityVenture.exe
godot --headless --path . --export-release "Linux" ../build/linux/CityVenture.x86_64
echo "Build OK: build/windows/CityVenture.exe"
