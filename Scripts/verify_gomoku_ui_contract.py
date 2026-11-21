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

    # Compare complete layout rows, not substring positions: "board" is
    # also a prefix of "boardQuickControls".
    layout = home.split("LazyVStack(alignment: .leading, spacing: 14) {", 1)
    layout_body = layout[1].split(".padding(14)", 1)[0] if len(layout) == 2 else ""
    rows = [line.strip() for line in layout_body.splitlines()]
    hierarchy = [row for row in rows if row in {
        "statusCard", "eclipseIdentity", "boardQuickControls", "board",
        "advancedPanel"
    }]

    # Scope the gesture assertion to the genuine move-impact effect only.
    # Other static decorations must not accidentally satisfy this check.
    pulse_section = board.split(
        "// Original VeilLink R17: a single event-bound impact pulse.", 1
    )
    pulse = pulse_section[1].split("VeilBoardTapSurface(enabled:", 1)[0] \
        if len(pulse_section) == 2 else ""

    return {
        "one upper ECLIPSE identity": home.count("VeilEclipseIdentityCard(") == 1,
        "original runtime instrument stays folded":
            home.count("VeilEclipseRuntimeInstruments(") == 1
            and "if showsInstruments {" in home
            and "struct VeilEclipseRuntimeInstruments: View" in runtime,
        "native board tap surface":
            "GomokuBoardView(" in home
            and "VeilBoardTapSurface(enabled: enabled)" in board,
        "impact respects reduced motion and cannot intercept taps":
            "!eclipseSessionID.isEmpty && !reduceMotion" in pulse
            and ".allowsHitTesting(false)" in pulse,
        "source-aligned game hierarchy":
            hierarchy == ["statusCard", "eclipseIdentity",
                          "boardQuickControls", "board", "advancedPanel"],
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
            and "timeIntervalSince(started)" in identity,
        "live search branches explicitly opt in":
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
