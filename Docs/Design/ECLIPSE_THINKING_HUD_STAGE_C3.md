# ECLIPSE Thinking HUD — Stage C3 · Native PV → Gomoku replay

**Scope:** stacked on draft PR #55 (Stage C2); linked to Issue #50. Research/owner review only.
No main merge, release IPA, weights, private datasets, or decision-policy change.

## Implemented code path

`Search::analyze` → `CompletedPVSink` → `EGSearchPVSnapshotV1` →
`EclipseCppProductionAdapter.liveCompletedPV()` →
`NativeGomokuAppController.thinkingHUDSnapshot()` →
`EclipseThinkingHUDSnapshot.visibleTeachingPV` →
`EclipseThinkingHUDView` ⇄ `GomokuBoardView`.

1. **Real source, not animation:** the C++ search extracts a bounded prefix from its
   last *fully completed* root iteration using exact transposition-table entries
   already computed in the same search; there is **no additional scoring pass**,
   heuristic reply invention, or request for a second best-move search. The
   principal branch is potentially *shorter than its root depth* because
   sparse/evicted/inexact TT entries terminate the line; search policy and
   selected best move are unchanged.
2. **Optional atomic, additive ABI:** `eg_read_search_pv_v1` reads a 16-move
   snapshot with exact per-engine `search_serial`, `completed_depth`, zero
   absent count. The same Stage B atomic sequence reader also protects
   existing ranked roots; cancel/new V2 search/play/undo/reset invalidates
   the previous PV. Wrong output size leaves the caller buffer unchanged.
3. **Strong matching:** Swift checks range, no duplicates, count ≤ depth,
   native search serial, native live completed depth, active best move,
   actual 15×15 current board occupancy, alternating turns and terminal
   GomokuState replay. A mismatched/invalid prefix is discarded.
4. **Fair play and privacy:** no PV for formal play, postgame replay, missing
   authorization, incomplete depth, Swift fallback, abandoned run or
   invalid search. The original VeilLink wood board receives only a
   non-interactive, optional teaching-only overlay of numbered translucent
   hypothetical stones. Nothing is appended to match histories.
5. **Client controls:** `上一手 / 下一步` traverses the actual current
   replayable prefix only; reset, restored match, model/effort selection,
   teaching exit, completed move and new AI search clear the count.
   The HUD explicitly labels it as a **search-derived hypothetical prefix,
   not a forced-win proof or a probability**.

## Verified identity and training integration boundary

- The Stage C3 source automatically works with an actual `EclipseCppProductionAdapter`
  instance once the selected V9 model SHA and approved compute policy SHA are
  verified. Mere selection in UI is not evidence of loaded C++ inference.
- Original Swift fallback keeps honest time/depth/node telemetry when
  provided, but **does not pretend to have a native PV**.
- R07 is a separate *34-dimensional LightGBM research checkpoint*; it is
  NOT part of the V9 26-dimensional deployed C++ scorer. R07 must first
  receive a separately validated runner, native ABI/feature parity,
  checkpoint digest registration, and paired-match strength gates. It is
  deliberately not published or renamed as a 2.0 production model here.
- Stage C2 ranked-root overlay remains heuristic *priority order*, not
  calibrated win probability; Stage C3 PV is a non-certified principal
  *prefix*, not VCF/VCT proof. No false claim of solver completion.

## Source verification and remaining acceptance

Source tests added/extended:
- `eclipse_live_search_snapshot_v1`: native PV ABI size,
  same-serial published data, complete depth, forced preflight empty PV,
  reset invalidation and legal alternating replay.
- `EclipseThinkingHUDTests`: no formal/postgame leak, root mismatch,
  duplicate/occupied/out-of-bounds moves, incomplete depth and reset.
- Core build + iOS native/XCTest are expected to run on GitHub CI/macOS
  for this PR; **not verified merely by creating the branch**.

**Still unavailable:** genuine VCF/VCT proof tree, full-depth certified
opponent refutations where TT is sparse, calibrated evaluation scores,
native per-depth move-change history, independent R07 engine runtime,
physical-device frame P95, CPU, peak RSS, energy and temperature in °C.
These cannot be made real with UI code alone.

**Rollback:** revert this isolated Stage C3 PR to Stage C2 (#55); additive
ABI and optional SwiftUI overlays have no persistent data migration.
