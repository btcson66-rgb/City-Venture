#!/bin/bash
# Build shareable tester packages into dist/:
#   CityVenture-<ver>-Windows.zip  CityVenture-<ver>-macOS.zip  CityVenture-<ver>-Linux.zip
#   CityVenture-<ver>-Web.zip  (upload to itch.io as an HTML game; see HOW_TO_SHARE_WEB.txt inside)
# Needs Godot 4.5.1 export templates incl. web_nothreads_release.zip and macos.zip.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
VER=$(grep -m1 '^config/version=' "$GAME/project.godot" | cut -d'"' -f2)
DATE=$(date +%Y-%m-%d)
DIST="$ROOT/dist"
B="$ROOT/build"
rm -rf "$B" "$DIST"
mkdir -p "$B/windows" "$B/linux" "$B/macos" "$B/web" "$DIST"

python3 "$ROOT/tools/i18n_extract.py" --check
python3 "$ROOT/tools/beta_audit.py"
cd "$GAME"
godot --headless --path . --import >/dev/null 2>&1
godot --headless --path . res://tests/test_runner.tscn | tail -1
godot --headless --path . --export-release "Windows Desktop" "$B/windows/CityVenture.exe" >/dev/null 2>&1
godot --headless --path . --export-release "Linux" "$B/linux/CityVenture.x86_64" >/dev/null 2>&1
godot --headless --path . --export-release "macOS" "$B/macos/CityVenture.zip" >/dev/null 2>&1
godot --headless --path . --export-release "Web" "$B/web/index.html" >/dev/null 2>&1

python3 - "$ROOT" "$VER" "$DATE" <<'PY'
import os, sys, zipfile
root, ver, date = sys.argv[1:4]
b, dist, rel = os.path.join(root, "build"), os.path.join(root, "dist"), os.path.join(root, "tools", "release")

def text(name, crlf):
    s = open(os.path.join(rel, name), encoding="utf-8").read().replace("{VERSION}", ver).replace("{DATE}", date)
    if crlf:
        s = s.replace("\n", "\r\n")
    return "﻿".encode("utf-8") + s.encode("utf-8")   # BOM so Notepad/TextEdit pick UTF-8

def pack(out, entries):
    path = os.path.join(dist, out)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for arc, src in entries:
            info = zipfile.ZipInfo(arc, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            if isinstance(src, bytes):
                info.external_attr = 0o644 << 16
                z.writestr(info, src)
            else:
                mode = os.stat(src).st_mode & 0o777
                info.external_attr = (0o100000 | mode) << 16
                with open(src, "rb") as fh:
                    z.writestr(info, fh.read())
    print("%-40s %6.1f MB" % (out, os.path.getsize(path) / 1e6))

top = "CityVenture-%s" % ver
pack("CityVenture-%s-Windows.zip" % ver, [
    (top + "/CityVenture.exe", os.path.join(b, "windows", "CityVenture.exe")),
    (top + "/README.txt", text("README_TESTERS.txt", True))])
os.chmod(os.path.join(b, "linux", "CityVenture.x86_64"), 0o755)
pack("CityVenture-%s-Linux.zip" % ver, [
    (top + "/CityVenture.x86_64", os.path.join(b, "linux", "CityVenture.x86_64")),
    (top + "/README.txt", text("README_TESTERS.txt", False))])
# macOS: keep Godot's zip (it preserves the .app bundle, executable bits and ad-hoc signature); add the guide
mac_src = os.path.join(b, "macos", "CityVenture.zip")
mac_out = os.path.join(dist, "CityVenture-%s-macOS.zip" % ver)
with zipfile.ZipFile(mac_src) as zi, zipfile.ZipFile(mac_out, "w", zipfile.ZIP_DEFLATED) as zo:
    for item in zi.infolist():
        data = zi.read(item.filename)
        item.filename = top + "/" + item.filename
        zo.writestr(item, data)
    readme = zipfile.ZipInfo(top + "/README.txt", date_time=(2026, 1, 1, 0, 0, 0))
    readme.external_attr = 0o100644 << 16
    zo.writestr(readme, text("README_TESTERS.txt", False))
print("%-40s %6.1f MB" % (os.path.basename(mac_out), os.path.getsize(mac_out) / 1e6))
# web: files at the zip root (itch.io expects index.html there)
web = os.path.join(b, "web")
pack("CityVenture-%s-Web.zip" % ver, [(f, os.path.join(web, f)) for f in sorted(os.listdir(web))] +
     [("HOW_TO_SHARE_WEB.txt", text("HOW_TO_SHARE_WEB.txt", True)), ("README_TESTERS.txt", text("README_TESTERS.txt", True))])
PY
( cd "$DIST" && sha256sum *.zip > SHA256SUMS.txt )
echo "packages -> $DIST"
