#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ICON_DIR="$REPO_ROOT/Checkera/Resources/Assets.xcassets/AppIcon.appiconset"
SRC="$ICON_DIR/Icon-1024.png"

if [[ ! -f "$SRC" ]]; then
  echo "error: source not found at $SRC" >&2
  exit 1
fi

# size table: <pixel-size> <output-filename>
SIZES=(
  "20  Icon-20.png"
  "40  Icon-20@2x.png"
  "60  Icon-20@3x.png"
  "29  Icon-29.png"
  "58  Icon-29@2x.png"
  "87  Icon-29@3x.png"
  "40  Icon-40.png"
  "80  Icon-40@2x.png"
  "120 Icon-40@3x.png"
  "120 Icon-60@2x.png"
  "180 Icon-60@3x.png"
  "76  Icon-76.png"
  "152 Icon-76@2x.png"
  "167 Icon-83.5@2x.png"
)

for entry in "${SIZES[@]}"; do
  read -r size name <<<"$entry"
  out="$ICON_DIR/$name"
  sips -z "$size" "$size" "$SRC" --out "$out" >/dev/null
  echo "wrote $name (${size}x${size})"
done

echo "done."
