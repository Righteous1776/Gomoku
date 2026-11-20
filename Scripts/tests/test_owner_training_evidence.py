import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "owner_evidence",
    Path(__file__).resolve().parents[1] / "verify_owner_training_evidence.py",
)
evidence = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evidence)


class OwnerTrainingEvidenceTests(unittest.TestCase):
    def test_original_28_records(self):
        report = evidence.audit_bytes(evidence.ARCHIVE.read_bytes())
        self.assertEqual(report["legitimateComplete"], 10)
        self.assertEqual(report["legalIncomplete"], 18)
        self.assertEqual(report["hashedPositionAggregates"], 1205)
        self.assertEqual(report["uniqueComplete"], 10)

    def test_native_seed_has_236_real_unique_games(self):
        data = (evidence.ROOT / "Apps/iOS/Gomoku/Resources/GomokuNativeTrainingSeed.json").read_bytes()
        report = evidence.audit_native_seed(data)
        self.assertEqual(report["legalTerminalRecords"], 2000)
        self.assertEqual(report["distinctCompletedGames"], 236)
        self.assertEqual(report["duplicateGames"], 1764)

    def test_raw_bytes_must_remain_exact(self):
        mutated = evidence.ARCHIVE.read_bytes() + b" "
        with self.assertRaisesRegex(ValueError, "blob changed"):
            evidence.audit_bytes(mutated)

    def test_changed_terminal_label_fails_even_with_recomputed_checksum(self):
        obj = json.loads(evidence.ARCHIVE.read_bytes())
        completed = next(g for g in obj["payload"]["recentGames"]
                         if g["result"] != "unfinished")
        completed["result"] = "unfinished"
        obj["payloadChecksum"] = evidence.fnv1a64(
            evidence.canonical_bytes(obj["payload"])
        )
        with self.assertRaisesRegex(ValueError, "terminal label"):
            evidence.audit_bytes(json.dumps(obj).encode(), enforce_blob=False)


if __name__ == "__main__":
    unittest.main()
