"""ECLIPSE MODEL 3.0 identity audit: real bytes and honest runtime boundaries.

Gomoku application version is 2.0.0. Research weights are R07 34D; their
MODEL version is 3.0 but they do not replace native V9 Astra/Sol 2.0.
This test never reads original user games and does not assert chess strength.
"""
import hashlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT / "Apps/iOS/Gomoku/Resources/ECLIPSE_3_0_RESEARCH_MODELS.json"
SOURCE = ROOT / "Training/research/r07/checkpoints"
MANIFEST = SOURCE / "MODEL_MANIFEST.json"


class Generation3ModelIdentityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = json.loads(APP.read_text(encoding="utf-8"))
        cls.manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))

    def test_version_names_never_replace_real_runtime(self):
        c = self.catalog
        self.assertEqual(c["application_version"], "2.0.0")
        self.assertEqual(c["generation"], "3.0")
        self.assertEqual(c["label"], "ECLIPSE 3.0")
        self.assertEqual(c["flagship_alias_name"], "3.0 Astra")
        self.assertEqual(c["flagship_alias_id"], "eclipse-3.0-astra")
        self.assertEqual(c["flagship_checkpoint_id"], "eclipse-3.0-r07-249")
        self.assertFalse(c["production_enabled"])
        self.assertFalse(c["ios_runtime_loaded"])
        self.assertEqual(c["native_feature_abi"], "34D-r07-compatibility-port-experimental")
        self.assertIn("V9 Astra/Sol 2.0 26D", c["old_runtime_preserved"])
        self.assertFalse(self.manifest["active_in_ios_gomoku"])
        self.assertFalse(self.manifest["active_in_native_v9"])
        self.assertFalse(self.manifest["release_approved"])
        self.assertEqual(self.manifest["product_model_generation"], "3.0")
        self.assertEqual(self.manifest["host_app_version"], "2.0.0")

    def test_five_3_0_checkpoints_match_actual_published_weight_bytes(self):
        c = self.catalog
        source = {f["file"]: f for f in self.manifest["model_files"]}
        self.assertEqual(len(c["checkpoints"]), 5)
        self.assertEqual([x["trees"] for x in c["checkpoints"]],
                         [244, 249, 259, 274, 289])
        aliases = [m for m in c["checkpoints"]
                   if m["id"] == c["flagship_checkpoint_id"]]
        self.assertEqual(len(aliases), 1)
        self.assertEqual(aliases[0]["trees"], 249)
        ids = {entry["id"] for entry in c["checkpoints"]}
        self.assertEqual(len(ids), 5)
        for item in c["checkpoints"]:
            self.assertEqual(item["features"], 34)
            self.assertFalse(item["production_eligible"])
            self.assertTrue(item["id"].startswith("eclipse-3.0-r07-"))
            self.assertEqual(item["research_revision"],
                             "R07-" + str(item["trees"]))
            expected = "eclipse_r07_34d_%s_trees.txt" % item["trees"]
            self.assertEqual(item["source_file"], expected)
            original = source[expected]
            self.assertEqual(item["sha256"], original["sha256"])
            self.assertEqual(item["features"], original["features"])
            self.assertEqual(item["trees"], original["trees"])
            actual = (SOURCE / expected).read_bytes()
            self.assertEqual(hashlib.sha256(actual).hexdigest(),
                             item["sha256"])

    def test_best_candidate_is_still_rejected_by_original_nine_gates(self):
        c = self.catalog
        best = [x for x in c["checkpoints"] if x["trees"] == 249][0]
        self.assertEqual(best["exploratory_gates_passed"], 8)
        self.assertEqual(best["exploratory_gates_total"], 9)
        self.assertFalse(best["production_eligible"])
        metrics = json.loads((ROOT / "Training/research/r07_public_metrics.json")
                             .read_text(encoding="utf-8"))
        self.assertFalse(metrics["gates"]["promoted"])
        self.assertEqual(metrics["gates"]["failed"], ["real40_top1"])


if __name__ == "__main__":
    unittest.main()
