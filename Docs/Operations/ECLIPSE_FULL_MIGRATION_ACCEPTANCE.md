# ECLIPSE × Gomoku — Full Migration Acceptance

> P0 migration review ledger. **PR #13 stays Draft.** No main merge, no IPA release, no write to VeilLink.
>
> Last reviewed PR head: `9e6b6f5444ae3e42935c0f1e0d25e9b254ab0b21` (UI + native verified export; document commit follows) (continue updating for subsequent commits).
> Original immutable reference: `Righteous1776/VeilLink@0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`.

## Rules

- `STAGED`: source/assets present; **not** runtime completion.
- `WIRED`: live app executes functionality; test result still pending.
- `TESTED`: CI logs show relevant automated tests passed *on the stated SHA*.
- `ACCEPTED`: Owner/reviewer confirms operational, security, parity and device acceptance.
- An older green CI run may not be attributed to newer code. Explicitly mark pending/blocked.

## Module traceability

| Module | Original source | Independent implementation | Actual runtime hookup | Test evidence | Current state |
|---|---|---|---|---|---|
| Native engine + seven difficulty tiers + 6× | `GomokuBot`, R4/R12/R13, `EclipseDifficultyPolicy`, unified search | `Apps/iOS/Gomoku/NativeEclipse/` | `NativeGomokuAppController.scheduleAI()` | Earlier parity CI 33 XCTest + 1 UI test at older SHA (not current HEAD); core blob equality previously reviewed | TESTED (old baseline) |
| Real persistent self-play validation | `NativeGomokuSelfPlay`, `AdaptiveBoardLearning` | `GomokuNativeTrainingJournal.swift`, `GomokuTrainingWriteGate.swift` | Original native replay, final outcome verification, unique move sequence, one-pass per-batch audit and generation-locked background write; `529d2f0`, `0c5c1e7`, `13fa85a` | `GomokuTrainingIntegrityTests`, `GomokuTrainingWriteGateTests` committed; no current macOS runner evidence | WIRED |
| Learning snapshot and inference feedback | `AdaptiveBoardLearningSnapshot`, `LocalAIGameController` | `GomokuLearningRepertoire.swift`, `GomokuLocalMatchEvidence.swift` | Real native search consumes verified records; only device-keyed local match receipts may promote live human history; external JSON remains reference only; `586ae67`, `284e63e` | `GomokuLearningProvenanceTests` and tactical tests committed; real A/B move-choice parity pending | WIRED |
| 10/100/1000 native batches and stop protection | `NativeGomokuSelfPlay` | `NativeGomokuAppController.swift`, `GomokuTrainingWriteGate.swift` | Detached worker, single initial index scan, atomic generation gate and cancellation, verified UI progress; `13fa85a`, `95a1dd6` | Cancel / restart unit cases committed; persistent session checkpoints and 1000-game endurance still outstanding | WIRED (partial) |
| Original bundled training seed | `GomokuBundledNativeSeed` and original JSON | `GomokuBundledSeedBootstrap.swift` | First launch checksum and terminal replay, staged incremental batch import, idempotent seed promotion; `16f86cd`, `cdcddd0` | `testBundledSeedFirstImportIsValidatedAndIdempotent` committed; current iOS CI not executed | WIRED |
| VeilLink `.vltrain.json` compatibility | `AdaptiveBoardLearning.swift` | `GomokuLegacyLearningImporter.swift`, `GomokuDeveloperPermit.swift` | Authenticated developer-only picker, live revocable authorization, FNV checksum, terminal replay, Xiangqi filtering, staging/backup/rollback and one-pass batch dedup; `6c6b9e1`, `081a6d9` | `GomokuLegacyLearningImporterTests` includes revoked token, tampering and duplicate cases, CI pending; large-file and older schema parity outstanding | WIRED (partial) |
| Chess/Gomoku isolation | `AdaptiveBoardLearningStore` scoped stores | `GomokuLegacyLearningImporter.swift` | Xiangqi records and x: aggregate positions never enter independent learning | Mixed-game and forged outcome cases committed; CI pending | WIRED |
| Interrupted match resume | `LocalBoardMatchStore.swift` | `VeilGomokuMatchArchive.swift`, `NativeGomokuAppController.swift`, `InstrumentHomeView.swift` | App init detects valid `.playing`; user explicitly resumes, replays state and restores id/side/difficulty; commits `224637e`, `8d86f56` | `GomokuRecoveryTests` pending; app-kill UI test missing | WIRED |
| Imported match timestamp fidelity | `VeilGomokuMatchArchive.swift` | `GomokuMatchTransfer.swift` | Validated import preserves original startedAt/updatedAt/completedAt rather than reconstructing times; commits `08b5477`, `27fdd9c` | `GomokuMatchTransferTests.testImportPreservesOriginalStartedAndCompletedTimestamps` pending | WIRED |
| Developer formation lab and signed lesson library | `DeveloperFormationLibrary.swift`, `BoardDeveloperLearningLabView.swift`, `DeveloperLearningLabGate.swift` | `GomokuDeveloperAuthorization.swift`, `GomokuDeveloperLessonLibrary.swift`, `DeveloperLearningLabView.swift` | Device-owner authorization, HMAC/Keychain lessons, alternating teaching moves, prefix influence and private import permit; `0830054`, `f26123c`, `e7e5a10` | `GomokuDeveloperFormationTests` committed; physical biometric/Keychain acceptance pending | WIRED (subset) |
| Personal coach learning profile | `AdaptiveBoardLearning.swift` `PersonalBoardCoachProfile` | `GomokuCoachProfile.swift`, `GomokuCoachView.swift` | Async verify -> completed matches, native/legacy evidence, opening, repeated losses -> UI sheet; commits `0183dd0`, `dc77540`, `d63ad02` | `GomokuCoachProfileTests` committed; CI pending | WIRED |
| Search trace, last move, fallback notices | `VeilEclipseSearchTraceStore`, `VeilGomokuUnifiedSearch.Trace` | `VeilEclipseMeasuredMetricsStore.swift`, `InstrumentHomeView.swift` | Original onExploredLine and onSearchTrace callbacks; measured depth/node milestones feed original upper console and read-only analysis sheet; session token invalidation; `8ce361f`, `d3ae209` | `VeilEclipseMeasuredMetricsTests` committed; no accepted UI/performance screenshots | WIRED |
| Instrument-grade game hierarchy / native night+day | `VeilLink/UI/GameLobbyView.swift` `LocalAIGameView` lines 412–924, original board from `VeilLink/UI/MiniGameViews.swift` | `InstrumentHomeView.swift`, `BoardInstrumentView.swift` | Compact status, ECLIPSE identity, original seven-tier/full-depth controls, board ahead of expandable training, genuine imported VeilLink runtime component, original event-bound stone pulse; `1b1520b`, `49abbba`, `d22ddba` | `InstrumentUITests` foldout and dark/light screenshot attachments authored (`e39fd6e`); simulator images NOT produced, physical dark/light visual comparison pending | WIRED, NOT ACCEPTED |
| Original per-ply self-play export | `LocalAIGameController.exportNativeSelfPlayDetails()` | `GomokuNativeTrainingJournal.exportVerifiedDetails()`, `NativeGomokuAppController.prepareNativeTrainingExport()` | Async off-UI inspection; streamed `gomoku.native.selfplay-details.v1` records, no hard cap, aborts on invalid/duplicate original archive, ShareLink only after success; `1bcc89f`, `0ec3cc8`, `01f44f5` | `GomokuTrainingIntegrityTests` export/malformed-archive checks authored (`9e6b6f5`); iOS runner failed before steps | WIRED, NOT TESTED |
| Peer-to-peer BLE + authenticated E2EE match | Original VeilLink BLE/Pairing code | Original resources archived | Not integrated | No two-iPhone evidence | STAGED / BLOCKED on physical device for final acceptance |
| Standalone icon / signing / device install | VeilLink visual language | `project.yml`, app resources | Independent bundle id present, brand icon/signing work outstanding | Simulator not a substitute for device install | STAGED |

