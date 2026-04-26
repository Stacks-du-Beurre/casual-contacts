#!/usr/bin/env bash
# Composite raw App Store screenshots into Apple device-frame templates.
#
# Operates on whatever PNGs already exist in Screenshots/{light,dark}/
# (produced by Tools/generate-screenshots.sh). Doesn't re-run the UI
# tests — fast to iterate on framing alone.
#
# Output: <screen>_framed.png next to each <screen>.png.
#
# Frame templates live in Tools/frame-templates/ as SVGs (or PNGs).
# The first run rasterizes the SVG and caches the PNG; subsequent
# runs reuse the cache unless the SVG is newer.
#
# Usage:
#   Tools/frame-screenshots.sh                                  # both appearances, default frame
#   Tools/frame-screenshots.sh --appearance dark                # only dark mode
#   Tools/frame-screenshots.sh --frame iphone-17-pro-max-black-titanium
#       Use a different template. Argument is the file name in
#       Tools/frame-templates/ without the .svg/.png extension.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES_DIR="$REPO_ROOT/Tools/frame-templates"
VENV_DIR="$REPO_ROOT/Tools/.venv"
SCREENSHOTS_DIR="$REPO_ROOT/Screenshots"
COMPOSITOR="$REPO_ROOT/Tools/frame_compositor.py"

frame_name="iphone-17-pro-max-natural-titanium"
appearance_filter=""
while [ $# -gt 0 ]; do
    case "$1" in
        --frame)
            shift
            frame_name="${1:?--frame requires a template name}"
            ;;
        --appearance)
            shift
            case "$1" in
                light|dark) appearance_filter="$1" ;;
                *) echo "Unknown appearance: $1 (expected light or dark)" >&2; exit 1 ;;
            esac
            ;;
        -h|--help)
            sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown arg: $1" >&2
            exit 1
            ;;
    esac
    shift
done

# Resolve the frame template — prefer SVG (auto-rasterized) but accept PNG.
template=""
for ext in svg png; do
    candidate="$TEMPLATES_DIR/$frame_name.$ext"
    if [ -f "$candidate" ]; then
        template="$candidate"
        break
    fi
done
if [ -z "$template" ]; then
    echo "ERROR: no template found at $TEMPLATES_DIR/$frame_name.{svg,png}" >&2
    exit 1
fi

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "ERROR: rsvg-convert not found. Install with: brew install librsvg" >&2
    exit 1
fi

# Bootstrap a Python venv with Pillow on first run. Cached at
# Tools/.venv/ (gitignored). Cheap to skip if already present.
if [ ! -x "$VENV_DIR/bin/python3" ]; then
    echo "Creating Pillow venv at $VENV_DIR (one-time, ~10s)…"
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/python3" -m pip install --quiet --upgrade pip
    "$VENV_DIR/bin/python3" -m pip install --quiet Pillow
fi

PYTHON="$VENV_DIR/bin/python3"
APPEARANCES=("light" "dark")

for appearance in "${APPEARANCES[@]}"; do
    if [ -n "$appearance_filter" ] && [ "$appearance" != "$appearance_filter" ]; then
        continue
    fi
    dir="$SCREENSHOTS_DIR/$appearance"
    if [ ! -d "$dir" ]; then
        echo "Skipping $appearance — $dir doesn't exist. Run Tools/generate-screenshots.sh first." >&2
        continue
    fi
    echo
    echo "=== Framing $appearance ($frame_name) ==="
    "$PYTHON" "$COMPOSITOR" "$template" "$dir"
done

echo
echo "Done."
