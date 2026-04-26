#!/usr/bin/env python3
"""Composite raw 1320×2868 screenshots into Apple device-frame templates.

Frame templates live in Tools/frame-templates/ as SVGs (or pre-rendered
PNGs). The compositor:

1. Rasterizes the SVG to a PNG once (cached next to the source).
2. Auto-detects the screen rectangle inside the frame by walking
   inward from the bezel — the screen area is the central transparent
   region surrounded by the opaque silver/black bezel ring.
3. Resizes the input screenshot to fit that rectangle.
4. Pastes the screenshot under the frame and alpha-composites the
   frame on top — the dynamic island, bezel highlights, and side
   buttons all stay opaque while the screen content shows through.

Output: <input>_framed.png next to each input.

Usage:
    frame_compositor.py <frame-template.svg> <input-dir> [--output-suffix _framed]
"""
import argparse
import statistics
import subprocess
import sys
from pathlib import Path

from PIL import Image

# Pixel is "opaque bezel" if its alpha is at least this. The bezel
# anti-aliases against the surrounding canvas at the device outline,
# so we want a threshold high enough to skip those edge pixels but
# not so high that we miss the bezel proper.
BEZEL_ALPHA_THRESHOLD = 200

# Width to rasterize the frame SVG at. The frame's intrinsic aspect
# ratio determines the height. Sized so the detected screen area
# can comfortably accommodate a 1320×2868 input without further scale.
FRAME_RENDER_WIDTH = 1500


def rasterize_svg(svg_path: Path) -> Path:
    """Render the SVG to a PNG once, cache next to the source."""
    png_path = svg_path.with_suffix(".png")
    if png_path.exists() and png_path.stat().st_mtime > svg_path.stat().st_mtime:
        return png_path
    print(f"Rasterizing {svg_path.name} → {png_path.name}…")
    subprocess.run(
        ["rsvg-convert", "-w", str(FRAME_RENDER_WIDTH), str(svg_path), "-o", str(png_path)],
        check=True,
    )
    return png_path


