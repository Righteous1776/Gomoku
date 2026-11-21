# Gomoku migration — owner-authorized isolated source snapshot
Date: 2026-11-20. Upstream: `Righteous1776/VeilLink@0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`.
This record is part of a **separate feature branch for Owner review**, not a merged or released standalone application.

## Completed with real Git objects
- All **57 mandatory source inventory entries**, expanding to **59 exact original files**, staged at `Legacy/Original/<VeilLink original path>`. Added 3 reference files for formative testing and import.
- Source Git blobs were compared with the corresponding target Git objects: **62/62 match**.
- `Provenance/original_source_git_blobs.json` gives the source path, stage path, original Git Blob SHA and classification for every file.
- No source under `Legacy/Original` is registered as an app target: staging is not running source integration.
- No writes to `Righteous1776/VeilLink`; original app source remains read-only. No personal learning history, signing key or unverified .npz weights were committed.

## Remaining work — cannot report complete
1. Full compiler-guided dependency closure and separation of Gomoku from unrelated Xiangqi, chat and VeilLink AppModel. Native Swift engine remains unlinked; 7-tier behavior, learning/selfplay, archives and search trace are NOT YET RUNNING in Gomoku.
2. Port from original staged `VeilLink/UI/GameLobbyView.swift` / `MiniGameViews.swift` into independent Gomoku screens. MUST honor Owner R17.2 correction: NO bottom `VeilEclipseRuntimeInstruments` dashboard, NO `impactIndex` / `impactScale` / `impactExpanded` / board landing ripple. Preserve upper black robot console, real stopwatch and normal last-move marking. Corrected design reference: `VeilLink/integration/v30-eclipse-r17-selective-20261120@af37b1e90ef77fc0ca0bb176a96d6a43bb234a1d` (isolated, not released). This is separate from exact source snapshot.
3. Wire original `instrumentAuto` theme into standalone dark/light/system pages. Existing SwiftUI shell is provisional.
4. Implement independent opt-in learning/archives export+import; no cross-app sandbox read; no arbitrary game/position cap. Original training seed resource has been staged but not linked into App.
5. Standalone two-device BLE/E2EE only after protocol/security, reconnection, and real-hardware review; don't copy VeilLink messenger wholesale.
6. Reconcile optional upstream reference directories. Original inventory includes 12 reference entries, some whole messaging/security folders and full app icon assets; do not mass-copy unrelated material. The full original app or identity/keys are out-of-scope for standalone Gomoku.
7. Fix iOS simulator errors and run `xcodebuild` on macOS; original Swift vs C++ experimental engine regression; real iPhone/iPad QA; signed IPA if authorized. All NOT RUN by source staging.

## Verification
```sh
python3 Scripts/audit_git_blobs.py
python3 Scripts/audit_git_blobs.py --emit-sha256
python3 Scripts/audit_migration.py
```
`--emit-sha256` creates the expected SHA256 manifest locally on a clean, authenticated checkout **after Git Blob verification**. An emitting build would have to commit that manifest through a separate reviewed change; it is not falsely reported as already generated here.

## Governance
Single explicit Owner instruction to conduct a one-off full migration is implemented only on an isolated `feature/owner-source-migration-20261120` branch. No self-assignment of `AGENT_INBOX/BOARD.json`, no direct `main` merge, no signing/release. Owner/integration reviewer must still enforce `SOURCE` and downstream `IOS/IMPORT/BLE` task dependencies.
