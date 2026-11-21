#!/usr/bin/env python3
"""R19 Gomoku cutover architecture and model identity audit.

A green *architecture* result never means the latest training artifact is
loaded or signed for an IPA. Private histories must remain off public CI.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

CONTROLLER = "Apps/iOS/Gomoku/NativeEclipse/NativeGomokuAppController.swift"
PRODUCTION_ADAPTER = "Apps/iOS/Gomoku/NativeEclipse/EclipseCppProductionAdapter.swift"
REGISTRY = "Apps/iOS/Gomoku/NativeEclipse/EclipseTrainerProductionRegistry.swift"
C_HEADER = "Engine/include/eclipse_c_api.h"
C_IMPL = "Engine/src/eclipse_c_api.cpp"
POLICY = "Apps/iOS/Gomoku/NativeEclipse/EclipseTrainerComputePolicy.swift"
PROJECT = "project.yml"


def check(root: Path) -> dict:
    required = (
        CONTROLLER, PRODUCTION_ADAPTER, REGISTRY, C_HEADER, C_IMPL,
        POLICY, PROJECT, "Engine/src/search.cpp", "Engine/src/search.hpp",
        "Engine/tests/test_compute_policy_v2.cpp",
        "Apps/iOS/GomokuTests/EclipseCppProductionRuntimeTests.swift",
        "Apps/iOS/GomokuTests/EclipseTrainerProductionRegistryTests.swift",
        "Arena/trainer_handoff_gate.py",
        "Engine/tools/verify_v9_compiled_provenance.py",
        "Engine/tests/test_v9_compiled_binding.cpp",
        "Apps/iOS/Gomoku/Resources/ECLIPSE_ACTIVE_MODELS.json",
    )
    present = all((root / path).is_file() for path in required)
    src = {
        path: (root / path).read_text(encoding="utf8")
        if (root / path).is_file() else ""
        for path in required
    }
    model_catalog = {}
    try:
        model_catalog = json.loads(
            src["Apps/iOS/Gomoku/Resources/ECLIPSE_ACTIVE_MODELS.json"]
        )
    except (ValueError, TypeError):
        pass
    catalog_records = model_catalog.get("models", [])
    catalog_ids = {
        m.get("model_id") for m in catalog_records if isinstance(m, dict)
    } if isinstance(catalog_records, list) else set()
    checks = {
        "all_required_sources_present": present,
        "release_adapter_not_debug_only":
            re.search(r"(?m)^\s*#if\s+DEBUG\b", src[PRODUCTION_ADAPTER]) is None,
        "official_controller_routes_to_cpp":
            "EclipseCppProductionAdapter.make(" in src[CONTROLLER]
            and "cppRuntime.decide(" in src[CONTROLLER],
        "cpp_abiv2_used":
            "eg_analyze_compute_policy_v2(" in src[PRODUCTION_ADAPTER]
            and "EGComputePolicyV2" in src[C_HEADER],
        "runtime_checkpoint_must_be_loaded":
            (
                "loadedCheckpointSHA256() == trainer.checkpointSHA256"
                in src[PRODUCTION_ADAPTER]
            ) or all(x in src[PRODUCTION_ADAPTER] for x in (
                "eg_select_compiled_v9_model_v4",
                "eg_active_compiled_v9_sha256_v4",
                "Self.bindCheckpoint(created, model: model,",
                "Self.activeCheckpointSHA256(of: created, model: model) == checkpointSHA256",
                "eg_load_astra_r07_v5(",
            )) and all(x in src[C_HEADER] and x in src[C_IMPL]
                       for x in (
                "eg_select_compiled_v9_model_v4",
                "eg_active_compiled_v9_sha256_v4",
            )) and (
                "verify_v9_compiled_provenance.py"
                in src["Engine/tools/verify_v9_compiled_provenance.py"]
                or "compiled, compiled_roots" in
                src["Engine/tools/verify_v9_compiled_provenance.py"]
            ),
        "checkpoint_identity_api_exposed":
            "eg_active_trained_checkpoint_sha256_v2" in src[C_HEADER]
            and "eg_active_trained_checkpoint_sha256_v2" in src[C_IMPL],
        "manifest_must_match_actual_cpp":
            "cppLoadedCheckpointSHA256: " in src[REGISTRY]
            and "actuallyLoaded == manifest.checkpointSHA256" in src[REGISTRY],
        "production_auto_loads_verified_manifest":
            "EclipseTrainerProductionRegistry.loadFromBundle()" in src[CONTROLLER]
            or (
                "EclipseTrainerProductionRegistry.loadAllFromBundle()" in
                src[CONTROLLER]
                and "resolveCatalog(" in src[REGISTRY]
                and "ECLIPSE_ACTIVE_MODELS" in src[REGISTRY]
                and model_catalog.get("schema")
                    == "eclipse.production-model-catalog.v2"
                and catalog_ids == {
                    "eclipse-2.0-astra", "eclipse-2.0-sol"
                }
                and len(catalog_records) == 2
                and "featuredIncludingVerified(verifiedSelectableModels)"
                    in src[CONTROLLER]
                and "verifiedTrainerExecutions" in src[CONTROLLER]
            ),
        "original_swift_fallback_present":
            "GomokuBot.chooseMove(" in src[CONTROLLER]
            and "cppFailed:" in src[CONTROLLER],
        "actual_backend_telemetry":
            "lastExecutionBackend" in src[CONTROLLER],
        "trainer_decides_budget":
            "maxWallTimeMilliseconds ?? 0" in src[POLICY]
            and "maxNodes ?? 0" in src[POLICY],
        "real_ios_cpp_compiled":
            all(x in src[PROJECT] for x in (
                "Engine/src/search.cpp", "Engine/src/board.cpp",
                "Engine/src/eclipse_c_api.cpp"
            )),
        "private_training_not_in_prod_manifest":
            "private_match_history" not in src[REGISTRY]
            and "Set(object.keys)" in src[REGISTRY],
    }
    # Detect the current frozen prototype without claiming a trained model.
    match = re.search(
        r'int eg_active_trained_checkpoint_sha256_v2\('
        r'[^)]*\)\s*\{([^}]*)\}', src[C_IMPL], flags=re.S
    )
    stub = bool(match and "return 0;" in match.group(1))
    report = {
        "schema": "eclipse.r19.production-integration-audit.v1",
        "scope": "release-compiled C++ architecture; never personal data",
        "checks": checks,
        "architecture_wiring_verified": all(checks.values()),
        "training_agent_checkpoint_compiled_in_this_source":
            not stub if match else False,
        "actual_loaded_trainer_checkpoint_attested": False,
        "trained_swift_strength_noninferiority_verified": False,
        "signed_ipa_installed_on_real_iphone_verified": False,
        "promotion_note": "Architecture is not a model/checkpoint/strength/release claim.",
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = check(args.root)
    body = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(body, encoding="utf8")
    print(body, end="")
    return 0 if result["architecture_wiring_verified"] else 1


if __name__ == "__main__":
    sys.exit(main())