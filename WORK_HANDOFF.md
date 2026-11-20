# [WORK MASTER HANDOFF] Gomoku / ECLIPSE independent repository — one complete execution

> **This file is the main executable task brief to forward to ChatGPT Work. Read in full before any repository writes.**
>
> Owner: ZeoStudio (GitHub `Righteous1776`)  
> New app: **Gomoku** / Engine: **ECLIPSE**  
> Source repo: `Righteous1776/VeilLink`  
> **Source pin:** `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32` (observed main 2026-11-20)  
> New repo: `Righteous1776/Gomoku` (create private by default; do not publish without explicit owner approval)  
> New iOS bundle: `studio.zeo.gomoku`  
> Status of this ZIP: a **bootstrap engineering package**, not a finished release and not a byte-for-byte portable Swift port. Follow all execution gates below.

## 0. Your assignment and non-negotiable principles

**Carry out the entire repository bootstrap and integration effort in this Work run wherever tools and credentials permit, rather than merely rephrasing this plan.** Create the new GitHub repo, commit this engineering package, stage immutable upstream Gomoku source, make the exact original ECLIPSE feature set compile and run in the new iOS app, implement and test migration of private user data through explicit export/import, establish native C++ engine and Python training stack and CI, test it, produce a usable IPA only if proper signing is available, and report objective pass/fail evidence for every gate.

1. **Protect upstream.** NEVER change, force-push, delete, reset, rebase, mutate version, or trigger release on `Righteous1776/VeilLink`. Read only. The prior source repo has strict Owner → Integration Governor → Lane governance; default is INBOX_ONLY. This new independent repo is a separate owner-approved bootstrap effort; do not infer permission to change VeilLink.
2. **Source fidelity.** The original Gomoku Swift ECLIPSE (including tactical guards, learned ordering, search budget, seven tiers, training, match archives, displays) is authoritative. Copy all relevant upstream source files *exactly* into `Legacy/Original`, record SHA256, then create adapted copies in app modules. Never rewrite original files in place. If a source module is mingled with Xiangqi or messenger code, extract via smallest necessary patches with tests, record a diff. Do not accidentally substitute `Engine/` C++ experimental engine as the ECLIPSE production engine.
3. **Visual parity.** Fixed original VeilLink `instrumentAuto` (“拟物仪器”) across ALL pages, including nighttime/daytime/system light behavior. No other visual theme selection. Reuse original SwiftUI primitives and source colors, original GomokuBoardView, ECLIPSE compute console, search trace and archived match UI. This bundle's provisional SwiftUI shell is a functional entrypoint only, NOT the finished design.
4. **Functional completeness.** Preserve seven-tier difficulty from `LocalAIGameController`, `2×/4×/6×` as search-budget multipliers (not strength multipliers), black/white selection, 15×15 freestyle, original opponent AI, native self-play, game history with no arbitrary count/file-size caps, per-game archive, developer formation learning, move-sequence learning, training/learning import/export, read-only search visualization, local recovery, and existing offline optional GomokuEngineV2 choice if licensed. Preserve multiplayer only by implementing a standalone purpose-scoped BLE/E2EE game session — do NOT require VeilLink messenger or expose chat data.
5. **Native research architecture.** Keep C++20 portable `Engine/` + C ABI, Python Training + optional PyTorch research, and paired-match Arena. C++ baseline must stay **experimental** until compared to Swift ECLIPSE on equivalent rules/time/hardware and certified non-regressive by test evidence. Do not claim neural net training makes AI stronger without head-to-head validation. Original Swift remains selectable/default for all parity-critical releases until promotion.
6. **Private data.** No personal sessions, photos, voice, contacts, chat text, device identifiers or unreconciled weights into Git. The attached `brain.npz.zip`/`weights.npz.zip` were not verified as Gomoku training artifacts: treat as out-of-scope; do not ingest blindly. Original app sandbox cannot be read by a different app; build user-initiated export/import with exact shape/version checks and backups. Gomoku and Xiangqi data must remain separate.
7. **No false successes.** If tests did not run, mark NOT RUN; if code only compiles locally, do not claim installable IPA; if signing credentials absent, deliver unsigned developer artifact separately, plus exact signing blockers. Attach logs/commit SHAs and link artifacts only if actually present.

## 1. Inspect and pin source; create new repository

A. Read `README.md`, `AGENTS.md`, every file in `Docs/`, `Migration/source_inventory.json`, `Provenance/UPSTREAM.json`, `.github/workflows/`, and `project.yml`. Inventory each engine/code/asset/license. Confirm `Righteous1776/VeilLink` upstream commit exists. Compare its history to current `main`, but use **pinned** commit as migration baseline; if source has advanced, present an auditable diff and do not silently select a different revision.

B. Under user's authorized connected GitHub identity create **private** repository `Righteous1776/Gomoku` (unless already exists; never overwrite). MIT license copyright ZeoStudio. Initialize `main` with this bundle. Preserve all existing files and source provenance. Attach repository topics only if supported; never add secrets.