## CI and quality evidence (do not extrapolate)

- PR #13 after `b8bee2d`: `44776904081` Inbox Lite **success**; `44776904225` C++ and Python **success**.
- iOS Actions `44776904098`: **queued** at last check; **not** evidence of successful Swift, XCTest or UI test execution.
- Previous baseline CI `44769241993`: earlier Debug/Release success, 32 XCTest according to prior audit; new patches require their own tests and logs.

## Runner and workflow availability note

On commits after `3fb78f6`, the C++/Python and Inbox jobs sometimes report failure with **empty steps and no assigned runner**. That output is an Actions execution/infrastructure blocker until GitHub supplies a job log, **not** a passing or failing application test. iOS jobs remain queued. Investigate repository Actions entitlement, runner availability or billing only from authenticated GitHub settings; do not assume a root cause from status alone.

## Explicit unsatisfied gates

1. **P0:** Real learning snapshot is wired but benchmark A/B search move choice, large-scale performance, crash-safe import and database format parity are not accepted.
2. **P0:** Real seed first-ingestion is now wired, but persistent batch pause/resume checkpoints, repair/read-only recovery tools, collision-safe durable indexing, and 100/1000/10000-game performance evidence remain incomplete.
3. **P0:** Signed standalone developer lessons and device-owner gate are wired, but real device authorization, Swift build, lesson prefix-change tests and original teaching semantics still need acceptance.
4. **P1:** Personal coach and native search depth/node event wiring exist; full search phase UI, dark/light screenshots, Reduced Motion and long-history interaction/performance acceptance remain incomplete.
5. **P1:** BLE authentication/reliability and two physical phones require implementation and actual E2E evidence.
6. **P1:** Swift 6 strict concurrency checks, stable Release/XCTest, signing/device install and performance gates remain unproven at this head.

