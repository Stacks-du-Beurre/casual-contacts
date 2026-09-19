#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ictool="/Applications/Icon Composer.app/Contents/Executables/ictool"
source_icon="$repo_root/CasualContacts/CasualContacts/AppIcon.icon"

if [[ ! -x "$ictool" ]]; then
  echo "Missing Icon Composer ictool at: $ictool" >&2
  exit 1
fi

if [[ ! -d "$source_icon" ]]; then
  echo "Missing source icon: $source_icon" >&2
  exit 1
fi

if ! command -v magick >/dev/null 2>&1; then
  echo "Missing ImageMagick 'magick' command." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

export_icon() {
  local width="$1"
  local height="$2"
  local output="$3"
  local raw="$tmpdir/$(basename "$output").raw.png"

  "$ictool" "$source_icon" \
    --export-image \
    --output-file "$raw" \
    --platform iOS \
    --rendition Default \
    --width "$width" \
    --height "$height" \
    --scale 1 >/dev/null

  magick "$raw" \
    -colorspace sRGB \
    -alpha off \
    -depth 8 \
    -strip \
    -define png:color-type=2 \
    "$output"
}

export_icon 1024 1024 "$repo_root/marketing-site/assets/AppIcon.png"
export_icon 180 180 "$repo_root/marketing-site/apple-touch-icon.png"
export_icon 32 32 "$repo_root/marketing-site/favicon-32.png"
export_icon 16 16 "$repo_root/marketing-site/favicon-16.png"

magick \
  "$repo_root/marketing-site/favicon-16.png" \
  "$repo_root/marketing-site/favicon-32.png" \
  "$repo_root/marketing-site/favicon.ico"
