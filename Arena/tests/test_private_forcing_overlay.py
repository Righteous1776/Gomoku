"""Synthetic-only proof-backed local tactical policy cache tests."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from private_forcing_overlay import build_overlay, lookup_verified


class OwnerOnlyOverlayTests(unittest.TestCase):
    def test_compiles_and_revalidates_synthetic_double_threat(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            suite = root / "synthetic.json"
            db = root / "owner-only.sqlite"
            history = [110, 0, 111, 15, 113, 30]
            suite.write_text(json.dumps({
                "report": {"schema": "eclipse.private-forcing-forks.v1"},
                "private_cases": [{
                    "history": history, "side": 1,
                    "proven_moves": [112],
                    "completion_targets": {"112": [109, 114]},
                    "max_within_source_repetitions": 9,
                    "distinct_sources": 2
                }]
            }))
            result = build_overlay(suite, db)
            self.assertEqual(result["counts"]["positions"], 1)
            self.assertEqual(result["counts"]["forcing_moves"], 1)
            self.assertEqual(lookup_verified(db, history), [112])
            self.assertEqual(lookup_verified(db, [112]), [])
            with self.assertRaises(ValueError):
                build_overlay(suite, db)
            self.assertTrue(db.exists(), "failed overwrite attempt must preserve DB")

    def test_rejects_forged_completion_targets_without_writing(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            suite = root / "invalid.json"
            db = root / "must-not-exist.sqlite"
            suite.write_text(json.dumps({
                "report": {"schema": "eclipse.private-forcing-forks.v1"},
                "private_cases": [{
                    "history": [110, 0, 111, 15, 113, 30],
                    "side": 1, "proven_moves": [112],
                    "completion_targets": {"112": [109, 115]},
                    "max_within_source_repetitions": 1,
                    "distinct_sources": 1
                }]
            }))
            with self.assertRaises(ValueError):
                build_overlay(suite, db)
            self.assertFalse(db.exists(), "failed proof may never leave a DB")


if __name__ == "__main__":
    unittest.main()
