"""Only synthetic handoff manifests and fake byte checkpoints used in CI."""
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from trainer_handoff_gate import (
    validate_metadata, artifact_sha256, check_runner_identity,
    compute_policy_sha256, validate_compute_policy
)

SHA = "0" * 64


def template():
    return {
        "schema": "eclipse.trainer.handoff.v2",
        "training_revision": "R29",
        "family": "astra",
        "proposed_generation": "1.1",
        "checkpoint_sha256": SHA,
        "checkpoint_format": "eclipse-policy",
        "provenance_sha256": "f"*64,
        "privacy_policy": "LOCAL_ONLY",
        "repeated_tactics_preserved": True,
        "independent_verified_game_groups": 234,
        "augmentation_excluded_from_game_count": True,
        "compute_policy": {
            "mode": "adaptive", "max_wall_time_ms": None, "max_nodes": None,
            "max_depth": 12, "root_width": 60, "reply_width": 35,
            "continuation_width": 24, "forced_line_depth": 10,
            "candidate_radius": 3
        }
    }


class TrainerHandoffTests(unittest.TestCase):
    def test_revision_is_not_automatically_a_released_model(self):
        result = validate_metadata(template())
        self.assertEqual(result["training_revision"], "R29")
        self.assertEqual(result["release_candidate_id"], "eclipse-1.1-astra")
        self.assertFalse(result["strength_noninferiority_verified"])
        self.assertFalse(result["production_promotion_authorized"])

    def test_private_training_must_preserve_independent_counts(self):
        for field, value in [
            ("privacy_policy", "public"),
            ("repeated_tactics_preserved", False),
            ("augmentation_excluded_from_game_count", False),
            ("independent_verified_game_groups", 0),
            ("training_revision", "pull-request-29"),
            ("compute_policy", {"mode": "adaptive", "max_wall_time_ms": 5700}),
        ]:
            m=template()
            m[field]=value
            with self.subTest(field=field),self.assertRaises(ValueError):
                validate_metadata(m)
        m=template()
        m["raw_actions"]=[0,1,2]
        with self.assertRaises(ValueError):
            validate_metadata(m)

    def test_trainer_owns_optional_wall_time_and_node_ceilings(self):
        model = template()
        verified = validate_metadata(model)
        self.assertTrue(verified["trainer_open_ended_wall_time"])
        self.assertEqual(len(verified["compute_policy_sha256"]), 64)
        model["compute_policy"] = {**model["compute_policy"],
            "mode": "budgeted", "max_wall_time_ms": 131071,
            "max_nodes": 15_000_000, "max_depth": 15}
        self.assertTrue(validate_metadata(model)["metadata_schema_valid"])
        for value in (0, -2, True, "5700"):
            bad = {**model["compute_policy"], "max_wall_time_ms": value}
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_compute_policy(bad)

    def test_checkpoint_hash_and_loaded_identity_enforced(self):
        with tempfile.TemporaryDirectory() as t:
            folder=Path(t)
            checkpoint=folder/"synthetic-policy.bin"
            checkpoint.write_bytes(b"synthetic checkpoint NOT real user model")
            digest=artifact_sha256(checkpoint)
            manifest=template()
            manifest["checkpoint_sha256"]=digest
            runner=folder/"synthetic-runner"
            runner.write_text(
                "#!/usr/bin/env python3\nimport json,sys\n"
                "print(json.dumps({"
                "'schema':'eclipse.loaded-checkpoint-identity.v1',"
                "'training_revision':'R29',"
                "'family':'astra',"
                f"'checkpoint_sha256':'{digest}',"
                f"'compute_policy_sha256':'{compute_policy_sha256(manifest['compute_policy'])}',"
                "'checkpoint_loaded':True}))\n"
            )
            os.chmod(runner,0o755)
            check_runner_identity(runner,manifest)
            manifest["checkpoint_sha256"]="1"*64
            with self.assertRaises(ValueError):
                check_runner_identity(runner,manifest)
            self.assertNotEqual(artifact_sha256(checkpoint),manifest["checkpoint_sha256"])


if __name__=="__main__":
    unittest.main()
