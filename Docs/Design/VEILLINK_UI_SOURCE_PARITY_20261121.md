# Gomoku UI: exact VeilLink source migration (owner-directed)

## Source of truth

- VeilLink repository: `Righteous1776/VeilLink`, **main `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`**
- VeilLink game screen: `VeilLink/UI/GameLobbyView.swift` — `LocalAIGameView` at lines 380–460, status/readouts at 590–683, advanced foldout at 686–718.
- Original 15×15 board: `VeilLink/UI/MiniGameViews.swift` — `GomokuBoardView` at lines 1452–1603.
- Original ECLIPSE identity/trace: `VeilLink/UI/VeilEclipseIdentityAndTrace.swift`.
- Original animation and measured-instrument widgets: `VeilLink/UI/VeilEclipseComputeConsole.swift`, `VeilEclipseRuntimeInstruments.swift`, `VeilEclipseBoardThoughtField.swift`.
- Original materials: `VeilLink/Core/AppearanceTheme.swift` (`instrumentDay`/`instrumentNight`), `VeilLink/Core/AppTheme.swift` (`VeilTheme`, `VeilSpacing`, `VeilCardModifier`, `VeilAmbientBackground`).

## Exact on-screen hierarchy restored

`statusCard → VeilEclipseIdentityCard.veilCard() → VeilEclipseRuntimeInstruments.veilCard() → boardQuickControls → GomokuBoardView → resultCard (if finished) → boardAdvancedPanel`.

- Same `VStack(spacing: 14)`, outer `.padding(14)`, ambient background and title.
- Same 3-column adaptive status grid and monospaced LCD metric typography.
- Same 15×15 board wood fill, white grid, star points, black/white stone finish, spacing, impact and gesture geometry. The board source was **already faithfully ported** at restored rollback baseline; do not touch or unnecessarily reimplement it.
- Same VeilLink colors, material and original ECLIPSE console/runtime components. The last three source-file SHA-1 values already match VeilLink upstream exactly; do not "refresh" their visuals.
- Remove Gomoku-only second runtime foldout: there should be exactly one original instrument in its original position.
- The original VeilLink ECLIPSE card text and wall-time label are restored.

## Limited adaptations that remain necessary

The standalone Gomoku app has no VeilLink `AppModel` or chat/game-hall navigation, and supports independently verified Astra 2.0 / Sol 2.0 native C++ trees. Keep the standalone model selector, trainer-controlled compute policy, journal and training controls wired to `NativeGomokuAppController`. Their **behavior is not a visual redesign**. Additions must follow original VeilLink colors, sizing and hierarchy; no fake console widgets or custom mechanical trim.

Do **not** re-import VeilLink's global device/network dependencies into this isolated game application. Do **not** change C++, model checkpoints, policy SHA, self-play or training data in an appearance migration.

## Acceptance

1. CI must pass 15×15 board gesture and R17 impact, accessibility, iPhone/iPad sizing, and source-order checks.
2. Release IPA must build on a commit **based on rollback `4d57b983f5caca0c3bbb300f3879e1e5f7a9bfae`**; previous rejected 15 commits remain invalid.
3. iOS screenshot parity with the actual VeilLink build is a separate **visual acceptance gate**; source structure parity alone does not prove pixel-by-pixel equality.
4. Do not merge the design PR into the rollback lane until its independent build and screenshot checks pass.

This document records what was sourced directly from VeilLink, not speculative styling guidance.
