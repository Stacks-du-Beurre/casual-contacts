#!/bin/bash
# Regenerates Swift Path constants from design-assets/Guilloche/App/ into
# Packages/Sources/Visuals/Guilloche/Generated/.
# Run after updating SVG assets or changing the SVGToSwift tool.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${REPO_ROOT}/Packages/Sources/Visuals/Guilloche/Generated"
GUILLOCHE_APP_DIR="${REPO_ROOT}/design-assets/Guilloche/App"
CYRILLIC_RESOURCE_DIR="${REPO_ROOT}/Packages/Sources/Visuals/Resources/Guilloche"

# Wipe only the generated subdirs — preserve the top-level dir and its .gitkeep
# so the folder survives a fresh clone before the script has ever run.
rm -rf "${OUT_DIR}/Rotation" "${OUT_DIR}/Blend"
mkdir -p "${OUT_DIR}"

"${REPO_ROOT}/Tools/package-cyrillic-guilloche.py"

rm -rf "${CYRILLIC_RESOURCE_DIR}"
mkdir -p "${CYRILLIC_RESOURCE_DIR}/Rotation" "${CYRILLIC_RESOURCE_DIR}/Blend"
cp -R "${GUILLOCHE_APP_DIR}/Rotation/Cyrillic" "${CYRILLIC_RESOURCE_DIR}/Rotation/"
cp -R "${GUILLOCHE_APP_DIR}/Blend/Cyrillic" "${CYRILLIC_RESOURCE_DIR}/Blend/"

swift run --package-path "${REPO_ROOT}/Tools/SVGToSwift" svg-to-swift \
    "${GUILLOCHE_APP_DIR}/Rotation/Latin" \
    "${OUT_DIR}/Rotation/Latin" \
    "CCVisuals.Guilloche.Rotation.Latin"

swift run --package-path "${REPO_ROOT}/Tools/SVGToSwift" svg-to-swift \
    "${GUILLOCHE_APP_DIR}/Blend/Latin" \
    "${OUT_DIR}/Blend/Latin" \
    "CCVisuals.Guilloche.Blend.Latin"

echo "Generated $(find "${OUT_DIR}" -name '*.swift' | wc -l) Swift files"
