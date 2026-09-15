#!/usr/bin/env python3
"""Validate SwingPong's combined CSV and create Create ML label folders."""

from __future__ import annotations

import argparse
import csv
import json
import math
from collections import Counter, defaultdict
from pathlib import Path

FEATURES = ("ua_x", "ua_y", "ua_z", "rr_x", "rr_y", "rr_z", "g_x", "g_y", "g_z")
REQUIRED = ("session_id", "participant_id", "label", "frame_index", "timestamp", *FEATURES)
LABELS = {"bounce", "adjust", "idle"}
FRAME_COUNT = 50


def prepare(source: Path, destination: Path) -> dict:
    if destination.exists() and any(destination.iterdir()):
        raise ValueError(f"Output folder is not empty: {destination}")

    with source.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = [column for column in REQUIRED if column not in (reader.fieldnames or [])]
        if missing:
            raise ValueError("Missing CSV columns: " + ", ".join(missing))
        sessions: dict[str, list[dict[str, str]]] = defaultdict(list)
        for row_number, row in enumerate(reader, start=2):
            session = row["session_id"].strip()
            if not session:
                raise ValueError(f"Row {row_number} has no session_id")
            sessions[session].append(row)

    if not sessions:
        raise ValueError("The CSV contains no recorded sessions")

    counts: Counter[tuple[str, str]] = Counter()
    feature_ranges = {feature: [math.inf, -math.inf] for feature in FEATURES}

    for session, rows in sessions.items():
        labels = {row["label"].strip() for row in rows}
        participants = {row["participant_id"].strip() for row in rows}
        if len(labels) != 1 or not labels.issubset(LABELS):
            raise ValueError(f"Session {session} has an invalid or mixed label")
        if len(participants) != 1 or "" in participants:
            raise ValueError(f"Session {session} has an invalid or mixed participant")

        try:
            ordered = sorted(rows, key=lambda row: int(row["frame_index"]))
            frame_indices = [int(row["frame_index"]) for row in ordered]
        except ValueError as error:
            raise ValueError(f"Session {session} has a non-number frame_index") from error

        if len(ordered) != FRAME_COUNT or frame_indices != list(range(FRAME_COUNT)):
            raise ValueError(f"Session {session} must contain exactly frames 0 through 49")

        for row in ordered:
            for column in ("timestamp", *FEATURES):
                try:
                    value = float(row[column])
                except ValueError as error:
                    raise ValueError(f"Session {session} has a non-number in {column}") from error
                if not math.isfinite(value):
                    raise ValueError(f"Session {session} has a non-finite value in {column}")
                if column in feature_ranges:
                    feature_ranges[column][0] = min(feature_ranges[column][0], value)
                    feature_ranges[column][1] = max(feature_ranges[column][1], value)

        label = next(iter(labels))
        participant = next(iter(participants))
        split = "Testing" if participant == "guest" else "Training"
        output_folder = destination / split / label
        output_folder.mkdir(parents=True, exist_ok=True)
        output_file = output_folder / f"{session}.csv"
        with output_file.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=FEATURES)
            writer.writeheader()
            writer.writerows({feature: row[feature] for feature in FEATURES} for row in ordered)
        counts[(split, label)] += 1

    summary = {
        "source": str(source.resolve()),
        "total_sessions": len(sessions),
        "frame_count_per_session": FRAME_COUNT,
        "features": list(FEATURES),
        "counts": {
            split: {label: counts[(split, label)] for label in sorted(LABELS)}
            for split in ("Training", "Testing")
        },
        "feature_ranges": {
            feature: {"minimum": limits[0], "maximum": limits[1]}
            for feature, limits in feature_ranges.items()
        },
    }
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "validation-report.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare SwingPong motion data for Create ML.")
    parser.add_argument("csv", type=Path, help="The swings.csv exported by the iPhone app")
    parser.add_argument("--output", type=Path, default=Path("TrainingData"), help="New output folder")
    args = parser.parse_args()

    try:
        summary = prepare(args.csv, args.output)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Dataset check failed: {error}\n")

    print(f"Dataset ready: {summary['total_sessions']} valid sessions")
    for split, labels in summary["counts"].items():
        print(f"{split}: " + ", ".join(f"{label}={count}" for label, count in labels.items()))
    print(f"Open this folder in Create ML: {args.output / 'Training'}")


if __name__ == "__main__":
    main()
