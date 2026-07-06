#!/usr/bin/env bash
# Wrapper for generate-ios-assets.py — validates dependencies, then runs.
set -euo pipefail

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "error: rsvg-convert not found on PATH" >&2
  echo "       install with:  brew install librsvg" >&2
  exit 1
fi

if ! python3 -c "import PIL" >/dev/null 2>&1; then
  echo "error: Pillow not installed for python3" >&2
  echo "       install with:  python3 -m pip install --user Pillow" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/generate-ios-assets.py" "$@"
