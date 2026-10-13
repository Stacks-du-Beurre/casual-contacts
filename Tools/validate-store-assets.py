#!/usr/bin/env python3
"""Reject incomplete store copy or image sets before any remote write."""
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCALES = ("en-US", "ru", "uk")
LIMITS = {"name": 30, "subtitle": 30, "description": 4000, "keywords": 100,
          "release_notes": 4000, "promotional_text": 170}
DEVICES = {"iPhone 17 Pro Max": (1320, 2868)}

def validate(metadata, screenshots):
    for locale in LOCALES:
        folder = metadata / locale
        for field in ("description", "keywords", "release_notes", "support_url", "privacy_url"):
            value = (folder / f"{field}.txt").read_text().strip()
            if not value:
                raise ValueError(f"Empty {locale}/{field}")
            if field.endswith("_url") and not value.startswith("https://"):
                raise ValueError(f"Invalid URL in {locale}/{field}")
        for field, limit in LIMITS.items():
            file = folder / f"{field}.txt"
            if file.exists() and len(file.read_text().strip()) > limit:
                raise ValueError(f"{locale}/{field} exceeds {limit} characters")
        for device, size in DEVICES.items():
            images = sorted((screenshots / locale).glob(f"*-{device}-*.jpg"))
            if len(images) != 6:
                raise ValueError(f"Expected 6 {locale}/{device} screenshots, got {len(images)}")
            for image in images:
                result = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(image)], text=True)
                values = dict(line.strip().split(": ", 1) for line in result.splitlines()[1:])
                if (int(values["pixelWidth"]), int(values["pixelHeight"])) != size:
                    raise ValueError(f"Wrong screenshot size: {image.name}")

if __name__ == "__main__":
    validate(ROOT / "AppStore/metadata", Path(os.environ["CC_STORE_SCREENSHOTS"]))
    print("Validated localized metadata and all 18 store screenshots.")
