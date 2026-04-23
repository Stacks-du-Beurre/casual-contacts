#!/bin/bash
# One-shot: trims the 1px lighter bleed row from the top AND bottom of the
# 3 time-of-day gradient PNGs that were exported 417-tall with an anti-aliased
# artboard margin (Dusk, Night, Midnight). Output overwrites each PNG in place
# in both design-assets/Gradients/ and Packages/.../Gradients.xcassets/.
#
# After running, the 3 edited PNGs will be 415-tall — all 7 remain within ±1px
# of each other in aspect, so EmptyStateGradientBackdrop's hardcoded imageSize
# stays accurate enough for the parallax slack calculation.
#
# Idempotent: exits early if a target PNG is already 415-tall.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="${REPO_ROOT}/design-assets/Gradients"
ASSET_DIR="${REPO_ROOT}/Packages/Sources/DesignSystem/Resources/Gradients.xcassets"

TARGETS=("Dusk" "Night" "Midnight")

trim_one_px_top_bottom() {
    local in_path="$1"
    local out_path="$2"
    local w
    local h
    w=$(sips -g pixelWidth  "$in_path" | awk '/pixelWidth:/  {print $2}')
    h=$(sips -g pixelHeight "$in_path" | awk '/pixelHeight:/ {print $2}')
    if [ "$h" -le 415 ]; then
        echo "  already ${w}x${h}, skipping"
        return 0
    fi
    local new_h=$((h - 2))
    # sips cropOffset is <top> <left>; cropToHeightWidth is <height> <width>.
    sips --cropToHeightWidth "$new_h" "$w" --cropOffset 1 0 "$in_path" --out "$out_path" >/dev/null
    echo "  ${w}x${h} -> ${w}x${new_h}"
}

for name in "${TARGETS[@]}"; do
    echo "=== $name ==="
    src="${SRC_DIR}/${name}.png"
    asset="${ASSET_DIR}/${name}.imageset/${name}.png"
    for p in "$src" "$asset"; do
        if [ -f "$p" ]; then
            echo "  $p"
            trim_one_px_top_bottom "$p" "$p"
        else
            echo "  MISSING: $p" >&2
            exit 1
        fi
    done
done

echo
echo "Final sizes:"
for name in Dawn Sunrise Midday Sunset Dusk Night Midnight; do
    f="${ASSET_DIR}/${name}.imageset/${name}.png"
    dims=$(sips -g pixelWidth -g pixelHeight "$f" | awk '/pixel/ {print $2}' | tr '\n' 'x' | sed 's/x$//')
    echo "  $name: $dims"
done
