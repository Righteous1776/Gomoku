# ECLIPSE R17 — C++20 Trainer Compute ABI V2

## Architecture — separate training, engine, and release authority

```
Owner
  └─ Specialized Training Agent — creates R29 or later checkpoint,
       selects actual search-compute policy and supplies immutable SHA-256
       │
       ▼
  Integration/Verification Gate (Arena/trainer_handoff_gate.py)
       ├─ checkpoint identity and actual loaded bytes digest
       ├─ compute_policy_sha256, provenance and private-data policy
       └─ paired games vs original trained Swift / all accepted device gates
       │
       ├─ Native Swift search (incumbent; currently production default)
       │     GomokuBot → VeilGomokuUnifiedBridge → VeilGomokuUnifiedSearch
       │
       └─ C++20 experimental search (R17)
             Swift DEBUG fixture
               → eg_analyze_compute_policy_v2(C ABI)
               → eclipse::Search::analyze(ComputePolicy)
               → validated board + forced win/block/forks + PVS
               → EGComputeRunV2 (move, nodes, elapsed, depth, EXACT policy echo)
```

## Invariants

**The Training Agent decides each checkpoint's compute policy.** The integrator
must not change 130–5700ms historical Swift baseline budgets into mandatory
limits for new models. R17 C++ accepts `mode=adaptive, max_wall_time_ms=0,
max_nodes=0` without a hidden cutoff. A budgeted policy can request 123456ms or
any other positive 64-bit representable value; no hard 20s clipping. Depth,
root/reply/continuation widths, forcing depth, and candidate radius come from
the passed policy. The board itself imposes the only structural maxima:
225 intersections, 14-cell radius, <=225 search depth. A finite search can
terminate on a proof, completed depth, explicit trainer budget or cancellation.

**V1 is frozen for historical experiment comparison.** Original
`eg_best_move_diagnostics_v1` and `eg_best_move_root_policy_v1` remain available.
They continue to use historical search defaults and are NOT proof of R29
checkpoint loading. The legacy C ABI is still compatible with original Swift
and the 200-game 75ms comparator.

**V2 is actually executed, not a display label.**
`EGComputePolicyV2` is passed through Swift’s C bridge to the real
`eclipse::Search` fields. `EGComputeRunV2.applied_policy` echoes the parameters
received by the native search, alongside measured nodes, completed iterative
depth, wall-clock time and a legal root. The iOS debug fixture verifies each
field and correlates it with the Swift policy digest. The separate CLI
`--policy-v2` executes the same ABI. A provisional R29 identity or a
checkpoint hash without actual loaded-file proof cannot select production C++.

**C ABI remains fail-closed.** Struct sizes, zeroed reserved words, policy
mode, root masks and bounded learning bonuses are checked before search.
A verified immediate win or mandatory block overrides root bonuses. Invalid
requests, error/cancellation or illegal root policy do not partially overwrite
caller outputs or change the board. Only `eg_cancel_search_v2` may be called
concurrently on the same engine; play/reset/destroy are disallowed until
analysis returns.

**Cancellation is not a trainer budget.** The user leaving a game or revoking
the task can cancel analysis even with unlimited time. Memory pressure,
thermal limits, iOS process suspension, and device owner safety preferences
need separate monitoring; unlimited thinking does not mean non-terminating
search may freeze UI indefinitely.

## V2 CLI example — synthetic research only

For a trainer-authored adaptive policy with no deadline/nodes cap,
max depth 15, root width 60, reply width 40, continuation width 30,
forcing-line depth 10 and radius 5:

```sh
build/Engine/gomoku_cli \
  --best 0,15,1,16,2,17,3,18 \
  --policy-v2 0,0,0,15,60,40,30,10,5
```

For an explicitly trainer-selected 123456ms and 70M node budget:

```sh
build/Engine/gomoku_cli \
  --best 0,15,1,16,2,17,3,18 \
  --policy-v2 1,123456,70000000,15,60,40,30,10,5
```

The CLI returns the chosen move and an `applied_compute_policy` object.
Neither command runs a new trained checkpoint; the current C++ evaluator is
the research frozen R10-derived ordering. R17 introduces compute-architecture
parity, NOT personalized trained-strength parity.

## Remaining blocking gates

1. Actual R29 or newer trainer checkpoint artifact, exact SHA-256 and concrete
   C++/iOS loader, rather than prototype frozen model data.
2. Per-checkpoint policy digest verified against *loaded runtime* and modeled
   Swift fallback/rollback; no uncontrolled changes to installed models.
3. Per-checkpoint and per-effort tactical + real-game tests against the actual
   trained Swift ECLIPSE, paired opening and color swaps, independent confidence
   intervals; repeated user-discovered tactics retained as evidence but their
   re-exports/rotations are not independent wins.
4. iPhone/iPad hardware memory, battery and temperature behavior; production
   cannot promote C++ without Owner approval.
5. Only verified release model generations get user-facing ECLIPSE version
   numbers (Luna / Terra / Sol / Astra). Increases in thinking time alone do
   not create a new release version.

No private `.vltrain`, private SQLite, position maps or training checkpoints
were committed to the public GitHub PR.
