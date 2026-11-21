# ADR-003 · Additive C++20 search telemetry ABI

Status: **experimental candidate, requires Owner review before merge**.

## Motivation

The existing research `eg_best_move` returns one legal-square index and exposes no
search-depth, actual node-count, stop reason or measured elapsed time. Without
these, a SwiftUI analysis console cannot truthfully display C++ search progress,
and an Arena benchmark cannot distinguish tactical preflight from incomplete
iterative deepening. This change does not turn the research core into the
production Swift ECLIPSE.

## API contract

`Engine/include/eclipse_c_api.h` retains **all previous symbols** and adds
`eg_best_move_diagnostics_v1(..., EGSearchDiagnosticsV1 *out)`.

- Before calling, set `out->size_bytes=sizeof(EGSearchDiagnosticsV1)`. On
  wrong size, null engine, or null output, it returns 0 without writing output.
- Success returns 1. This single search yields a move, completed search depth,
  visited negamax nodes, real wall-clock milliseconds and a categorical reason.
- Reason codes: COMPLETE=0, FORCED_WIN=1, FORCED_BLOCK=2, ONLY_MOVE=3,
  NO_MOVE=4, TIME_LIMIT=5. Terminal games report move=-1, NO_MOVE.
- Tactical win/block preflight intentionally counts zero **negamax** nodes and
  depth zero, because the current prototype does not expose its preflight work
  as search nodes. Do not portray zero as no computation.
- This API is synchronous and does not provide cancellation yet; call on a
  background worker with immutable board history. Do not invoke both functions
  to measure one search: that would perform two separate searches.
- No change to existing `eg_best_move` behavior, rules replay ABI v1, Swift
  app wiring or the original Seven-Tier Swift engine.

## Required gates before any default-engine switch

1. Keep existing C API and binary symbol ABI intact and run Linux/macOS C++
   builds and tests.
2. Verify the same mandatory win/block and terminal behavior with the new API,
   including failure leaving caller outputs unchanged.
3. Add C++-vs-Swift tactical comparisons and repeated-position profiles.
4. Add explicit per-search cancellation, generation validation and non-blocking
   Swift bridge **in a different reviewed change**.
5. Perform signed-device latency/thermal/reproducibility testing before
   deciding runtime adoption. No automated model or engine promotion.

## Rollback

Revert the files changed in this PR. No stored dataset or user state is written
and the Swift default has not been replaced.
