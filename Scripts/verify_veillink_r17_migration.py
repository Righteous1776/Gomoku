#!/usr/bin/env python3
"""Verify literal VeilLink@0e4b51e UI assets plus active R17 ABI wiring.

This is SOURCE INTEGRITY only, never a substitute for iOS XCTest or hardware.
No local player archives or training evidence are read.
"""
from pathlib import Path
import hashlib

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "Apps/iOS/Gomoku"

# Original blob SHAs from Righteous1776/VeilLink@0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32.
ORIGINAL_R17_UI = {
    "Visualization/VeilEclipseRuntimeInstruments.swift":
        "390410ee6a84feb1d4e9374f025715c1aee786f9",
    "Visualization/VeilEclipseComputeConsole.swift":
        "ab923f9fd731b1ed66dd64cfcab950be19d6bd42",
    "Visualization/VeilEclipseConsoleStream.swift":
        "098af4a2ddbf9ac4e7466859e988ee343500c9b0",
    "Visualization/VeilEclipseBoardThoughtField.swift":
        "e3c648e49383261c450bd4d6c53ed2a7e8d47ead",
}

def git_blob_sha(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()

def check():
    for relative, expected in ORIGINAL_R17_UI.items():
        path = UI / relative
        actual = git_blob_sha(path.read_bytes())
        assert actual == expected, (
            f"Original VeilLink R17 UI byte drift: {relative}\n"
            f"expected {expected} but found {actual}"
        )

    main = (UI / "InstrumentHomeView.swift").read_text(encoding="utf8")
    c_header = (ROOT / "Engine/include/eclipse_c_api.h").read_text(encoding="utf8")
    c_implementation = (ROOT / "Engine/src/eclipse_c_api.cpp").read_text(encoding="utf8")
    swift_bridge = (UI / "NativeEclipse/EclipseCppProductionAdapter.swift").read_text(encoding="utf8")
    controller = (UI / "NativeEclipse/NativeGomokuAppController.swift").read_text(encoding="utf8")
    board = (UI / "BoardInstrumentView.swift").read_text(encoding="utf8")

    for symbol in ("EGComputePolicyV2", "EGComputeRunV2",
                   "eg_analyze_compute_policy_v2", "eg_cancel_search_v2"):
        assert symbol in c_header, f"R17 C ABI missing: {symbol}"
    assert "run.search.completed_depth" not in c_implementation or "snapshot.search.completed_depth" in c_implementation
    assert "snapshot.applied_policy = *policy" in c_implementation
    assert "e->cancelled.store(true" in c_implementation
    assert "eg_analyze_compute_policy_v2(" in swift_bridge
    assert "eg_cancel_search_v2(engine)" in swift_bridge
    assert "run.applied_policy.max_depth == config.max_depth" in swift_bridge
    assert "run.applied_policy.root_width == config.root_width" in swift_bridge
    assert "policy.sha256 == approvedComputePolicySHA256" in swift_bridge
    assert "EclipseCppProductionAdapter.make(" in controller
    assert "rootPolicy: rooted" in controller
    assert "onExploredLine: observer" in controller
    assert "onSearchTrace: metricObserver" in controller
    assert "eclipseMetricsStore.clear()" in controller
    assert "VeilEclipseRuntimeInstruments(" in main
    assert "VeilEclipseIdentityCard(" in main
    assert "VeilEclipseBoardThoughtField(" in board
    assert "VeilBoardTapSurface(enabled: enabled)" in board
    assert "hypot(dx, dy) <= step * 0.52" in board
    assert "private var eclipseRuntime: some View" in main
    assert main.index("                    eclipseIdentity") < main.index("                    eclipseRuntime") < main.index("                    boardQuickControls") < main.index("                    board")
    print("VEILLINK ORIGINAL R17 PARITY: 4 exact UI blobs + native V2/Swift bridge + status/board hierarchy PASS")

if __name__ == "__main__":
    check()
