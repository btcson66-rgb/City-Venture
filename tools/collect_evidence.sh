#!/bin/bash
# Collect Vertical Slice 001 evidence into evidence/vs001/:
#   test-reports/  unit tests (JUnit XML + console)
#   screenshots/   rendered walkthrough (real input) + scenery tour
#   logs/          walkthrough logs (headless + rendered) and export smoke log
#   videos/        uncut gameplay video recorded with Godot Movie Maker (see --video below)
# Usage: tools/collect_evidence.sh [--video]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EV="$ROOT/evidence/vs001"
GAME="$ROOT/game"
XVFB=(xvfb-run -a -s "-screen 0 1280x720x24")
GODOT_R=(godot --path "$GAME" --rendering-driver opengl3 --resolution 1280x720)
mkdir -p "$EV/test-reports" "$EV/screenshots/walkthrough" "$EV/screenshots/tour" "$EV/logs" "$EV/videos"

echo "== unit tests"
godot --headless --path "$GAME" res://tests/test_runner.tscn -- --junit="$EV/test-reports/unit.xml" \
	> "$EV/test-reports/unit_console.txt" 2>&1
tail -1 "$EV/test-reports/unit_console.txt"

echo "== headless walkthrough (full slice incl. month close)"
rm -rf /tmp/cv_wt && timeout 2400 godot --headless --path "$GAME" -- --bot=walkthrough --out=/tmp/cv_wt \
	> "$EV/logs/walkthrough_headless_console.txt" 2>&1
cp /tmp/cv_wt/walkthrough_log.txt "$EV/logs/walkthrough_headless.txt" 2>/dev/null
cp /tmp/cv_wt/walkthrough_result.json "$EV/logs/walkthrough_headless_result.json" 2>/dev/null
tail -1 "$EV/logs/walkthrough_headless.txt"

echo "== rendered walkthrough (screenshots)"
rm -rf /tmp/cv_wtx && timeout 3000 "${XVFB[@]}" "${GODOT_R[@]}" -- --bot=walkthrough --out=/tmp/cv_wtx \
	> "$EV/logs/walkthrough_rendered_console.txt" 2>&1
rm -f "$EV/screenshots/walkthrough/"*.png
cp /tmp/cv_wtx/screenshots/*.png "$EV/screenshots/walkthrough/" 2>/dev/null
cp /tmp/cv_wtx/walkthrough_log.txt "$EV/logs/walkthrough_rendered.txt" 2>/dev/null
tail -1 "$EV/logs/walkthrough_rendered.txt"

echo "== scenery tour"
rm -rf /tmp/cv_tour && timeout 300 "${XVFB[@]}" "${GODOT_R[@]}" -- --bot=shots --out=/tmp/cv_tour \
	> "$EV/logs/tour_console.txt" 2>&1
rm -f "$EV/screenshots/tour/"*.png
cp /tmp/cv_tour/screenshots/*.png "$EV/screenshots/tour/" 2>/dev/null

if [ "${1:-}" = "--video" ]; then
	echo "== uncut gameplay video (Movie Maker, 30 fps)"
	rm -rf /tmp/cv_vid && mkdir -p /tmp/cv_vid
	timeout 7200 "${XVFB[@]}" "${GODOT_R[@]}" --write-movie /tmp/cv_vid/walkthrough.avi --fixed-fps 30 \
		-- --bot=walkthrough --video --out=/tmp/cv_vid > "$EV/logs/video_console.txt" 2>&1
	cp /tmp/cv_vid/walkthrough_log.txt "$EV/logs/walkthrough_video.txt" 2>/dev/null
	ffmpeg -y -loglevel error -i /tmp/cv_vid/walkthrough.avi -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p \
		-movflags +faststart "$EV/videos/vs001_gameplay_uncut.mp4"
	ffprobe -v error -show_entries format=duration -of csv=p=0 "$EV/videos/vs001_gameplay_uncut.mp4"
fi
echo "evidence -> $EV"
