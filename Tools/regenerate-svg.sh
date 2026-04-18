#!/bin/bash
# Regenerates Swift Path constants from design-assets/Rotation/ and
# design-assets/Blended_export/SVG/ into Packages/Sources/Visuals/Guilloche/Generated/.
# Run after updating SVG assets or changing the SVGToSwift tool.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${REPO_ROOT}/Packages/Sources/Visuals/Guilloche/Generated"

# Wipe only the generated subdirs — preserve the top-level dir and its .gitkeep
# so the folder survives a fresh clone before the script has ever run.
rm -rf "${OUT_DIR}/Rotation" "${OUT_DIR}/Blend"
mkdir -p "${OUT_DIR}"

swift run --package-path "${REPO_ROOT}/Tools/SVGToSwift" svg-to-swift \
    "${REPO_ROOT}/design-assets/Rotation" \
    "${OUT_DIR}/Rotation" \
    "CCVisuals.Guilloche.Rotation"

swift run --package-path "${REPO_ROOT}/Tools/SVGToSwift" svg-to-swift \
    "${REPO_ROOT}/design-assets/Blended_export/SVG" \
    "${OUT_DIR}/Blend" \
    "CCVisuals.Guilloche.Blend"

echo "Generated $(find "${OUT_DIR}" -name '*.swift' | wc -l) Swift files"
