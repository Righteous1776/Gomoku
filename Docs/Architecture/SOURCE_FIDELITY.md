# Source fidelity and licensing contract

## Observed upstream facts (2026-11-20)

- Repository: `https://github.com/Righteous1776/VeilLink`; default `main`; pinned SHA `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`.
- Root LICENSE: MIT, `Copyright (c) 2026 ZeoStudio`.
- Root `project.yml`: Swift 5.9 / `studio.zeo.veillink`, iOS min 15.0, app named VeilLink. The new independent app intentionally targets iOS 17.0+.
- Native original AI: `VeilLink/Agent/Games/GomokuBot.swift`, `VeilGomokuUnifiedSearch.swift`, `VeilGomokuUnifiedBridge.swift`, trained `EclipseTrainedOrdering.swift`, mandatory counter-fork `GomokuCounterForkR4.swift`, `EclipseDifficultyPolicy.swift`, R12/R13 optional search modules.
- Original AI orchestrator: `LocalAIGameController.swift` mixes Gomoku/Xiangqi and depends on `MiniGameKind` and original app symbols.
- Source UI: `GameLobbyView.swift` contains `LocalAIGameView`; `MiniGameViews.swift` contains `GomokuBoardView` and multiplayer UI; ECLIPSE trace and runtime files in `VeilLink/UI/VeilEclipse*.swift`.
- Original theme enum `VeilAppearanceSelection.instrumentAuto` shown as “拟物仪器”; supports dark/light/system, not a distinct standalone custom recreation.
- Training resource: `VeilLink/Resources/GomokuNativeTrainingSeed.json`; optional JS engine with `VeilLink/Resources/GomokuEngineV2/engine.js`, `LICENSE`, `PROVENANCE.md`.
- Tests include GomokuBot, 7-tier, native self-play, formation, archive, ECLIPSE R12/R13/R14.

## Preserve exact bytes

- Stage all listed source files from pinned commit under `Legacy/Original` with `Scripts/migrate_from_veillink.py` and compare SHA256 using `Scripts/audit_migration.py`.
- Adaptation is a forked source copy, not a rewrite of original staged files. Save a source→adapted mapping with exact file origins, generated diff and reason, per file.
- No renaming internal `VeilGomoku*` identifiers merely for brand aesthetics. The product name can be Gomoku, engine ECLIPSE, with legacy internal symbol names untouched until an explicit safe refactor.
- Training seeds are not proof of arbitrary real-world Elo or ranks. Audit source provenance, model version and checksum before deploying.
- Preserve original MIT terms and check all nested license files. Third-party binaries and unverified user's `.npz` archives are NOT implicitly covered by the MIT license.

## Do not stage by default

- Entire original app, unrelated games, messaging database, personal device data, private assets, huge unrelated weights (`VeilFlyCore.vfly` etc.), provisioning profiles or keys.
- Source inventory includes some *read-only reference* folders to permit clean BLE extraction, but Work should not automatically link them to Gomoku iOS target.
