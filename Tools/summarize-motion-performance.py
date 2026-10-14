#!/usr/bin/env python3
"""Validate active-motion transition captures and compare display callback timing.

Usage: python3 Tools/summarize-motion-performance.py BEFORE.json AFTER.json
These are simulator callback intervals, not GPU-presented frame rates.
"""
import json
import statistics
import sys
from pathlib import Path


def summarize(path):
    samples = json.loads(Path(path).read_text())
    result = {}
    for phase in ("enter", "exit"):
        rows = [sample for sample in samples if sample["phase"] == phase]
        if len(rows) != 5:
            raise ValueError(f"{path}: expected five {phase} cycles, got {len(rows)}")
        if any(row["motionUpdates"] == 0 or row.get("maxDepthMeters", 0) <= 0 or not row["intervalsMS"] for row in rows):
            raise ValueError(f"{path}: every {phase} cycle must include active motion and nonzero perspective depth")
        intervals = sorted(value for row in rows for value in row["intervalsMS"])
        result[phase] = {
            "cycles": len(rows),
            "callbacks": len(intervals),
            "motionUpdates": sum(row["motionUpdates"] for row in rows),
            "medianMS": round(statistics.median(intervals), 2),
            "p95MS": round(intervals[int(0.95 * (len(intervals) - 1))], 2),
            "maxMS": round(max(intervals), 2),
        }
    return result


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    before, after = map(summarize, sys.argv[1:])
    for phase in before:
        reduction = 100 * (1 - after[phase]["medianMS"] / before[phase]["medianMS"])
        print(f"{phase}: median {before[phase]['medianMS']} → {after[phase]['medianMS']} ms "
              f"({reduction:.1f}% lower); p95 {before[phase]['p95MS']} → {after[phase]['p95MS']} ms; "
              f"motion updates {after[phase]['motionUpdates']}")