def detect_screen_rect(frame: Image.Image) -> tuple[int, int, int, int]:
    """Find the screen rectangle inside the device frame.

    The frame layout is: surrounding canvas (alpha=0) → bezel (alpha>0,
    silver/black/grey) → screen cutout (alpha=0) → optional dynamic-
    island overlay rendered on top of the screen area. The screen
    rectangle is therefore the central transparent hole surrounded
    by the bezel ring.

    Strategy: from the device bounding box, scan inward along several
    parallel rows/columns. Each scan crosses canvas → bezel → screen
    → bezel → canvas, so the second alpha=0 run after the first
    opaque region is the screen interior. Take the median start/end
    across multiple scans for robustness against anti-aliasing and
    side-button cutouts. We avoid the top 20% (dynamic island lives
    there) for the row scans, and the side-button bands for column
    scans.
    """
    pixels = frame.load()
    w, h = frame.size

    # Device bbox — the smallest rect that contains all opaque pixels.
    bbox = frame.getbbox()
    if bbox is None:
        raise ValueError("Frame has no opaque pixels at all.")
    dev_l, dev_t, dev_r, dev_b = bbox

    def horizontal_scan(y: int) -> tuple[int, int] | None:
        """Returns the (left, right) inner edges of the screen at row y."""
        # Walk in from the device's left edge: skip transparent canvas,
        # then opaque bezel, then the screen edge is the next transparent.
        x = dev_l
        # Skip leading transparent canvas (shouldn't be any since dev_l
        # was set to the first opaque column, but be safe).
        while x < dev_r and pixels[x, y][3] < BEZEL_ALPHA_THRESHOLD:
            x += 1
        # Skip bezel.
        while x < dev_r and pixels[x, y][3] >= BEZEL_ALPHA_THRESHOLD:
            x += 1
        if x >= dev_r:
            return None
        screen_left = x
        # Skip screen interior.
        while x < dev_r and pixels[x, y][3] < BEZEL_ALPHA_THRESHOLD:
            x += 1
        screen_right = x
        return (screen_left, screen_right)

    def vertical_scan(x: int) -> tuple[int, int] | None:
        y = dev_t
        while y < dev_b and pixels[x, y][3] < BEZEL_ALPHA_THRESHOLD:
            y += 1
        while y < dev_b and pixels[x, y][3] >= BEZEL_ALPHA_THRESHOLD:
            y += 1
        if y >= dev_b:
            return None
        screen_top = y
        while y < dev_b and pixels[x, y][3] < BEZEL_ALPHA_THRESHOLD:
            y += 1
        screen_bottom = y
        return (screen_top, screen_bottom)

    # Run horizontal scans across the lower 70% of the device — this
    # avoids the dynamic island (top ~10%) and the speaker grille
    # cutout some frames render at the very top.
    h_scan_rows = [int(dev_t + (dev_b - dev_t) * f) for f in (0.30, 0.45, 0.60, 0.75, 0.90)]
    h_results = [r for r in (horizontal_scan(y) for y in h_scan_rows) if r is not None]
    if not h_results:
        raise ValueError("Couldn't locate the screen's left/right edges.")
    screen_left = int(statistics.median(r[0] for r in h_results))
    screen_right = int(statistics.median(r[1] for r in h_results))

    # Run vertical scans down columns to the LEFT and RIGHT of the
    # screen-center axis. Sampling at 1/4 and 3/4 of the screen width
    # avoids the dynamic island AND any anomalies at the exact center.
    quarter = (screen_right - screen_left) // 4
    v_scan_cols = [
        screen_left + quarter,
        screen_left + 2 * quarter,
        screen_right - quarter,
    ]
    v_results = [r for r in (vertical_scan(x) for x in v_scan_cols) if r is not None]
    if not v_results:
        raise ValueError("Couldn't locate the screen's top/bottom edges.")
    screen_top = int(statistics.median(r[0] for r in v_results))
    screen_bottom = int(statistics.median(r[1] for r in v_results))

    return (screen_left, screen_top, screen_right, screen_bottom)


def composite(screenshot_path: Path, frame: Image.Image, screen_rect: tuple[int, int, int, int]) -> Image.Image:
    """Place the screenshot inside the screen rect and overlay the frame."""
    left, top, right, bottom = screen_rect
    sw, sh = right - left, bottom - top

    shot = Image.open(screenshot_path).convert("RGBA")
    shot = shot.resize((sw, sh), Image.LANCZOS)

    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    canvas.paste(shot, (left, top))
    canvas.alpha_composite(frame)
    return canvas


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frame_template", type=Path, help="Path to .svg or .png frame template")
    parser.add_argument("input_dir", type=Path, help="Directory containing raw <screen>.png files")
    parser.add_argument("--output-suffix", default="_framed", help="Suffix added to framed filenames")
    args = parser.parse_args()

    if args.frame_template.suffix.lower() == ".svg":
        frame_png = rasterize_svg(args.frame_template)
    else:
        frame_png = args.frame_template

    frame = Image.open(frame_png).convert("RGBA")
    rect = detect_screen_rect(frame)
    l, t, r, b = rect
    print(f"Frame: {frame.size[0]}×{frame.size[1]}  screen rect: ({l}, {t}, {r}, {b})  size {r-l}×{b-t}")

    inputs = sorted(p for p in args.input_dir.glob("*.png") if args.output_suffix not in p.stem)
    if not inputs:
        print(f"No raw PNGs found in {args.input_dir}", file=sys.stderr)
        return 1

    for src in inputs:
        out = src.with_name(f"{src.stem}{args.output_suffix}.png")
        result = composite(src, frame, rect)
        result.save(out, optimize=True)
        print(f"  {src.name} → {out.name}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