## Additional executed changes

- `395f48a`, `971bb78`, `bc48866`: legacy training import now requires a time-bound developer authorization at *commit*, not merely the UI button.
- `f1da7de`: tamper lock and replay/authorization lesson tests.
- `5552759`, `ab1a3a0`: test expectation repairs; neither is evidence of executing XCTest.
- Current post-change iOS Debug/Release, screenshot, real search A/B and device test counts: **NOT VERIFIED**.

## Continuation checkpoint · 2026-11-21

- New latest audited code head before this document update: `081a6d9ada0647a5a6fcdf4343e30b8d522e98f3`.
- **P0 provenance fence:** `d1dc5ae`, `586ae67`, `284e63e`, `2f3c5c6` use device-keyed live game receipts. User-selected `GomokuMatchTransfer` files no longer change formal AI/coach learning simply by being replayable.
- **P0 performance and race:** `0c5c1e7`, `4b8e126`, `13fa85a`, `95a1dd6`, `823ea4c`, `cdcddd0`, `081a6d9`: batch-level history validation and off-main work replace per-game scanning on the interactive actor; write generation revoked synchronously at cancellation; seed/import reuse the batch writer. Full persistent indexing and endurance remain unsolved.
- **Developer import authorization:** `f17b739`, `e7e5a10`, `6c6b9e1`, `0e06425`, `674e7ed`: revoked or expired permit cannot commit a validated training package; database swap is serialized with permission revocation.
- **Measured UI:** `4d1d142`, `8ce361f`, `d3ae209`, `f1aebdd`: actual ECLIPSE unified search events feed depth/node metrics, never synthetic estimates; no extra board-bottom instrument.
- **Required iOS permission text:** `32e9ff9`: developer device-owner authentication disclosure.
- Actions at source commit `081a6d9`: iOS `44781964169` **queued**; C++/Python `44781964445` and Inbox `44781964207` **failure with unavailable executed-step evidence**. Do not attribute these jobs to application test failures or report TESTED. Previous green CI does not validate the above commits.
- Still no two-physical-iPhone BLE/E2EE evidence, Swift 6 strict compile, signed IPA, icon acceptance, source/target gameplay parity or Owner authorization to merge.


## UI screenshot-driven migration pass · 2026-11-21

The Owner-supplied VeilLink night screenshots are the **source reference**: black/orange instrument navigation, ECLIPSE identity with compact VISUAL STREAM, single difficulty menu and deep-search toggle, 15×15 wood board, and one collapsed training panel with verified learning/formation/Bot-vs-Bot/coach/export. They are **not screenshots of the independent Gomoku build**.

Changes staged in PR #13 only:

- Replaced independent vertical button pile (NEW GAME / BLACK / separate pickers / three self-play buttons / coach / developer buttons / import / export / visualization / formation / theme) with a source-aligned card hierarchy and collapse. Full-screen messenger tab bar is excluded intentionally.
- Restored the original `VeilEclipseRuntimeInstruments.swift` component byte-for-byte; accessible behind an explicit disclosure **inside** the learning panel to keep the actual board near the top and avoid continuous redraw when hidden.
- Restored the original board's single on-move impact animation, gated by reduced-motion and scoped to the native game session; kept tap recognizer simultaneous with scrolling and a separate accessibility grid.
- Training stats now bind to verified local journal/coach values; reference screenshot's “42 games / 2403 positions / 3110 self-play” are **never** hardcoded into Gomoku.
- Added independent streamed JSON export of per-move validated native self-play; unlike VeilLink's former package contract, this export is **not** presented as a round-trip `.vltrain.json` import or full “训练包” parity.
- New UI tests request screenshot attachments for day and night plus expanded learning. These attachments do not exist until simulator XCTest truly executes. Reduced Motion, iPad, keyboard, short-screen, dynamic type and low-power profiles remain unaccepted.

