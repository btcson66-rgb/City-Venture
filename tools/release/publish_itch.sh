#!/bin/bash
# Push the packaged builds in dist/ to itch.io with butler (https://itch.io/docs/butler/).
#   bash tools/package_release.sh          # build dist/ first
#   bash tools/release/publish_itch.sh     # web build -> <ITCH_USER>/<ITCH_GAME>:html5
#   bash tools/release/publish_itch.sh --windows   # also the Windows build -> :windows
# The API key is read only from the BUTLER_API_KEY environment variable. Never put it in the repo.
# The first push to a channel creates a new upload on the itch.io page: on the game's Edit page tick
# "This file will be played in the browser" for the html5 upload once (and remove any older manual upload).
# Later pushes replace that upload's files; players' browser saves stay, since the page origin doesn't change.
set -euo pipefail
ITCH_USER="benson-lai"
ITCH_GAME="cityventure"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VER=$(grep -m1 '^config/version=' "$ROOT/game/project.godot" | cut -d'"' -f2)
DIST="$ROOT/dist"

if [ -z "${BUTLER_API_KEY:-}" ]; then
	echo "BUTLER_API_KEY is not set. Add it to the environment (itch.io → Settings → API keys), then run again." >&2
	exit 1
fi

BUTLER="$(command -v butler || true)"
if [ -z "$BUTLER" ]; then
	BDIR="${XDG_CACHE_HOME:-$HOME/.cache}/butler"
	BUTLER="$BDIR/butler"
	if [ ! -x "$BUTLER" ]; then
		echo "Downloading butler into $BDIR ..."
		mkdir -p "$BDIR"
		curl -fsSL -o "$BDIR/butler.zip" "https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default"
		python3 -c "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$BDIR/butler.zip" "$BDIR"
		chmod +x "$BUTLER"
	fi
fi
"$BUTLER" -V

push() {
	local file="$DIST/CityVenture-$VER-$1.zip"
	if [ ! -f "$file" ]; then
		echo "Missing $file: run tools/package_release.sh first." >&2
		exit 1
	fi
	echo "Pushing $file -> $ITCH_USER/$ITCH_GAME:$2 (version $VER)"
	"$BUTLER" push "$file" "$ITCH_USER/$ITCH_GAME:$2" --userversion "$VER"
}

push Web html5
if [ "${1:-}" = "--windows" ]; then
	push Windows windows
fi
"$BUTLER" status "$ITCH_USER/$ITCH_GAME"
