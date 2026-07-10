#!/usr/bin/env bash
# package.sh — build the PUBLIC CurseForge zip of EasyMountFarmer.
#
# The distributed addon ships with the mount data already baked in (Data/*.lua) but
# WITHOUT the developer-only pieces:
#   - Tools/Generator.lua (the `/emf gen` in-game data generator) is removed, and its
#     load line is stripped from the .toc (the `/emf gen` command becomes a no-op).
#   - the EasyMountFarmerGen saved variable (only written by the generator) is dropped.
#
# Output: EasyMountFarmer-<version>.zip at the repo root, containing a top-level
# EasyMountFarmer/ folder (the layout CurseForge / the game expect).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
SRC="$ROOT/EasyMountFarmer"
TOC="$SRC/EasyMountFarmer.toc"

if [ ! -f "$TOC" ]; then echo "TOC not found: $TOC" >&2; exit 1; fi
if ! command -v zip >/dev/null 2>&1; then echo "'zip' is required (apt-get install zip)." >&2; exit 1; fi

VERSION="$(grep -m1 '## Version:' "$TOC" | sed 's/.*:[[:space:]]*//' | tr -d '\r')"
VERSION="${VERSION:-0.0.0}"

BUILD="$ROOT/build"
OUT="$BUILD/EasyMountFarmer"
ZIP="$ROOT/EasyMountFarmer-$VERSION.zip"

rm -rf "$BUILD" "$ZIP"
mkdir -p "$OUT"
cp -r "$SRC/." "$OUT/"

# --- strip developer-only pieces ------------------------------------------------
rm -f "$OUT/Tools/Generator.lua"
rmdir "$OUT/Tools" 2>/dev/null || true

# rebuild the .toc without the generator load line and without the dev saved var
grep -v '[Tt]ools\\Generator\.lua' "$TOC" \
  | sed 's/,[[:space:]]*EasyMountFarmerGen//; s/EasyMountFarmerGen,[[:space:]]*//' \
  > "$OUT/EasyMountFarmer.toc"

# --- sanity check: the generator file is gone and the .toc is clean -------------
# (source comments may still mention the generator by name — that's harmless.)
if [ -f "$OUT/Tools/Generator.lua" ]; then
  echo "WARN: Tools/Generator.lua is still present in the build." >&2
fi
if grep -q 'Generator\.lua\|EasyMountFarmerGen' "$OUT/EasyMountFarmer.toc"; then
  echo "WARN: a dev reference survived in the .toc:" >&2
  grep -n 'Generator\.lua\|EasyMountFarmerGen' "$OUT/EasyMountFarmer.toc" >&2 || true
fi

# --- zip (top-level EasyMountFarmer/ folder) ------------------------------------
( cd "$BUILD" && zip -r -q -X "$ZIP" EasyMountFarmer )
rm -rf "$BUILD"

echo "Packaged v$VERSION -> $ZIP"
unzip -l "$ZIP" | sed 's/^/  /'