Current runner check at `9e6b6f5`: iOS Actions `44785011256`, C++/Python `44785011290`, Inbox Lite `44785011337` all show **failure before any job steps / assigned runner evidence**. These are not verified compiler/test failures nor passing checks. Do not mark the UI TESTED or promote this PR.

## Authentic personal training archive and seed replay · 2026-11-21

- Source original file 285,074 bytes preserved in `Migration/OwnerEvidence/VeilLink-Gomoku-OwnerTraining-20261031.vltrain.json`, byte-for-byte blob SHA `811255cc73f3d79ef2aa4c768a2b5ed1679ba8a4`. Payload checksum `c52154f68a0cb20c`: 28 legal original games, 10 completed and mutually unique, 18 incomplete and legally replayed, 1,205 aggregate hash-only positions retained but not promoted.
- Original native seed 2,000 records is already byte-identical. Independent source replay confirmed 2,000/2,000 legal, **236 unique, 1,764 duplicates**; FNV `29e9808a4a69618b`. Python and XCTest regression assertions newly written; executing the tests is blocked by GitHub Actions no-runner state.
- Owner-only, nondefault bundle staging script and authenticated developer import are wired. Follow-on integration retains full raw input inside `ImportedLegacyLearningV1/RawSources` after user selection; real on-device ingestion remains NOT VERIFIED.
- Historical source R6/R8 5,141-game raw private bundles, 62,500 surrogate experiment log, shared VLPOL model and 224 MB three-game dataset are NOT additional native ECLIPSE training evidence present in GitHub. See `Docs/Operations/REAL_TRAINING_DATA_MIGRATION.md`.

## Owner raw data closeout, as actually staged on PR #13

- Authentic private owner source files: **3 byte-exact original archives**, from 2026-10-31 and 2026-11-13 twice. Each is outside the normal iOS application bundle in `Migration/OwnerEvidence/`.
- Independent replay: 28 + 107 + 78 = **213 raw recorded matches**, 115 genuine terminal-label/replay-compatible records, **102 unique completed trajectories**, 93 genuine nonterminal histories and **5 identified source restore fragments** with nonterminal board but terminal label. All original bytes retained. No invalid/mislabeled fragments enter learning.
- Original native seed: 2,000 valid terminal entries but only 236 distinct move trajectories; **0 exact overlap** between the verified owner trajectory set and the unique native seed set; therefore **338 distinct move trajectories across both sources**, but NOT 338 verified on-device imported games. This is a dedup factual count, not a strength/Elo score.
- Black/white real-owner training correction: `GomokuLegacyLearningImporter` honors the first actor identity as Black, persists `humanStone` in version-compatible journal records; `GomokuLearningRepertoire` applies owner-relative outcomes and AI turn; existing native-only self-play stores remain color-relative. The five known fragments are quarantined **only** for exact pinned SHA256 original package and ordinal.
- Old v29 export Date precision can change canonical JSON FNV across runtimes; matching exact original SHA256 + expected envelope checksum permits those two only, while arbitrary modified exports still require canonical FNV.
- Owner-only packaging requires explicit `--acknowledge-private-bundle`, creates ignored `Resources/OwnerPrivate` copies of all three sources, and supplies separately authorized developer-lab buttons. This *does not* automatically export or install private game history on the owner phone.
- Python source verifier and XCTest unit tests authored; current GitHub Actions still show failure without any assigned runner or steps, so **runtime completion remains WIRED / NOT TESTED / NOT ACCEPTED**. Documentation `Docs/Operations/REAL_TRAINING_DATA_MIGRATION.md` is authoritative.

## Owner decision and rollback

**Decision: NOT MERGEABLE / NOT RELEASABLE** pending iOS CI, above P0 gates, parity review and Owner approval. All work stays in `integration/veillink-migration-consolidated` attached to PR #13. Revert individual new commits if regressions surface; never mutate `Legacy/Original/` bytes or the source `VeilLink` repository.

## TenGate Lite lane ownership

Current integration changes are authored under the Owner's explicit single-task direction, not proof of persistent Governor delegation. Do not silently grant ordinary Agents direct edit permission. Proposed lanes, only when assigned in `AGENT_INBOX/BOARD.json`: ENGINE / TRAINING / DATA / FORMATION / IOS / BLE / QA, with disjoint file ownership and INBOX_ONLY submissions.
