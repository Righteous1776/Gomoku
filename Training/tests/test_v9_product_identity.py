"""ECLIPSE V9 Astra/Sol product identity — independently validate REAL file bytes.

No private .vltrain histories are used. This is a naming + provenance check,
NOT a model promotion or claim about trained Swift 6x game strength.
"""
import hashlib
import json
from pathlib import Path
import re
import unittest

REPO = Path(__file__).resolve().parents[2]
HANDOFF = REPO / "Training/Handoffs/V9"


class V9AstraSolProductIdentityTests(unittest.TestCase):
    def test_same_generation_distinct_v9_weights_and_releasability_honest(self):
        product = json.loads((HANDOFF / "product-identity.json").read_text())
        receipt = json.loads((HANDOFF / "artifact-receipt.json").read_text())
        swift_catalog = (
            REPO / "Apps/iOS/Gomoku/NativeEclipse/EclipseModelCatalog.swift"
        ).read_text()

        self.assertEqual(product["schema"], "eclipse.product-generation-identity.v1")
        self.assertEqual(product["product_generation"], "2.0")
        self.assertEqual(product["model_lineage"], "V9")
        self.assertEqual(product["product_state"], "NAMED_RESEARCH_CANDIDATES_NOT_RELEASED")
        self.assertFalse(product["compute_policy_is_version_number"])
        models = product["models"]
        self.assertEqual({x["full_name"] for x in models},
                         {"ECLIPSE 2.0 Astra", "ECLIPSE 2.0 Sol"})
        self.assertEqual({x["product_id"] for x in models},
                         {"eclipse-2.0-astra", "eclipse-2.0-sol"})
        self.assertEqual({x["internal_training_revision"] for x in models}, {"V9"})
        self.assertEqual({x["n_features"] for x in models}, {26})
        self.assertEqual({x["trees"] for x in models}, {160, 314})
        self.assertEqual(len({x["weights_sha256"] for x in models}), 2)
        self.assertEqual(
            {x["weights_sha256"] for x in models},
            {
                "d50190d02bf6ebd6f447d84a2920184964ac9cff1dcc0712b0076cec326a177d",
                "074140fa99d52143ce3b887a553f1f11586973096baaada6476f97004e4b4fdd",
            }
        )
        # Version 1.x remains a distinct archived release, NEVER rewritten.
        for historical in ("eclipse-1.0-astra", "eclipse-1.0-sol",
                           "eclipse-1.0-terra", "eclipse-1.0-luna"):
            self.assertIn(f' = "{historical}"', swift_catalog)
        self.assertIn('case "eclipse-1.2-astra"', swift_catalog)
        self.assertIn('case "eclipse-1.1-sol"', swift_catalog)
        self.assertIn("featuredIncludingVerified", swift_catalog)
        self.assertIn("requiresVerifiedCheckpoint", swift_catalog)
        self.assertTrue(any(x["role"] == "distilled_lightweight" and
                            x["trained_from_family"] == "Astra" and
                            x["distinct_weights"] for x in models))
        self.assertTrue(all(not x["production_loaded"] for x in models))

        received = {
            (f["family"], f["internal_version"]): f
            for f in receipt["model_checkpoints"]
        }
        for model in models:
            with self.subTest(name=model["full_name"]):
                relative_path = Path(model["weights_path"])
                self.assertEqual(relative_path.parts[:2], ("source", "models"))
                file = HANDOFF / relative_path
                data = file.read_bytes()  # full real checkpoint; not metadata only
                self.assertEqual(len(data), model["weights_bytes"])
                digest = hashlib.sha256(data).hexdigest()
                self.assertEqual(digest, model["weights_sha256"])
                self.assertIn(b"max_feature_idx=25\n", data[:500])
                self.assertIn(b"objective=lambdarank\n", data[:500])
                self.assertEqual(len(re.findall(rb"(?m)^Tree=[0-9]+\r?$", data)),
                                 model["trees"])
                family = model["role"] == "flagship" and "astra" or "sol"
                self.assertEqual(
                    received[(family, "V9")]["sha256"], digest
                )
                self.assertIn(f' = "{model["product_id"]}"', swift_catalog)
                self.assertIn(f'return "{model["display_name"]}"', swift_catalog)

        self.assertEqual(
            next(x for x in models if x["role"] == "flagship")["release_gate"],
            "BLOCKED_UNIQUE_MANDATORY_DEFENSE_RANKING_REGRESSION"
        )
        self.assertEqual(
            next(x for x in models if x["role"] == "distilled_lightweight")["release_gate"],
            "RESEARCH_REVIEW_ONLY"
        )


if __name__ == "__main__":
    unittest.main()