C. Add protected integration process: `feature/source-extraction`, `feature/ios-original-parity`, `feature/cpp-engine`, `feature/training`, `feature/local-migration`, `feature/ble-game-link`, merged to main in reviewed sequence; prohibit direct version/signing/release changes by normal agents. Use PRs, no direct uncontrolled main mutation. If repository private branch protection unavailable due plan, document and use PR reviews, do not claim enforced protections.

## 2. Exact upstream source extraction — MUST EXECUTE

1. Clone upstream from GitHub in a clean working checkout.
2. Check out the exact pinned commit and confirm `git rev-parse HEAD`.
3. Run:

```sh
python3 Scripts/migrate_from_veillink.py --source /PATH/TO/VeilLink
python3 Scripts/migrate_from_veillink.py --source /PATH/TO/VeilLink --execute
python3 Scripts/audit_migration.py
```

4. If any **critical** item is missing, stop extraction, explain path drift and reconcile inventory with verified replacement. Never proceed with a missing engine file. Record `Provenance/migrated_sources.sha256.json` and a source inventory report.
5. Staged files intentionally NOT compiled. Convert them into isolated production modules in `Apps/iOS/` and `Engine/` only after reviewing dependencies. Legacy staged files must remain byte-identical.
6. Document transitive dependencies: original `AppModel`, `MiniGameKind`, `MiniGamePlayer`, `GomokuState`, `LocalBoardMatchStore`, `AdaptiveBoardLearningStore`, `VeilAppearanceController`, theme primitives, local file importer, UI trace instruments, Game Lobby BLE network and protocol. Identify each dependency: keep, extract, adapt, or reject, and explain why.
7. Record a machine-readable mapping `Migration/evidence/transitive_dependencies.json`, original-to-adapted diff map, and SHA256 digest of every adapted file in an audit log.

## 3. Replace shell with original Gomoku application and instrument design

- Create `GomokuApp` as sole `@main`, independent app target, separate bundle/entitlements/Info.plist/resources. Use deployment target iOS 17+ (new product contract). Confirm compatibility with iPhone 13/iPad.
- Refactor `LocalAIGameView` into a standalone Gomoku screen while copying original view elements and interactions, including `GomokuBoardView`, dedicated compute console, source difficulty definitions, trace controls, native self-play controls, trainer, archive/replay, and explicit import/export.
- Freeze appearance selection to `VeilAppearanceSelection.instrumentAuto` without deleting day/night/system color mode behavior. Reuse `VeilInstrumentBackground`, `VeilInstrumentPlate`, `VeilPhysicalButtonStyle`, `VeilLCDDisplay`, and other actual original components.
- Eliminate unrelated messenger, games and tool-center navigation *from the standalone target*; retain only necessary shared dependencies. Do not ship unrelated large AI models, giant binaries, private assets, or excess app capabilities.
- No decorative gesture interceptors on scrollable surfaces. Use profiling to make UI input latency acceptable; run simulator and physical-device smoke checks.
- Keep ECLIPSE naming for AI, **Gomoku** product naming and bundle ID, ZeoStudio attribution.

## 4. Engine separation and C++ research core

- Compile `Engine/` C++20 cleanly across Linux/macOS and in Xcode. Preserve C ABI (`eclipse_c_api.h`) stability; add versioning/error and cancellation interfaces before production search integration.
- The provided C++ search is deliberately **prototype strength**. Implement port of original Swift mandatory tactical gates, exact rules, candidate ranking learned R10, search time/nodes/depth semantics, search trace and cancellation without semantics loss. Add Zobrist hash/transposition table/iterative deepening and correctness tests incrementally; protect tactical rules against learned-order override.
- Build a Swift-compatible selection layer permitting original Swift ECLIPSE as default and experimental C++ in a developer-only test console, with an explicit engine ID and telemetry for every move.
- Parity requires deterministic corpus of positions and outcomes, forced win/block/fork, seven difficulty settings, 6× budget invariants, paired matches, device timeouts, out-of-time legal fallback, and stable seed/learning imports. Do not assert exact-move equality where equally strong alternatives exist; require tactical legality, result equivalence and statistical strength.

## 5. Data migration — no invisible cross-sandbox access

- Reverse-engineer and document original formats: `adaptive-board-learning-gomoku-v2.json`, `gomoku-native-selfplay-v1.json`, original `LocalBoardMatchStore` recovery JSON, `GomokuMatchHistoryV1/` per-match JSON, formation discovery UserDefaults and bundled native seed.
- Build opt-in **Export all Gomoku data** in original app only if authorized to change that repo via its governance; if not, use existing supported exports in VeilLink and provide an import flow that accepts those files without mutating upstream. Explicitly distinguish what cannot be exported from existing app without authorized upstream work.
- Build standalone import, schema/version/fingerprint verification, ZIP path traversal and zip bomb protection, independent staging, atomic commit, conflict resolution, duplicate detection, visible report and rollback. Never import chat records or Xiangqi data. Preserve source until import verified; do not wipe original.
- Avoid any fixed number-of-games/positions cap. Per-file size controls may be set only for safety/memory and must support streaming/chunking with explicit feedback instead of arbitrary silent truncation.
- Generate sample migration fixtures with synthetic move sequences. Test 100% count/checksum identity and interrupted-import recovery. Keep user data under `Application Support` with file-protection where supported; do not commit it.
- Declare standalone app sandbox identity in documentation; **do not claim automatic migration** simply because code paths are the same.

