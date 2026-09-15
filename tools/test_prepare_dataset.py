import csv
import tempfile
import unittest
from pathlib import Path

from prepare_dataset import FEATURES, prepare


class PrepareDatasetTests(unittest.TestCase):
    def write_dataset(self, path: Path, frame_count: int = 50) -> None:
        fields = ["session_id", "participant_id", "label", "frame_index", "timestamp", *FEATURES]
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            for participant, label in (("primary", "bounce"), ("guest", "idle")):
                for frame in range(frame_count):
                    row = {
                        "session_id": f"{participant}-{label}",
                        "participant_id": participant,
                        "label": label,
                        "frame_index": frame,
                        "timestamp": frame / 100,
                    }
                    row.update({feature: frame / 1000 for feature in FEATURES})
                    writer.writerow(row)

    def test_splits_complete_sessions_by_participant(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "swings.csv"
            self.write_dataset(source)
            summary = prepare(source, root / "output")
            self.assertEqual(summary["total_sessions"], 2)
            self.assertTrue((root / "output/Training/bounce/primary-bounce.csv").exists())
            self.assertTrue((root / "output/Testing/idle/guest-idle.csv").exists())

    def test_rejects_incomplete_recording(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            source = root / "swings.csv"
            self.write_dataset(source, frame_count=49)
            with self.assertRaisesRegex(ValueError, "frames 0 through 49"):
                prepare(source, root / "output")


if __name__ == "__main__":
    unittest.main()
