# ECLIPSE × Gomoku — Full Migration Acceptance

> P0 migration review ledger. **PR #13 stays Draft.** No main merge, no IPA release, no write to VeilLink.
>
> Last reviewed PR head: `b8bee2d993155c8ccb36cd50d4b81e32bad435a3` (continue updating for subsequent commits).
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
| Real persistent self-play validation | `NativeGomokuSelfPlay`, `AdaptiveBoardLearning` | `GomokuNativeTrainingJournal.swift` | Completed replay -> correct winner -> atomic JSON -> unique count; commits `529d2f0`, `7fbd4c5` | `GomokuTrainingIntegrityTests` pending current CI | WIRED |
| Learning snapshot and inference feedback | `AdaptiveBoardLearningSnapshot`, `LocalAIGameController` | `GomokuLearningRepertoire.swift`, `AdaptiveLearningGomokuSurface.swift` | Worker constructs verified snapshot; `GomokuBot.chooseMove(learning:)`; search budget reinforced; commits `8586d44`, `6752e06`, `0463b28` | `GomokuLearningRepertoireTests` pending iOS CI; full move-choice A/B validation outstanding | WIRED |
| 10/100/1000 native batches and stop protection | `NativeGomokuSelfPlay` | `NativeGomokuAppController.swift`, `InstrumentHomeView.swift` | Real runner -> generation-guarded result append; toggle independently gates self-play influence; commits `0463b28`, `4d87ab8` | Cancel/restart and endurance tests not completed | WIRED (partial) |
| Original bundled training seed | `GomokuBundledNativeSeed` and original JSON | Matching native file and resource | Verification exists; **verified first import not yet wired** | `GomokuNativeTrainingResourceTests` previously existed | STAGED |
| VeilLink `.vltrain.json` compatibility | `AdaptiveBoardLearning.swift` | `GomokuLegacyLearningImporter.swift` | Explicit picker -> FNV checksum -> complete Gomoku move replays -> staged unique import -> saved legacy book -> next search; commits `9307678`, `ba199e4`, `3c611ae` | `GomokuLegacyLearningImporterTests` pending; canonical original package test and large-file streaming not yet passed | WIRED (partial) |
| Chess/Gomoku isolation | `AdaptiveBoardLearningStore` scoped stores | `GomokuLegacyLearningImporter.swift` | Xiangqi records and x: aggregate positions never enter independent learning | Mixed-game and forged outcome cases committed; CI pending | WIRED |
| Interrupted match resume | `LocalBoardMatchStore.swift` | `VeilGomokuMatchArchive.swift`, `NativeGomokuAppController.swift`, `InstrumentHomeView.swift` | App init detects valid `.playing`; user explicitly resumes, replays state and restores id/side/difficulty; commits `224637e`, `8d86f56` | `GomokuRecoveryTests` pending; app-kill UI test missing | WIRED |
| Imported match timestamp fidelity | `VeilGomokuMatchArchive.swift` | `GomokuMatchTransfer.swift` | Validated import preserves original startedAt/updatedAt/completedAt rather than reconstructing times; commits `08b5477`, `27fdd9c` | `GomokuMatchTransferTests.testImportPreservesOriginalStartedAndCompletedTimestamps` pending | WIRED |
| Developer formation lab and signed lesson library | `DeveloperFormationLibrary.swift`, `BoardDeveloperLearningLabView.swift`, `DeveloperLearningLabGate.swift` | Source archived only; not complete standalone implementation | No complete runtime hookup or authorization gate | Not run | STAGED |
| Personal coach learning profile | `AdaptiveBoardLearning.swift` `PersonalBoardCoachProfile` | Existing search/archival state, no complete coach service | Not integrated in consumer UI | Not run | STAGED |
| Search trace, last move, fallback notices | `VeilEclipseSearchTraceStore` and original instrument UI | `VeilEclipseSearchTraceStore.swift`, `InstrumentHomeView.swift` | Real onExploredLine callback, last-move marker, visible fallback; commit `4d87ab8` | Previous visual tests; current realtime metrics and snapshots not verified | WIRED (partial) |
| Peer-to-peer BLE + authenticated E2EE match | Original VeilLink BLE/Pairing code | Original resources archived | Not integrated | No two-iPhone evidence | STAGED / BLOCKED on physical device for final acceptance |
| Standalone icon / signing / device install | VeilLink visual language | `project.yml`, app resources | Independent bundle id present, brand icon/signing work outstanding | Simulator not a substitute for device install | STAGED |

## CI and quality evidence (do not extrapolate)

- PR #13 after `b8bee2d`: `44776904081` Inbox Lite **success**; `44776904225` C++ and Python **success**.
- iOS Actions `44776904098`: **queued** at last check; **not** evidence of successful Swift, XCTest or UI test execution.
- Previous baseline CI `44769241993`: earlier Debug/Release success, 32 XCTest according to prior audit; new patches require their own tests and logs.

## Explicit unsatisfied gates

1. **P0:** Real learning snapshot is wired but benchmark A/B search move choice, large-scale performance, crash-safe import and database format parity are not accepted.
2. **P0:** Native batch pause/resume persistent checkpoints, real seed's first ingestion, separate repair/read-only tools and a truly indexed durable learning database remain incomplete.
3. **P0:** Standalone developer formation teaching, authorization and verified replay are not wired.
4. **P1:** Personal coach, full original instrumentation and UI/animation acceptance remain incomplete.
5. **P1:** BLE authentication/reliability and two physical phones require implementation and actual E2E evidence.
6. **P1:** Swift 6 strict concurrency checks, stable Release/XCTest, signing/device install and performance gates remain unproven at this head.

## Owner decision and rollback

**Decision: NOT MERGEABLE / NOT RELEASABLE** pending iOS CI, above P0 gates, parity review and Owner approval. All work stays in `integration/veillink-migration-consolidated` attached to PR #13. Revert individual new commits if regressions surface; never mutate `Legacy/Original/` bytes or the source `VeilLink` repository.

## TenGate Lite lane ownership

Current integration changes are authored under the Owner's explicit single-task direction, not proof of persistent Governor delegation. Do not silently grant ordinary Agents direct edit permission. Proposed lanes, only when assigned in `AGENT_INBOX/BOARD.json`: ENGINE / TRAINING / DATA / FORMATION / IOS / BLE / QA, with disjoint file ownership and INBOX_ONLY submissions.
