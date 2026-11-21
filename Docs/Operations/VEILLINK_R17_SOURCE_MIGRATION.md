# Gomoku × VeilLink R17: source-faithful UI and functional migration

**Reference repository:** Righteous1776/VeilLink, commit
`0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`. This is the upstream
implementation, not an aesthetic reinterpretation.

**Protected model baseline:** Gomoku rollback `4d57b983f5caca0c3bbb300f3879e1e5f7a9bfae`,
which has the exact source tree of approved post-Astra/Sol injection baseline
`41fe4f65ad4dc723f9bf438cba4dfb9a385c1805`.
No trainer weights, C++ search geometry or owner data are changed in this pass.

## Direct UI mapping

| VeilLink source | Gomoku runtime | Provenance |
| --- | --- | --- |
| `VeilLink/UI/GameLobbyView.swift` `LocalAIGameView` (lines 412–458) | `InstrumentHomeView.swift` | Original ordered status, ECLIPSE card, runtime instruments, controls, board, result, collapsed training |
| `VeilLink/UI/MiniGameViews.swift` `GomokuBoardView` (lines 1452–1603) | `BoardInstrumentView.swift` | Same wood, black/white stones, grid, last-move pulse, line, margin=5.5%, tap radius=0.52 grid step; native UIKit tap surface retained for scroll coexistence + accessibility grid |
| `VeilLink/UI/VeilEclipseComputeConsole.swift` | `Visualization/VeilEclipseComputeConsole.swift` | exact Git blob |
| `VeilLink/UI/VeilEclipseConsoleStream.swift` | `Visualization/VeilEclipseConsoleStream.swift` | exact Git blob |
| `VeilLink/UI/VeilEclipseRuntimeInstruments.swift` | `Visualization/VeilEclipseRuntimeInstruments.swift` | exact Git blob; relocated from folded training to original above-board position |
| `VeilLink/UI/VeilEclipseBoardThoughtField.swift` | `Visualization/VeilEclipseBoardThoughtField.swift` | restored exact Git blob |
| `VeilLink/Core/AppearanceTheme.swift` instrument day/night | `DesignSystem/AppearanceTheme.swift` | token-for-token source instrument palette, locked instrument appearance and automatic/day/night |
| `VeilLink/Core/AppTheme.swift` | `DesignSystem/AppTheme.swift` + `InstrumentComponents.swift` | standalone subset of original VeilLink card/material, avoiding messaging-only dependencies |

## R17 (C++20 Trainer Compute ABI V2) live functional path

- `EGComputePolicyV2` / `EGComputeRunV2` / `eg_analyze_compute_policy_v2` / `eg_cancel_search_v2` are already present in standalone C++ and connected to `EclipseCppProductionAdapter` in Release.
- Trainer policy parameters and approved policy SHA are verified before running. C ABI echoes the applied policy and measured total nodes, completed depth and elapsed time. Native search is cancellable. Root learning bonuses remain unable to override the compulsory tactical check.
- `NativeGomokuAppController.scheduleAI()` dispatches the verified Astra/Sol native C++ engine off-main and safely falls back to original Swift, without falsely attributing fallback to ECLIPSE 2.0.
- Original Swift `onExploredLine` and `onSearchTrace` feed validated, session-bound search visuals and metrics. **Important limit:** this restored R17 C++ V2 ABI returns its native nodes/depth at completion, not a continuous candidate PV stream. Never depict decorative console code as actual search proof or imply C++ live per-node telemetry without a separate measured ABI.
- Pre-existing self-play, training archive, formation, coach, import/export and developer authorization remain wired and unchanged.

## Intentionally not copied

- VeilLink BLE chat, messenger tab bar, chess/other games and their databases are not part of the independent Gomoku UI.
- VeilLink AppModel / LocalAIGameController ownership is replaced by the current standalone model controller, so exact type-level copying would break the verified Astra/Sol binding.
- No private owner `.vltrain` data, real game records or training files from upstream are reuploaded.

## Gates

`Scripts/verify_veillink_r17_migration.py` checks all four original byte-exact UI assets, live native C ABI and Swift wiring, and original structure. Existing `Scripts/verify_gomoku_ui_contract.py` enforces board touch and reduced-motion safeguards. They are **source tests only**. iOS simulator screenshot comparison, Swift XCTest, actual iPhone hardware feel, performance, R17 telemetry and real match behavior still require independent acceptance on this exact commit. No merge to main or signed IPA is authorized by this document.
