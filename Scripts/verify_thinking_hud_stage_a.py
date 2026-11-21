#!/usr/bin/env python3
"""Issue #50 Stage A: prevent fake search data or VeilLink layout regressions.

Source guards are not a substitute for real iOS XCTest or performance tests.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Apps/iOS/Gomoku"

def verify():
    home = (APP / "InstrumentHomeView.swift").read_text()
    hud = (APP / "Visualization/EclipseThinkingHUDView.swift").read_text()
    state = (APP / "NativeEclipse/EclipseThinkingHUDSnapshot.swift").read_text()
    controller = (APP / "NativeEclipse/NativeGomokuAppController.swift").read_text()
    adapter = (APP / "NativeEclipse/EclipseCppProductionAdapter.swift").read_text()
    bot = (APP / "NativeEclipse/GomokuBot.swift").read_text()
    original = (APP / "Visualization/VeilEclipseRuntimeInstruments.swift").read_text()

    assert home.count("VeilEclipseRuntimeInstruments(") == 1
    assert home.count("EclipseThinkingHUDView(engine: engine)") == 1
    assert home.count('accessibilityIdentifier("gomoku.eclipse.runtime-source-card")') == 1
    assert "VStack(spacing: 14)" in home
    assert ".background(VeilAmbientBackground())" in home
    assert "struct VeilEclipseRuntimeInstruments: View" in original
    assert "Menu {" in hud and 'case compact, professional, developer' in hud
    assert "expanded.toggle()" in hud
    assert "scenePhase != .active ? 30" in hud
    assert "ProcessInfo.processInfo.isLowPowerModeEnabled" in hud
    assert "engine.thinkingHUDSnapshot()" in hud
    assert "completedDepth.map" in hud and "visitedNodes.map" in hud
    assert "未提供" in hud
    assert "正式对局：落子前禁止显示" in hud
    assert "候选评分、热力图、PV" in hud
    assert "withAnimation" not in hud
    assert "Canvas(" not in hud
    assert "ProgressView(value:" not in hud

    assert "static let version = 1" in state
    assert "var permitsUncommittedCandidates" in state
    assert "self != .formal" in state
    assert "Int32(EG_SEARCH_REASON_TIME_LIMIT)" in state
    assert "elapsedMilliseconds >= 500" in state

    assert "searchStartedUptime = ProcessInfo.processInfo.systemUptime" in controller
    assert "uptime: TimeInterval = ProcessInfo.processInfo.systemUptime" in controller
    assert "lastThinkingRun = activeThinkingRun" in controller
    assert "activeThinkingRun = nil" in controller
    assert "EclipseCppProductionAdapter.make(" in controller
    assert "let usingCpp = cppRuntime != nil && verifiedTrainer != nil" in controller
    assert "checkpointSHA256: usingCpp ? verifiedTrainer?.checkpointSHA256 : nil" in controller
    assert "GomokuLearningRepertoire.build(" in controller
    assert "run.search.reason" in adapter
    assert "nativeStopReason: Int32? = nil" in bot
    assert "score: 0, // C ABI V2 does not expose normalized evaluation score." in adapter
    assert "winProbability" not in hud
    print("ECLIPSE THINKING HUD STAGE A source/identity/privacy/VeilLink contract PASS")

if __name__ == "__main__":
    verify()
