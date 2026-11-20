# Freestyle Gomoku rules and migration/data contracts

## Rules

Upstream `GomokuState.size` is 15; 225 intersections, black/host first. Mainline should retain exactly original win/draw and valid turn/seat behavior. Default standalone rule ID: `freestyle-15`; no forbidden moves/Renju restrictions unless separate rules engine developed. `BoardBotDifficulty` cases (ordered): `relaxed`, `balanced`, `advanced`, `master`, `grandmaster` (2×), `legendary` (4×), `zenith` (6×). Multipliers are computation/search budgets, **not** actual measured strength.

## Known original stores / data namespaces

Original sources inspected:

- `AdaptiveBoardLearningStore`: default `Application Support/VeilLink/adaptive-board-learning-gomoku-v2.json` (game-scoped, separate Xiangqi suffix).
- `LocalAIGameController` native self-play: `Application Support/VeilLink/gomoku-native-selfplay-v1.json`.
- `VeilGomokuMatchArchive`: `Application Support/VeilLink/GomokuMatchHistoryV1/` per-match UUID JSON with hash-based legacy identifier compatibility, append-only histories.
- `LocalBoardMatchStore`: last-match recovery storage; exact file name/shape must be obtained from original source at pinned SHA.
- `GomokuFormationDiscoveryStore`: `UserDefaults` key `VeilLink.Gomoku.FormationNovelty.v1`.
- Original learning export format string: `veillink.board-learning.export.v1`.
- Bundled seed: `VeilLink/Resources/GomokuNativeTrainingSeed.json`, verified by source code checksum/version and rules replay.

**Critical caveat:** a new Bundle ID creates a new iOS app sandbox. Reusing original `VeilLink` directory path *inside the new sandbox* does not access the old app's files. Provide an explicit user-initiated export/import, with schema validations and rollback.

## Standalone storage plan

`Application Support/Gomoku/` with `matches/`, `learning/`, `selfplay/`, `formations/`, `migration/`. Separate the source-archive namespace (`VeilLink` export version) from new normalized exports (`gomoku.archive.v1`). Stores are append-only/atomic where applicable; no arbitrary 40-game/512KB limits. File-size input protection must use streaming, large-file caps based on device resources and explicit user-visible failure rather than silent truncation. Daily backup and app upgrade must never remove old records.

## Import workflow

1. User explicitly selects source `.json`/`.zip` through Files; use security-scoped URL and background staged copy.
2. Enumerate allowed files and safe paths; reject ZIP traversal, symlinks, excessive decompression ratios, and unknown entry types.
3. Per-file checksums, format/version checks, replay legal moves, winner check, reject cross-game data.
4. Show count: total, eligible, duplicates, conflicts, invalid; no silently hidden failures.
5. Commit atomically into standalone sandbox only after preflight; on cancellation leave old state intact.
6. Validate read-after-write and preserve original exports and backup; support rollback.

## Sync / multiplayer

Network turn sequencing based on authoritative monotonic turn sequence, NOT device wall-clock timestamps; lost/reordered messages trigger snapshot repair. `session_id`, `ply`, rule-set ID, board hash and explicit sender role are required.

## Included desktop migration prototype

`Migration/package_user_data.py` implements explicit selection, content allow-list, streamed SHA256 ZIP manifest verification, ZIP path traversal rejection, decompression-ratio and configurable resource budget, atomic package creation and no-overwrite extraction for preselected Gomoku data files. It **does not** parse/semantically migrate all Swift source store versions and **cannot** read another iOS app sandbox. Work must implement native Swift UI access, actual original-record replay validation and approved user export path, plus tests before calling data migration complete.
