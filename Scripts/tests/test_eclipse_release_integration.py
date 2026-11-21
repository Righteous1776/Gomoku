import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_eclipse_release_integration import ROOT, check


class CutoverAuditTests(unittest.TestCase):
    def test_current_cplusplus_wiring_is_real_but_training_identity_not_faked(self):
        outcome = check(ROOT)
        self.assertTrue(outcome["architecture_wiring_verified"], outcome["checks"])
        self.assertFalse(outcome["actual_loaded_trainer_checkpoint_attested"])
        self.assertFalse(outcome["trained_swift_strength_noninferiority_verified"])
        self.assertFalse(outcome["signed_ipa_installed_on_real_iphone_verified"])

    def test_missing_or_debug_only_adapter_fails_closed(self):
        import tempfile, shutil
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            paths = (
                "Apps/iOS/Gomoku/NativeEclipse/NativeGomokuAppController.swift",
                "Apps/iOS/Gomoku/NativeEclipse/EclipseCppProductionAdapter.swift",
                "Apps/iOS/Gomoku/NativeEclipse/EclipseTrainerProductionRegistry.swift",
                "Engine/include/eclipse_c_api.h",
                "Engine/src/eclipse_c_api.cpp",
                "Apps/iOS/Gomoku/NativeEclipse/EclipseTrainerComputePolicy.swift",
                "Engine/src/search.cpp", "Engine/src/search.hpp",
                "Engine/tests/test_compute_policy_v2.cpp",
                "Apps/iOS/GomokuTests/EclipseCppProductionRuntimeTests.swift",
                "Apps/iOS/GomokuTests/EclipseTrainerProductionRegistryTests.swift",
                "Arena/trainer_handoff_gate.py", "project.yml"
            )
            for name in paths:
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, p)
            adapter = root / "Apps/iOS/Gomoku/NativeEclipse/EclipseCppProductionAdapter.swift"
            adapter.write_text("#if DEBUG\n"+adapter.read_text()+"\n#endif\n")
            found = check(root)
            self.assertFalse(found["checks"]["release_adapter_not_debug_only"])
            self.assertFalse(found["architecture_wiring_verified"])


if __name__ == "__main__":
    unittest.main()
