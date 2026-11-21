"""Synthetic-only tests; never commit owner/player games as fixtures."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "tactical_evidence.py"
spec = importlib.util.spec_from_file_location("tactical_evidence", MODULE_PATH)
import sys
sys.path.insert(0, str(MODULE_PATH.parent))
audit_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit_module)


def game(moves):
    return {"schema": "eclipse.selfplay.v1", "rules": "freestyle-15",
            "winner": 1, "moves": moves}


class TacticalEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.folder = TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name) / "games.jsonl"

    def write(self, records):
        self.path.write_text(
            "".join(json.dumps(record) + "\n" for record in records),
            encoding="utf-8"
        )

    def test_exact_repetition_is_retained_not_deduplicated(self):
        line = game([0, 15, 1, 16, 2, 17, 3, 18, 4])
        another = game([10, 25, 11, 26, 12, 27, 13, 28, 14])
        self.write([line, another, line])
        result = audit_module.audit(self.path, prefix_plies=4)
        self.assertEqual(result["records_retained"], 3)
        self.assertEqual(result["exact_ordered_sequences"], 2)
        self.assertEqual(result["extra_exact_occurrences"], 1)
        self.assertEqual(result["repeated_exact_groups"], 1)
        self.assertEqual(result["repeated_exact_examples"][0]["occurrences"], 2)
        self.assertEqual(result["policy"]["duplicates_removed"], 0)
        self.assertNotIn("moves", json.dumps(result))

    def test_prefix_keeps_move_order(self):
        a = game([0, 15, 1, 16, 2, 17, 3, 18, 4])
        # This is a DIFFERENT order and a distinct game, even if parts
        # of the final stone placement are the same.
        b = game([1, 15, 0, 16, 2, 17, 3, 18, 4])
        self.write([a, b])
        result = audit_module.audit(self.path, prefix_plies=4)
        self.assertEqual(result["ordered_prefix_groups"], 2)

    def test_invalid_game_fails_closed(self):
        self.write([game([0, 15, 0])])
        with self.assertRaisesRegex(ValueError, "line 1"):
            audit_module.audit(self.path)

    def test_empty_game_file_is_error(self):
        self.path.write_text("", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "empty dataset"):
            audit_module.audit(self.path)

    def test_hashes_stable_and_no_raw_moves_in_report(self):
        line = game([0, 15, 1, 16, 2, 17, 3, 18, 4])
        self.write([line])
        first = audit_module.audit(self.path)
        second = audit_module.audit(self.path)
        self.assertEqual(first, second)
        self.assertEqual(len(first["source_sha256"]), 64)


if __name__ == "__main__":
    unittest.main()
