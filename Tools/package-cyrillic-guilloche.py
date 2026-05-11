#!/usr/bin/env python3
"""Package Cyrillic guilloche pipeline output for app ingestion.

The Cyrillic blend pipeline produces one SVG per interpolation layer under:

    design-assets/Guilloche/Pipeline/Cyrillic/pipeline/intermediate-blends/

The app ingestion contract is one SVG per glyph/shape, matching the Latin
catalog. This script combines each per-layer stack into:

    design-assets/Guilloche/App/Blend/Cyrillic/U0410_Circle.svg

It also copies finalized rotation source SVGs into:

    design-assets/Guilloche/App/Rotation/Cyrillic/
"""

from __future__ import annotations

import html
import re
import shutil
import sys
from pathlib import Path
from xml.etree import ElementTree


REPO_ROOT = Path(__file__).resolve().parents[1]
CYRILLIC_PIPELINE = REPO_ROOT / "design-assets" / "Guilloche" / "Pipeline" / "Cyrillic" / "pipeline"
APP_ROOT = REPO_ROOT / "design-assets" / "Guilloche" / "App"

ROTATION_SOURCE_DIR = CYRILLIC_PIPELINE / "rotation-sources"
ROTATION_OUTPUT_DIR = APP_ROOT / "Rotation" / "Cyrillic"

BLEND_SOURCE_DIR = CYRILLIC_PIPELINE / "intermediate-blends"
BLEND_OUTPUT_DIR = APP_ROOT / "Blend" / "Cyrillic"

VARIANTS = {
    "Circle": "C",
    "Square": "S",
    "Polygon": "P",
}


def main() -> int:
    if not ROTATION_SOURCE_DIR.is_dir():
        sys.stderr.write(f"Missing rotation source dir: {ROTATION_SOURCE_DIR}\n")
        return 2
    if not BLEND_SOURCE_DIR.is_dir():
        sys.stderr.write(f"Missing blend source dir: {BLEND_SOURCE_DIR}\n")
        return 2

    package_rotations()
    blend_count, path_count = package_blends()
    print(f"Packaged {blend_count} Cyrillic blend SVGs containing {path_count} paths")
    print(f"Copied {len(list(ROTATION_OUTPUT_DIR.glob('*.svg')))} Cyrillic rotation SVGs")
    return 0


def package_rotations() -> None:
    reset_dir(ROTATION_OUTPUT_DIR)
    for source in sorted(ROTATION_SOURCE_DIR.glob("*.svg")):
        shutil.copy2(source, ROTATION_OUTPUT_DIR / source.name)


def package_blends() -> tuple[int, int]:
    reset_dir(BLEND_OUTPUT_DIR)

    blend_count = 0
    path_count = 0
    for glyph_dir in sorted(path for path in BLEND_SOURCE_DIR.iterdir() if path.is_dir()):
        glyph_code = glyph_dir.name
        for variant_name, variant_suffix in VARIANTS.items():
            variant_dir = glyph_dir / variant_name
            if not variant_dir.is_dir():
                continue

            layers = sorted(
                variant_dir.glob(f"{glyph_code}_{variant_suffix}_*.svg"),
                key=layer_number,
            )
            if not layers:
                continue

            character = read_character(layers[0]) or glyph_code
            paths = []
            for layer in layers:
                paths.extend(read_shapes(layer))

            output_name = f"{glyph_code}_{variant_name}.svg"
            output_url = BLEND_OUTPUT_DIR / output_name
            output_url.write_text(
                svg_document(
                    svg_id=f"{glyph_code}_{variant_name}",
                    character=character,
                    variant=variant_name,
                    paths=paths,
                ),
                encoding="utf-8",
            )
            blend_count += 1
            path_count += len(paths)

    return blend_count, path_count


def reset_dir(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)


def layer_number(path: Path) -> int:
    match = re.search(r"_(\d+)\.svg$", path.name)
    if match is None:
        return sys.maxsize
    return int(match.group(1))


def read_character(svg_path: Path) -> str | None:
    root = ElementTree.parse(svg_path).getroot()
    return root.attrib.get("data-character")


def read_shapes(svg_path: Path) -> list[tuple[str, str]]:
    root = ElementTree.parse(svg_path).getroot()
    shapes: list[tuple[str, str]] = []
    for element in root.iter():
        tag = element.tag.rsplit("}", 1)[-1].lower()
        if tag == "path" and "d" in element.attrib:
            shapes.append(("path", element.attrib["d"]))
        elif tag == "polygon" and "points" in element.attrib:
            shapes.append(("polygon", element.attrib["points"]))
    return shapes


def svg_document(svg_id: str, character: str, variant: str, paths: list[tuple[str, str]]) -> str:
    escaped_id = html.escape(svg_id, quote=True)
    escaped_character = html.escape(character, quote=True)
    escaped_variant = html.escape(variant, quote=True)

    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg id="{escaped_id}" data-character="{escaped_character}" data-variant="{escaped_variant}" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 184 160">',
        "  <defs>",
        "    <style>",
        "      .cls-1 {",
        "        fill: none;",
        "        stroke: #000;",
        "        stroke-miterlimit: 10;",
        "        stroke-width: .5px;",
        "      }",
        "    </style>",
        "  </defs>",
    ]

    for index, (shape, value) in enumerate(paths):
        escaped_value = html.escape(value, quote=True)
        if shape == "path":
            lines.append(f'  <path id="{escaped_id}_path{index}" class="cls-1" d="{escaped_value}"/>')
        else:
            lines.append(f'  <polygon id="{escaped_id}_path{index}" class="cls-1" points="{escaped_value}"/>')

    lines.append("</svg>")
    return "\n".join(lines) + "\n"


if __name__ == "__main__":
    raise SystemExit(main())
