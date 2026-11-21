#!/usr/bin/env python3
"""Source contract for the original VeilLink ECLIPSE instrument migration.

Checks interactive behavior (foldout/gesture isolation), not the old R17.2
blanket prohibition on a genuine, reduced-motion-gated landing pulse.
The iOS simulator and physical screenshot gates remain separate.
"""
from pathlib import Path


APP = Path(__file__).resolve().parents[1] / "Apps/iOS/Gomoku"
PATHS = {
    "home": "InstrumentHomeView.swift",
    "board": "BoardInstrumentView.swift",
    "controller": "NativeEclipse/NativeGomokuAppController.swift",
    "identity": "Visualization/VeilEclipseIdentityAndTrace.swift",
    "appearance": "DesignSystem/AppearanceTheme.swift",
    "runtime": "Visualization/VeilEclipseRuntimeInstruments.swift",
    "materials": "DesignSystem/InstrumentComponents.swift",
    "console": "Visualization/VeilEclipseComputeConsole.swift",
    "thought": "Visualization/VeilEclipseBoardThoughtField.swift",
}


def read_sources(app=APP):
    return {name: (app / path).read_text(encoding="utf-8")
            for name, path in PATHS.items()}


def evaluate_sources(sources):
    home = sources["home"]
    board = sources["board"]
    controller = sources["controller"]
    identity = sources["identity"]
    appearance = sources["appearance"]
    runtime = sources["runtime"]
    materials = sources["materials"]
    console = sources["console"]
    thought = sources["thought"]

    # Compare complete layout rows, not substring positions: "board" is
    # also a prefix of "boardQuickControls".
    layout = home.split("LazyVStack(alignment: .leading, spacing: 12) {", 1)
    layout_body = layout[1].split(".padding(.horizontal, 12)", 1)[0] if len(layout) == 2 else ""
    rows = [line.strip() for line in layout_body.splitlines()]
    hierarchy = [row for row in rows if row in {
        "statusCard", "eclipseIdentity", "boardQuickControls", "board",
        "liveSearchRibbon", "advancedPanel"
    }]

    # The committed last stone is marked statically. No pulsing visual
    # effect is allowed to cause large board redraws or compete with taps.
    board_view_section = home.split("    private var board: some View {", 1)
    board_view = board_view_section[1].split(
        "    private var resultCard: some View {", 1
    )[0] if len(board_view_section) == 2 else ""

    return {
        "unframed board fills narrow screens":
            "GomokuBoardView(" in board_view
            and ".veilCard()" not in board_view
            and ".frame(maxWidth: .infinity)" in board_view
            and 'accessibilityIdentifier("gomoku.instrument.board")' in board_view,
        "wood board retains safe edge taps":
            "let margin = side * 0.055" in board
            and "let step = (side - margin * 2)" in board
            and "VeilBoardTapSurface(enabled: enabled)" in board
            and "hypot(dx, dy) <= step * 0.52" in board,
        "one upper ECLIPSE identity": home.count("VeilEclipseIdentityCard(") == 1,
        "original runtime instrument stays folded":
            home.count("VeilEclipseRuntimeInstruments(") == 1
            and "if showsInstruments {" in home
            and "struct VeilEclipseRuntimeInstruments: View" in runtime,
        "native board tap surface":
            "GomokuBoardView(" in home
            and "VeilBoardTapSurface(enabled: enabled)" in board,
        "static last-move marker replaces board impact animation":
            "// The last committed stone has a static gold dot" in board
            and "withAnimation(" not in board
            and ".animation(" not in board
            and "impactScale" not in board,
        "no fake animated console, only native measured values":
            "VeilEclipseConsoleStream.lines" not in console
            and "TimelineView(" not in console
            and "liveMetrics?.visitedNodes" in console
            and "nodesPerSecond" in console,
        "optional quiet board trace stays disabled by default":
            '?? false' in controller
            and 'by: 0.5' in thought
            and 'searchTrace.snapshot(' in thought
            and "ProcessInfo.processInfo.systemUptime" not in thought,
        "source-aligned game hierarchy":
            hierarchy == ["eclipseIdentity", "boardQuickControls", "board",
                          "liveSearchRibbon", "statusCard", "advancedPanel"],
        "training below board and behind disclosure":
            "if showsAdvanced {" in home
            and "gomoku.training.advanced.toggle" in home
            and "learningCard" in home,
        "narrow-width responsive controls":
            "ViewThatFits(in: .horizontal)" in home
            and "VStack(alignment: .leading, spacing: 10)" in home,
        "fixed instrument theme":
            "let selection: VeilAppearanceSelection = .instrumentAuto" in appearance,
        "real search start timestamp":
            "searchStartedAt = Date()" in controller
            and ("timeIntervalSince(started)" in identity
                 or "timeIntervalSince(started)" in home),
        "live search branch visibility is under owner control":
            "Toggle(isOn: $engine.eclipseVisualizationEnabled)" in home
            and "onExploredLine: observer" in controller
            and "traceStore.record(" in controller,
        "real trace is session-scoped":
            controller.count("eclipseTraceStore.clear()") >= 3
            and "scenePhase == .active" in home
            and "VeilEclipseBoardThoughtField(" in board,
        "analysis is a separate read-only presentation":
            "VeilEclipseTraceSheet(" in home
            and "VeilEclipseComputeConsole(" in identity,
        "wide iPad cockpit and compact split-view fallback":
            "viewport.size.width >= 900" in home
            and "HStack(alignment: .top, spacing: 18)" in home
            and ".frame(maxWidth: 340)" in home
            and "LazyVStack(alignment: .leading, spacing: 12)" in home,
        "responsive live measured telemetry": 
            "liveSearchRibbon" in home
            and 'accessibilityIdentifier("gomoku.eclipse.live-telemetry")' in home
            and 'accessibilityIdentifier("gomoku.eclipse.live-visibility")' in home
            and 'accessibilityIdentifier("gomoku.eclipse.analysis.open")' in home
            and "engine.realSearchMetrics" in home,
        "mechanical detailing is inert and does not shrink board":
            "struct VeilMachinedRim: View" in materials
            and "struct VeilMachinedRivet: View" in materials
            and materials.count(".allowsHitTesting(false)") >= 3
            and "VeilMachinedRivet(" in board
            and "VeilMachinedRim(" in board
            and "VeilInstrumentPlate(" in home
            and "let margin = side * 0.055" in board
            and "hypot(dx, dy) <= step * 0.52" in board,
        "day/night board material is adaptive without changing tap geometry":
            "appearance.isDarkAppearance" in board
            and "RadialGradient(" in board
            and "VeilBoardTapSurface(enabled: enabled)" in board,
        "day/night/system palette remains user selectable":
            'Picker("颜色模式", selection: $appearance.colorMode)' in home
            and all(f"case {mode}" in appearance
                    for mode in ("automatic", "light", "dark")),
    }


def main():
    checks = evaluate_sources(read_sources())
    failures = [label for label, passes in checks.items() if not passes]
    if failures:
        raise SystemExit("ECLIPSE instrument UI contract FAILED:\n- "
                         + "\n- ".join(failures))
    print(f"GOMOKU ECLIPSE UI SOURCE CONTRACT PASS ({len(checks)}/{len(checks)})")


if __name__ == "__main__":
    main()
