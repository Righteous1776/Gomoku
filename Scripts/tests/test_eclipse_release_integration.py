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
                "Arena/trainer_handoff_gate.py", "project.yml",
                "Engine/tools/verify_v9_compiled_provenance.py",
                "Engine/tests/test_v9_compiled_binding.cpp",
                "Apps/iOS/Gomoku/Resources/ECLIPSE_ACTIVE_MODELS.json",
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

    def test_missing_v9_manifest_fails_compiled_dual_cutover_gate(self):
        import tempfile, shutil
        # The mandatory two-model manifest must not be optional when the
        # dual-model compiled backend claims a verified production route.
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in (
                "Apps/iOS/Gomoku/NativeEclipse/NativeGomokuAppController.swift",
                "Apps/iOS/Gomoku/NativeEclipse/EclipseCppProductionAdapter.swift",
                "Apps/iOS/Gomoku/NativeEclipse/EclipseTrainerProductionRegistry.swift",
                "Engine/include/eclipse_c_api.h",
                "Engine/src/eclipse_c_api.cpp",
                "Apps/iOS/Gomoku/NativeEclipse/EclipseTrainerComputePolicy.swift",
                "Engine/src/search.cpp", "Engine/src/search.hpp",
                "Engine/tests/test_compute_policy_v2.cpp",
                "Engine/tests/test_v9_compiled_binding.cpp",
                "Engine/tools/verify_v9_compiled_provenance.py",
                "Apps/iOS/GomokuTests/EclipseCppProductionRuntimeTests.swift",
                "Apps/iOS/GomokuTests/EclipseTrainerProductionRegistryTests.swift",
                "Arena/trainer_handoff_gate.py", "project.yml",
            ):
                p = root / name
                p.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / name, p)
            outcome = check(root)
            self.assertFalse(outcome["checks"]["all_required_sources_present"])
            self.assertFalse(outcome["checks"]["production_auto_loads_verified_manifest"])
            self.assertFalse(outcome["architecture_wiring_verified"])


if __name__ == "__main__":
    unittest.main()
