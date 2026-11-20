#!/usr/bin/env python3
"""Check the owner's instrument UI and opt-in live trace wiring in app sources."""
from pathlib import Path

app = Path(__file__).resolve().parents[1] / "Apps/iOS/Gomoku"
home = (app / "InstrumentHomeView.swift").read_text()
board = (app / "BoardInstrumentView.swift").read_text()
controller = (app / "NativeEclipse/NativeGomokuAppController.swift").read_text()
identity = (app / "Visualization/VeilEclipseIdentityAndTrace.swift").read_text()
appearance = (app / "DesignSystem/AppearanceTheme.swift").read_text()
checks = {
    "single upper console": home.count("VeilEclipseIdentityCard(") == 1
        and "VeilEclipseRuntimeInstruments(" not in home,
    "no landing ripple": all(s not in board for s in ("impactIndex", "impactScale")),
    "original board": "GomokuBoardView(" in home and "VeilBoardTapSurface(" in board,
    "fixed instrument appearance": "let selection: VeilAppearanceSelection = .instrumentAuto" in appearance,
    "actual search clock": "searchStartedAt = Date()" in controller
        and "timeIntervalSince(started)" in identity,
    "live branches opt-in": "Toggle(isOn: $engine.eclipseVisualizationEnabled)" in home
        and "onExploredLine: observer" in controller and "traceStore.record(" in controller,
    "branch lifecycle": controller.count("eclipseTraceStore.clear()") >= 3
        and "scenePhase == .active" in home and "VeilEclipseBoardThoughtField(" in board,
    "analysis navigation": "VeilEclipseTraceSheet(" in home and "VeilEclipseComputeConsole(" in identity,
}
failed = [name for name, valid in checks.items() if not valid]
if failed:
    raise SystemExit("UI contract failed: " + ", ".join(failed))
print(f"GOMOKU R17.2 UI SOURCE CONTRACT PASS ({len(checks)}/{len(checks)})")
