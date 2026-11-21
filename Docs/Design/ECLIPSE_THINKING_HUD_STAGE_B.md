# ECLIPSE Thinking HUD — Stage B / Issue #50

## Scope and provenance

- Parent baseline: PR #51 / `59324be6807908ebbb8a6e95585115d458b00a47`; independent feature branch (no main changes).
- Preserves the exact VeilLink R17 original runtime card, board/UI and the existing Swift/C++ search policies. No model or training changes.
- New *optional* C++20 read-only `EGSearchLiveSnapshotV1` via `eg_read_live_search_v1` and `Search::ProgressSink`.
- The current 2 Hz or slower SwiftUI footer reads true nodes and **completed** iterative-deepening depth during C++ V2 search, rather than only after it returns.
- Normal search root ranking, tactical checks, negamax, width/depth limits, cutoff rules and selected Astra/Sol forest remain unchanged.

## Evidence architecture

- Native writer sequence-protects all atomic values; a read either receives a coherent search state or fails without altering its output. One search per engine is still mandatory. `eg_cancel_search_v2` remains the only concurrent-safe mutating call.
- Serial increments on each validated V2 search; engine reset/play/undo/model selector invalidates previous native telemetry. Application already associates each turn with a fresh `UUID`, selected engine identity, and board revision.
- Nodes are sampled at every 2048 `limit_reached` checks (not every UI frame); each fully finished root iteration publishes its actual depth/best move. Final diagnostics are copied from the same search. Preflight/forced-win early returns publish truthful final values, no synthetic progress.
- Root best move is available inside the native snapshot for **future authorized replay only**; the existing HUD exposes ONLY elapsed/nodes/completed depth and never leaks an unplayed candidate in formal competition.
- `score=0` is an ABI placeholder, not a win probability or draw prediction. This stage neither manufactures PV nor heatmap nor threat certificates.

## Verification / remaining gates

- Native `eclipse_live_search_snapshot_v1` CTest: idle/invalid output, real forced win, serial, reset invalidation, asynchronous live read and cancellation. Included in existing C++ CI.
- iOS `EclipseThinkingHUDTests`: direct C ABI smoke; Stage A reset and fairness tests remain.
- On real iPhone/iPad: pending Xcode XCTest result, screenshot/gesture audit, 60fps performance trace and CPU/thermal/energy profiling. **No device measurements claimed** until recorded.
- Stage C still requires validated full candidate ranking, hypothetical reply PV with legal moves and rigorously sourced tactical proof. Stage D requires real device budget/thermal/energy samples and explicitly validated Sol takeover, not a fictional live demo.
- Never merge or release this branch automatically; no private `.vltrain`, SQLite or personal game histories checked in.

## Acceptance convention

A successful GitHub CTest + iOS test is required but NOT a substitute for physical device profiling. A percentage computed from the 4 named stages would be misleading: Stage B source implementation is not Stage C/D acceptance.
