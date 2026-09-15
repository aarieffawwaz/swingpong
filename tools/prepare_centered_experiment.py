#!/usr/bin/env python3
"""Create a balanced, peak-aligned dataset experiment without changing swings.csv."""

import argparse
import csv
import math
from collections import defaultdict
from pathlib import Path

FEATURES = ("ua_x", "ua_y", "ua_z", "rr_x", "rr_y", "rr_z", "g_x", "g_y", "g_z")
LABELS = ("bounce", "adjust", "idle")
WINDOW = 25
PRE_PEAK = 10


def magnitude(row: dict[str, str]) -> float:
    return math.sqrt(sum(float(row[column]) ** 2 for column in FEATURES[:3]))


def evenly_spaced(items: list, count: int) -> list:
    if len(items) <= count:
        return items
    indices = [round(index * (len(items) - 1) / (count - 1)) for index in range(count)]
    return [items[index] for index in indices]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists() and any(args.output.iterdir()):
        parser.exit(1, f"Output folder is not empty: {args.output}\n")

    sessions = defaultdict(list)
    with args.csv.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            sessions[row["session_id"]].append(row)

    valid = defaultdict(list)
    for session, rows in sessions.items():
        rows.sort(key=lambda row: int(row["frame_index"]))
        peak = max(range(len(rows)), key=lambda index: magnitude(rows[index]))
        start = peak - PRE_PEAK
        end = start + WINDOW
        if start >= 0 and end <= len(rows):
            valid[rows[0]["label"]].append((session, rows[start:end]))

    per_class = min(len(valid[label]) for label in LABELS)
    for label in LABELS:
        folder = args.output / label
        folder.mkdir(parents=True, exist_ok=True)
        for session, rows in evenly_spaced(valid[label], per_class):
            with (folder / f"{session}.csv").open("w", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(handle, fieldnames=FEATURES)
                writer.writeheader()
                writer.writerows({feature: row[feature] for feature in FEATURES} for row in rows)

    print(f"Centered dataset ready: {per_class} recordings per class, {WINDOW} frames each")
    print(f"Peak is at frame {PRE_PEAK}")


if __name__ == "__main__":
    main()
