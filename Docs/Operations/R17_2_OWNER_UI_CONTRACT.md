# R17.2 owner-corrected standalone Gomoku UI contract

## Implementation in isolated owner feature branch
- Apps/iOS/Gomoku/InstrumentHomeView.swift (provisional iOS shell): single black/orange upper compute console with truthful REAL CLOCK T+, separate bottom status dashboard removed, 15x15 board/buttons remain; SwiftUI font-argument order repaired.
- Apps/iOS/Gomoku/EngineBridge.swift: published actual searchStartedAt, nil on reset and result; immutable result captured before MainActor.run.
- Apps/iOS/Gomoku/BoardInstrumentView.swift: **unchanged**; no expanding wave, rings, moving overlay or hit-testing interceptor.
- Scripts/verify_gomoku_ui_contract.py: source-based FAIL-CLOSED check against reintroduction of owner's rejected elements, independent of Legacy/Original historical archive.

## Original upstream authority
Do not wholesale import VeilLink R17.2 PR #234: owner rejected lower ECLIPSE / 实测仪表 card and 0.65-second landing pulse.
Reference corrected isolated source: VeilLink/integration/v30-eclipse-r17-selective-20261120 at af37b1e90ef77fc0ca0bb176a96d6a43bb234a1d.
Original source snapshot at Legacy/Original remains fixed at 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32 and may contain historical rejected UI **but it is deliberately NOT linked** into the app.

## Explicitly NOT claimed
This patch targets the **C++ experimental shell**. It does not yet compile or run original Swift ECLIPSE, does not import full instrumentAuto theme, or implement seven difficulties/learning/archive/BLE, and is not a signed IPA. The next source-to-adapted lane must extract original Swift semantics and replace the provisional shell after original-source parity approval.

## QA
Run `python3 Scripts/verify_gomoku_ui_contract.py` and `python3 Scripts/audit_git_blobs.py`, then macOS XcodeGen + `xcodebuild` and actual iPhone/iPad UI checks. No keyboard/scroll blocking, no extra bottom dashboard, no landing ripple.