## 6. Local two-device multiplayer

- Separate game-session protocol from VeilLink chat semantics; preserve gameplay message ordering, turn tokens, session IDs, rules/version handshake, atomic snapshot/replay and BLE transport integrity. Do not sort turns by peer wall-clock timestamps.
- Extract only necessary BLE + E2EE features and validate device permission declarations. Never claim BLE can provide iOS system background guarantees beyond OS permissions; design foreground-dependable experience and graceful reconnect.
- Protect confidentiality and replay integrity, do not read unrelated chat payloads, and avoid plaintext game state if original transport contract requires encryption. Never require VeilLink to be installed for new-app-to-new-app matches.
- Two physical iPhones are the release gate. Simulated unit tests are insufficient to claim real BLE interoperability. Record disconnect/reconnect, out-of-order, duplicates, resign, replay and elapsed-time drift tests.

## 7. CI, tests, iOS IPA, distribution

- `Gomoku CI` runs the Inbox and Python regressions, C++ build and CTest, self-play dataset validation, and source and package audits before the iOS simulator build and XCTest.
- To package a developer IPA from the same workflow, dispatch it with the full reviewed commit SHA. After all checks pass, CI scans and uploads `Gomoku-UNSIGNED-DEV-ONLY.ipa`.
- Add signed IPA workflow **only** if the owner actually supplies valid certificate/provisioning credentials through secure secrets. Confirm Bundle ID, team ID, entitlements and method of distribution; no credentials committed or printed. App icon and launch imagery must be distinct in product name but respect agreed original visual style. Signed IPA upload only after all quality gates and owner release approval.
- Test matrix: C++ Linux, C++ macOS, Python dataset, iOS simulator Debug/Release, iPhone/iPad physical device where accessible, BLE paired devices, data migration and parity. Any unavailable hardware is a documented blocker, not PASS.

## 8. Training / AI R&D (ship architecture now, validate research now)

- Keep Python training tools under `Training/`. Add validated self-play logs with provenance, source engine ID, rules and run configuration; absolutely no artificial 40-match/512KB limits.
- PyTorch `train_policy.py` is a research-only teacher; it does NOT automatically improve C++ or Swift play. Train a baseline from synthetic/offline **verified** data only, export and record evaluation evidence. Do not merge experimental weights into shipped app until stronger paired-match results, model license, architecture compatibility, memory/thermal and CoreML/ONNX conversion checks.
- Run `Arena/compare.py` paired color-swapped matches, keep outcome tables and uncertainty; avoid assigning real human dan or Elo from weak baselines.
- Lay stable multi-game engine interfaces; don't prematurely migrate chess/xiangqi rules. ECLIPSE becomes research engine platform, Gomoku remains its first consumer.

## 9. Acceptance/stop conditions — no fake completion

**Required to report full completion:**
- Private new repo URL with actual created main SHA and branch/PR links.
- Original upstream pinned SHA and extraction proof; no modified original byte.
- Standalone Xcode project and app launch/screenshot showing `instrumentAuto` exact source design.
- Full Gomoku feature matrix with every original feature exercised or marked failure.
- Swift ECLIPSE engine default, complete 7-tier behavior and verified regression tests.
- C++ engine compiles, with dev-only selection until parity promotion; Python experiments run; CI green.
- Data import/export and no-cap tests; documented sandbox limitation.
- Two-device BLE game session logs if hardware accessible; otherwise NOT VERIFIED and don't certify release.
- Valid signed device-installable IPA **only if signing and test conditions met**. Otherwise report precise blockers and deliver validated unsigned developer artifact separately.
- Full provenance, licensing report, crash/performance results, test logs, known issues and handoff for maintenance.

**Stop release** on missing core source, invalid provenance, AI tactical regression, private data exposure, source repo mutation, broken E2EE/turn order, missing third-party license, unusable UI, missing required iOS build/test evidence or absent valid signing credentials.

## 10. Work response format

Provide a final table with `deliverable / status (PASS|FAIL|NOT RUN|BLOCKED) / evidence link/commit SHA / remaining action`. Name all branches, PRs, check runs, generated files, date and environment. Explicitly distinguish 1) new repo created, 2) C++ prototype compiled, 3) original ECLIPSE migrated, 4) iOS app built, 5) signed IPA installable, and 6) C++ parity certified. These are separate achievements.

**Do not convert this handoff into just another proposal. Produce real artifacts.**
