#!/usr/bin/env python3
"""Source contract for the original VeilLink ECLIPSE instrument migration.

Checks original VeilLink LocalAIGameView top-level hierarchy, original
display/material wiring and unchanged native board hit geometry. ECLIPSE
2.0 model controls remain standalone adapters, not aesthetic replacements.
The simulator and physical screenshot gates remain separate.
"""
from pathlib import Path
import hashlib


APP = Path(__file__).resolve().parents[1] / "Apps/iOS/Gomoku"
PATHS = {
    "home": "InstrumentHomeView.swift",
    "board": "BoardInstrumentView.swift",
    "controller": "NativeEclipse/NativeGomokuAppController.swift",
    "identity": "Visualization/VeilEclipseIdentityAndTrace.swift",
    "appearance": "DesignSystem/AppearanceTheme.swift",
    "runtime": "Visualization/VeilEclipseRuntimeInstruments.swift",
    "thought": "Visualization/VeilEclipseBoardThoughtField.swift",
    "console": "Visualization/VeilEclipseComputeConsole.swift",
    "stream": "Visualization/VeilEclipseConsoleStream.swift",
}


def read_sources(app=APP):
    return {name: (app / path).read_text(encoding="utf-8")
            for name, path in PATHS.items()}


def git_blob_sha1(source: str) -> str:
    data = source.encode("utf-8")
    return hashlib.sha1(b"blob " + str(len(data)).encode("ascii") + b"\0" + data).hexdigest()


# Exact blob SHAs from VeilLink main at
# 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32.
UPSTREAM_BLOBS = {
    "thought": "e3c648e49383261c450bd4d6c53ed2a7e8d47ead",
    "console": "ab923f9fd731b1ed66dd64cfcab950be19d6bd42",
    "runtime": "390410ee6a84feb1d4e9374f025715c1aee786f9",
    "stream": "098af4a2ddbf9ac4e7466859e988ee343500c9b0",
}


def evaluate_sources(sources):
    home = sources["home"]
    board = sources["board"]
    controller = sources["controller"]
    identity = sources["identity"]
    appearance = sources["appearance"]
    runtime = sources["runtime"]

    # Compare complete layout rows, not substring positions: "board" is
    # also a prefix of "boardQuickControls".
    layout = home.split("VStack(spacing: 14) {", 1)
    layout_body = layout[1].split(".padding(14)", 1)[0] if len(layout) == 2 else ""
    rows = [line.strip() for line in layout_body.splitlines()]
    hierarchy = [row for row in rows if row in {
        "statusCard", "eclipseIdentity", "boardQuickControls", "board",
        "advancedPanel", "VeilEclipseRuntimeInstruments("
    }]

    # Scope the gesture assertion to the genuine move-impact effect only.
    # Other static decorations must not accidentally satisfy this check.
    pulse_section = board.split(
        "// Original VeilLink R17: a single event-bound impact pulse.", 1
    )
    pulse = pulse_section[1].split("VeilBoardTapSurface(enabled:", 1)[0] \
        if len(pulse_section) == 2 else ""

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
        "original VeilLink runtime instrument is visible between identity and controls":
            home.count("VeilEclipseRuntimeInstruments(") == 1
            and "if showsInstruments {" not in home
            and 'accessibilityIdentifier("gomoku.eclipse.runtime-source-card")' in home
            and "struct VeilEclipseRuntimeInstruments: View" in runtime,
        "native board tap surface":
            "GomokuBoardView(" in home
            and "VeilBoardTapSurface(enabled: enabled)" in board,
        "impact respects reduced motion and cannot intercept taps":
            "!eclipseSessionID.isEmpty && !reduceMotion" in pulse
            and ".allowsHitTesting(false)" in pulse,
        "source-aligned game hierarchy":
            hierarchy == ["statusCard", "eclipseIdentity",
                          "VeilEclipseRuntimeInstruments(",
                          "boardQuickControls", "board", "advancedPanel"]
            and ".background(VeilAmbientBackground())" in home
            and ".veilCard()" in home,
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
        "real VeilLink source widgets are byte-for-byte migrated":
            all(git_blob_sha1(sources[name]) == expected
                for name, expected in UPSTREAM_BLOBS.items()),
        "VeilLink status layout uses original adaptive readout grid":
            "LazyVGrid(" in home
            and "GridItem(.adaptive(minimum: 84), spacing: 8)" in home
            and "statusMetric(\"联网\", \"不需要\")" in home,
        "VeilLink identity uses original copy and measured elapsed clock":
            'Text("VeilLink Native Intelligence")' in identity
            and 'String(format: "%.1fs"' in identity
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
