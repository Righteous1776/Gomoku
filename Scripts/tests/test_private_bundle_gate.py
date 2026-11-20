"""Synthetic privacy tests: never load or copy personal owner evidence."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

SCRIPT = Path(__file__).resolve().parents[1] / "check_private_bundle.py"
spec = importlib.util.spec_from_file_location("private_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(gate)


class PrivateBundleTests(unittest.TestCase):
    def test_clean_source_and_empty_app(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            app = root / "Gomoku.app"
            app.mkdir()
            (app / "Info.plist").write_text("test")
            report = gate.verify(root, [app])
            self.assertEqual(report["privacy_profile"], "public-dev")
            self.assertEqual(len(report["artifacts"]), 1)

    def test_private_staging_fails_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            private = root / gate.OWNER_RESOURCE
            private.mkdir(parents=True)
            (private / "owner.data").write_bytes(b"fake-private")
            with self.assertRaises(gate.PrivateBundleError):
                gate.source_preflight(root)

    def test_owner_resource_inside_app_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder) / "Gomoku.app"
            (app / "OwnerPrivate").mkdir(parents=True)
            (app / "OwnerPrivate" / "stuff.bin").write_bytes(b"synthetic")
            with self.assertRaises(gate.PrivateBundleError):
                gate.inspect_artifact(app)

    def test_disguised_valid_envelope_inside_app_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            app = Path(folder) / "Gomoku.app"
            app.mkdir()
            (app / "asset.dat").write_text(json.dumps({
                "format": "veillink.board-learning.export.v1",
                "payload": {"recentGames": []},
            }))
            with self.assertRaises(gate.PrivateBundleError):
                gate.inspect_artifact(app)

    def test_private_ipa_entry_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            ipa = Path(folder) / "Gomoku.ipa"
            with zipfile.ZipFile(ipa, "w") as archive:
                archive.writestr("Payload/Gomoku.app/Resources/OwnerPrivate/archive.bin", "synthetic")
            with self.assertRaises(gate.PrivateBundleError):
                gate.inspect_artifact(ipa)

    def test_disguised_envelope_in_ipa_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            ipa = Path(folder) / "Gomoku.ipa"
            with zipfile.ZipFile(ipa, "w") as archive:
                archive.writestr("Payload/Gomoku.app/data.bin", json.dumps({
                    "format": "veillink.board-learning.export.v1",
                    "payload": {"recentGames": ["synthetic"]},
                }))
            with self.assertRaises(gate.PrivateBundleError):
                gate.inspect_artifact(ipa)

    def test_invalid_artifact_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(gate.PrivateBundleError):
                gate.inspect_artifact(Path(folder) / "does-not-exist.app")


if __name__ == "__main__":
    unittest.main()
