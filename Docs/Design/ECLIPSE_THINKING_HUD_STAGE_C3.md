# ECLIPSE Thinking HUD — Stage C3 exact-TT-backed PV prefix

This patch stacks on Stage C2 PR #55 and Issue #50.

## Actual evidence chain

1. The existing native C++ engine chooses `round_best` only after an entire search depth finishes, without a time budget interruption. It already stores exact transposition-table entries with flags and depth, subject to its normal cutoffs.
2. The optional C++ observer constructs a **maximum 16-ply prefix**, beginning with that completed-depth best root. For each hypothetical reply it follows an existing TT entry **only** if `flag == exact` and its stored depth meets the required remaining depth. No second search, guessed opponent response or heuristic extension is allowed.
3. Before publication, the algorithm restores every temporary trial stone in reverse order. The actual search board, hash, choice, limits, and move/iteration order are unchanged.
4. `EGPVPrefixSnapshotV1` is an additive C ABI with count, per-engine serial, completed depth and 16 integer moves, protected by the same atomic sequence lock as Stage B.
5. The Swift adapter checks the ABI size, count, uniqueness, bounds and serial. The controller additionally checks exact depth and first move against the same search's live snapshot, and **replays all hypothetical stones on the real current board with correct alternating side and terminal rules**.
6. Only authorized developer teaching discloses PV. Formal match and postgame contexts never reveal an unplayed search continuation. The text labels the line as a **partial PV prefix, not a proof**.

## Verifications and omissions

- Native CTest asserts PV serial, completed-depth linkage, first move equality, board coordinate uniqueness and full reset invalidation.
- iOS XCTest asserts no formal-match leak and no incomplete-depth line.
- Full-width PV from all search leaves cannot be claimed because the TT stores a bounded set of exact entries. When no exact entry exists the prefix is truncated, not fabricated.
- Full VCF/VCT proof trees, threat types and validated all-candidate scores remain open. The user must not construe an exact TT reply as a mathematical forced win.
- iOS simulator, physical iPhone/iPad, energy/thermals and Sol take-over require separate acceptance. No `main` merge, release, change of weights/policy, or private training content.
