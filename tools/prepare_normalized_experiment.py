#!/usr/bin/env python3
"""Prepare a leakage-resistant, normalized Create ML activity dataset.

The source CSV is never changed. Complete recordings are assigned to either
Training or Validation before normalization statistics are calculated.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path

FEATURES = ("ua_x", "ua_y", "ua_z", "rr_x", "rr_y", "rr_z", "g_x", "g_y", "g_z")
LABELS = ("bounce", "adjust", "idle")
FRAME_COUNT = 50
VALIDATION_EVERY = 5


def smooth(values: list[list[float]]) -> list[list[float]]:
    """Apply a small zero-phase filter that can be reproduced on a saved window."""
    result: list[list[float]] = []
    for index, current in enumerate(values):
        previous = values[max(0, index - 1)]
        following = values[min(len(values) - 1, index + 1)]
        result.append([
            0.25 * previous[column] + 0.5 * current[column] + 0.25 * following[column]
            for column in range(len(FEATURES))
        ])
    return result


def load_sessions(source: Path) -> dict[str, list[tuple[str, list[list[float]]]]]:
    sessions: dict[str, list[dict[str, str]]] = defaultdict(list)
    with source.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        required = {"session_id", "label", "frame_index", *FEATURES}
        missing = required.difference(reader.fieldnames or [])
        if missing:
            raise ValueError("Missing CSV columns: " + ", ".join(sorted(missing)))
        for row in reader:
            sessions[row["session_id"]].append(row)

    by_label: dict[str, list[tuple[str, list[list[float]]]]] = defaultdict(list)
    for session_id, rows in sessions.items():
        rows.sort(key=lambda row: int(row["frame_index"]))
        labels = {row["label"] for row in rows}
        indices = [int(row["frame_index"]) for row in rows]
        if len(labels) != 1 or next(iter(labels)) not in LABELS:
            raise ValueError(f"Session {session_id} has an invalid or mixed label")
        if len(rows) != FRAME_COUNT or indices != list(range(FRAME_COUNT)):
            raise ValueError(f"Session {session_id} must contain frames 0 through 49")
        values = [[float(row[feature]) for feature in FEATURES] for row in rows]
        if not all(math.isfinite(value) for frame in values for value in frame):
            raise ValueError(f"Session {session_id} contains a non-finite feature")
        by_label[next(iter(labels))].append((session_id, smooth(values)))
    return by_label


def split_sessions(by_label: dict[str, list[tuple[str, list[list[float]]]]]):
    training: list[tuple[str, str, list[list[float]]]] = []
    validation: list[tuple[str, str, list[list[float]]]] = []
    for label in LABELS:
        recordings = by_label[label]
        if len(recordings) < VALIDATION_EVERY:
            raise ValueError(f"Not enough {label} recordings for a validation split")
        for index, (session_id, values) in enumerate(recordings):
            target = validation if index % VALIDATION_EVERY == VALIDATION_EVERY - 1 else training
            target.append((label, session_id, values))
    return training, validation


def normalization(training: list[tuple[str, str, list[list[float]]]]):
    frames = [frame for _, _, recording in training for frame in recording]
    means = [sum(frame[column] for frame in frames) / len(frames) for column in range(len(FEATURES))]
    variances = [
        sum((frame[column] - means[column]) ** 2 for frame in frames) / len(frames)
        for column in range(len(FEATURES))
    ]
    deviations = [math.sqrt(variance) for variance in variances]
    if any(deviation < 1e-9 for deviation in deviations):
        raise ValueError("A feature has no useful variation")
    return means, deviations


def write_split(
    destination: Path,
    split: str,
    recordings: list[tuple[str, str, list[list[float]]]],
    means: list[float],
    deviations: list[float],
) -> dict[str, int]:
    counts = {label: 0 for label in LABELS}
    for label, session_id, values in recordings:
        folder = destination / split / label
        folder.mkdir(parents=True, exist_ok=True)
        with (folder / f"{session_id}.csv").open("w", newline="", encoding="utf-8") as handle:
            writer = csv.writer(handle)
            writer.writerow(FEATURES)
            for frame in values:
                writer.writerow([
                    f"{(frame[column] - means[column]) / deviations[column]:.8f}"
                    for column in range(len(FEATURES))
                ])
        counts[label] += 1
    return counts


def prepare(source: Path, destination: Path) -> dict:
    if destination.exists() and any(destination.iterdir()):
        raise ValueError(f"Output folder is not empty: {destination}")
    by_label = load_sessions(source)
    training, validation = split_sessions(by_label)
    means, deviations = normalization(training)
    report = {
        "source": str(source.resolve()),
        "frame_count": FRAME_COUNT,
        "sample_rate_hz": 100,
        "filter": "three-point 0.25/0.50/0.25 smoothing with replicated edges",
        "validation_rule": "every fifth complete recording within each label",
        "features": list(FEATURES),
        "means": dict(zip(FEATURES, means)),
        "standard_deviations": dict(zip(FEATURES, deviations)),
        "counts": {
            "Training": write_split(destination, "Training", training, means, deviations),
            "Validation": write_split(destination, "Validation", validation, means, deviations),
        },
    }
    (destination / "preprocessing-report.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("csv", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = prepare(args.csv, args.output)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Dataset preparation failed: {error}\n")
    print(json.dumps(report["counts"], indent=2))


if __name__ == "__main__":
    main()
