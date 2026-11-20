# [AGENT-DROP][IOS] R17.2 owner-corrected UI — concrete Swift patch
## Goal
Submit real Swift app source changes in a review-only PATCH.diff so standalone Gomoku does NOT acquire the rejected lower ECLIPSE telemetry dashboard or any move-impact ripple, while retaining one upper black compute unit and a truthful elapsed search clock.

## Changes
- `Apps/iOS/Gomoku/InstrumentHomeView.swift` (existing shell): removes the **separate ENGINE STATUS card**, moves status and `REAL CLOCK T+` into a single upper black ECLIPSE console, with `TimelineView` at 0.5 s during active search and 1 s for reduced motion/inactive scene. No fake nodes, decorative LED stream, extra touch overlays, or drag gestures. Corrects Swift `Font.system` weight/design ordering behind an existing iOS build failure. Existing 15x15 board and controls retained.
- `Apps/iOS/Gomoku/EngineBridge.swift` (existing shell): publishes actual `searchStartedAt` when search is scheduled; clears it on reset and on matching generation completion; captures immutable `selectedMove` before MainActor closure rather than a mutated variable.
- `Apps/iOS/Gomoku/BoardInstrumentView.swift` already has no `impactIndex` / `impactScale` / landing ripple, and is intentionally untouched.
- The app still uses experimental C++ engine. This patch is **not** the full Swift ECLIPSE parity migration nor exact `instrumentAuto` component port.

### Verified source and migration mapping
- The unmerged original R17.2 PR `Righteous1776/VeilLink#234` contains owner-rejected card/pulse; do not wholesale copy.
- The correct behavioral reference is isolated `VeilLink@af37b1e90ef77fc0ca0bb176a96d6a43bb234a1d` (`integration/v30-eclipse-r17-selective-20261120`), with `docs/engineering/V30_ECLIPSE_R17_TRIAGE.md`.
- Future full UI integration references original `VeilLink/UI/GameLobbyView.swift`, `MiniGameViews.swift`, `VeilEclipseComputeConsole.swift`, `VeilEclipseIdentityAndTrace.swift`, plus `LocalAIGameController.swift` and `VeilGomokuUnifiedBridge.swift`. Adapted implementations must preserve search strength 1–10, unlimited time cutoff, seven tiers and instrumentAuto while forbidding rejected UI.
- This two-file patch is an adapted interim implementation using current standalone shell APIs; no source is overwritten under `Legacy/Original`.

## Risks
- **BLOCKED:** trusted main BOARD still lists `IOS` as `OPEN/unassigned`, with `depends_on=[SOURCE]` which is not `MERGED`. Owner's instruction permits preparing this DRAFT, not assuming task assignment or valid check-drop.
- No SwiftUI typecheck, full Xcode build, iPhone/iPad screen inspection, or game strength test ran. Actual stopwatch means wall-clock elapsed time, not search progress.
- On merging full Swift ECLIPSE source the temporary C++ shell should be replaced/rebased, rather than treating this interim correction as final exact visual parity.

## Rollback
Only Inbox files were added on `agent-drop/chatgpt-ios-ui/IOS`. Closing Draft PR leaves product/main untouched. Any future applied integration must be reverted through normal Git commits, not main history rewrite.

## Evidence
- Gomoku main base `a819c1ea0ff82846a077ee856c49aacd7191bf10`; home blob `8b1c760907b8f1a26bc6cf4692acaf952aa83e51`, bridge blob `41551d58091639da5d50858d726a94b0bb30f06e`, board blob `16c5dd9f1c138525496bd8b492eef22f1356a8c0`.
- Candidate static checks: **6/6 PASS**:
  - Swift font parameter order
  - rejected lower dashboard absent
  - rejected landing ripple absent
  - real clock bound to actual search start
  - search reset with generation guard
  - Swift concurrency capture fixed
- `git apply --check` NOT RUN; `xcodebuild` NOT RUN; device UI regression NOT RUN; signed IPA NOT BUILT.

## Next
1. Owner/integration reviewer finishes SOURCE provenance audit and merge, assigns IOS scope to `chatgpt-ios-ui` via trusted BOARD and checks dependencies/conflicts.
2. Rebase/re-submit against actual up-to-date main if required by immutable-drop rules; run `Scripts/inbox.py check-drop`, `git apply --check`, then compile and test.
3. Replace provisional shell with original ECLIPSE/instrumentAuto SwiftUI source through separate adapted diff, copying no lower dashboard/ripple; verify owner-corrected UI with Xcode/real devices.
