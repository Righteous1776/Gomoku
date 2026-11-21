"""Public-only integrity checks for R07 aggregate results.

These checks validate internal arithmetic and evidence boundaries;
they do NOT independently replay private games, regenerate LightGBM
weights, certify Elo, or replace genuine headless-native chess tests.
"""
import ast
import json
import unittest
from pathlib import Path

METRICS = Path(__file__).resolve().parents[1] / "research" / "r07_public_metrics.json"


class R07PublicEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.m = json.loads(METRICS.read_text(encoding="utf-8"))

    def test_privacy_boundary(self):
        p = self.m["privacy"]
        for field in (
            "includes_private_raw_games", "includes_private_positions",
            "includes_private_test_fixture",
            "includes_private_derived_model_weights",
        ):
            self.assertIs(p[field], False, field)
        self.assertEqual(self.m["status"], "RESEARCH_NOT_PROMOTED")
        self.assertFalse(self.m["gates"]["promoted"])

    def test_counts_do_not_conflate_candidates_and_games(self):
        x = self.m["input_counts"]
        self.assertEqual(
            x["private_train_groups"] + x["public_train_groups"] +
            x["synthetic_train_groups"], x["total_train_groups"]
        )
        self.assertEqual(x["total_train_groups"], 37123)
        self.assertEqual(x["total_candidate_rows"], 666475)
        self.assertGreater(x["total_candidate_rows"], x["total_train_groups"])
        self.assertLessEqual(x["public_exact_unique_games"], x["public_winepy_files"])

    def test_gates_and_static_ranking(self):
        r = self.m["ranking_results"]
        gates = self.m["gates"]
        self.assertEqual(gates["R07_249_passed"], 8)
        self.assertEqual(gates["total"], 9)
        self.assertEqual(gates["failed"], ["real40_top1"])
        self.assertEqual(r["R04"]["private_top1"], r["R07_249"]["private_top1"])
        self.assertLess(r["R07_249"]["real40_top1"], r["R04"]["real40_top1"])
        self.assertEqual(
            r["R07_249"]["synthetic1800_top1"] -
            r["R04"]["synthetic1800_top1"], 2
        )

    def test_research_arena_is_not_elo_or_native(self):
        a = self.m["paired_research_arena"]
        self.assertEqual(a["games"], 2 * a["swapped_openings"])
        self.assertEqual(
            a["wins_r07"] + a["wins_r04"] + a["draws"], a["games"]
        )
        self.assertEqual(
            a["r07_score_rate"],
            (a["wins_r07"] + a["draws"] / 2) / a["games"]
        )
        self.assertEqual(
            a["neutral_pairs"] + a["r07_double_win_pairs"] +
            a["r04_double_win_pairs"], a["swapped_openings"]
        )
        self.assertFalse(a["elo_claimed"])
        self.assertEqual(a["native_v9_games"], 0)
        self.assertLessEqual(a["paired_bootstrap_ci95"][0], 0.5)
        self.assertGreaterEqual(a["paired_bootstrap_ci95"][1], 0.5)

    def test_public_research_sources_parse_without_private_imports(self):
        """Parse source syntax without requiring proprietary inputs or models."""
        root = Path(__file__).resolve().parents[1]
        for name in ("features34.py", "train_r07.py", "arena_ranker_r07.py"):
            source = root / "research" / "r07" / "source" / name
            ast.parse(source.read_text(encoding="utf-8"), filename=str(source))

    def test_model_hashes_are_structurally_verifiable(self):
        lineage = self.m["source_lineage"]
        self.assertEqual(lineage["r04"]["trees"], lineage["r07_base"]["trees"])
        self.assertEqual(lineage["r07_base"]["features"], 34)
        self.assertEqual(lineage["r07_base"]["prediction_delta_256_probe"], 0)
        self.assertEqual(len(lineage["r07_candidates"]), 5)
        for model in lineage["r07_candidates"]:
            self.assertEqual(len(model["sha256"]), 64)
            int(model["sha256"], 16)


if __name__ == "__main__":
    unittest.main()
