# ECLIPSE R24 · Adaptive Thinking / Zero-Value Search Suppression

**Status:** experimental feature branch stacked on the Thinking HUD Stage C3
Draft PR #57. **NOT** installed in `main`; not a trained neural time-allocation
head, not a model generation, and not proof of stronger Gomoku playing strength.

## Root cause

The original V2 compute policy accepted `EG_COMPUTE_MODE_ADAPTIVE` with
`max_wall_time_ms=0`, but the C++ implementation simply treated it as
**no hard deadline**. Search still exhausted its configured depth (or the
external node/cancellation limit), even after a stable decision. Its forcing-
four solver could repeat a costly depth-first search on quiet positions where
no first move could possibly begin a forcing-four line.

A fixed 20-second cutoff would conceal rather than solve this defect: easy
positions should stop after sufficient evidence, uncertain positions must be
allowed more computation without losing mandatory tactical defenses.

## Two implemented decision layers

### Layer 1 — logically unnecessary VCF prefix elimination

Before calling `prove_four`, `Search::analyze` already enumerates each legal
root and checks the immediate winning squares available *after* making that
move. Now the completed audit records whether **any** move creates a forcing-
four starter without permitting an immediate opponent win.

For THIS solver, `prove_four` can only succeed if such a root exists. When
the entire root set was checked and no starter exists, the solver skips its
impossible proof tree. This is a solver-specific necessary-condition
optimization; it does **not** certify the absence of longer VCT, double-three,
or tactics outside the solver. An incomplete audit never authorizes a skip.

Immediate win, immediate block and verified double-finish preflight are
unchanged and still override learned root bonuses.

### Layer 2 — conservative low-risk convergence

A new internal `AdaptiveConvergence` observes **only fully finished search
depths**. The optional early-stop path is enabled exclusively when the
Training Agent's actual V2 compute policy is `mode=adaptive`.

It refuses an early stop if ANY candidate reveals an opponent fork, ANY root
can start the existing forcing-four proof search, either root safety audit was
incomplete, the top and runner-up are too close, the chosen move changes
between adjacent depths, or the odd/even horizon score trends disagree.

It requires >=5 completed depths, >=4 consecutive well-separated decisions
for the same root and alternating parity stability. It stops at the first
completed depth satisfying those predicates and emits
`EG_SEARCH_REASON_STABLE_CONVERGENCE (7)`. **This is a heuristic plateau,
not a forced-win proof and not an Elo-strength guarantee.**

If uncertainty persists, the engine continues using the trainer-selected
`max_depth`, `max_nodes`, `max_wall_time_ms`, and cooperative cancellation.
No arbitrary 5.7/20/30-second application-imposed clamp was introduced.
The budgeted V2 mode retains its old depth-completion behavior.

### Operational effect

- Quiet/easy: avoid an impossible forcing-four proof tree and optionally
  stop after repeated, separated, parity-stable search results.
- Mandatory defense / live forced-four: do **not** use convergence to
  truncate unresolved tactical search.
- Highly ambiguous / multiple good candidates: keep searching.
- User cancels or exits match: native cancellation still owns the result.
- Existing Swift fallback: unchanged; no false claim that it executes this
  native rule, and no trained checkpoint has been changed.

The Thinking HUD displays an independently coded, truthful stop explanation
for reason 7; all existing native serial and model/checkpoint attestation
requirements remain.

## Validation

Added `eclipse_adaptive_convergence` CTest and extended
`EclipseThinkingHUDTests` covering confidence gate, close candidates,
unstable best, threatened root, original budgeted mode, completed depth,
real C++ mandatory immediate win and unique immediate block.

**Mandatory before promotion:**
1. Reproducible side-by-side paired native evaluations vs the frozen baseline
   for a stratified set of quiet/middle/forced-block/fork/VCF/VCT positions;
   compare best move, deadly error count, actual nodes, P50/P95 elapsed and
   reason-7 frequency, with model/engine/policy SHA unchanged except the
   intended search-policy algorithm revision.
2. Full real games with black/white swap, no tactical safety regression, and
   confidence ranges before claiming strength gain.
3. iOS simulator XCTest and iPhone/iPad memory, power, thermal, frame-time
   tests before enabling it in release. Failures keep prior search behavior.
4. A **genuinely learned** stopping head later needs per-depth training data
   and independent deeper-oracle labels: move regret, forced-tactic errors,
   counterfactual nodes/cost and family-held-out games. The current rule
   is deliberately hand-designed because the provided historical `.vltrain`
   exports do not independently prove a correct stopping label for each depth.

No model weights, data, Legacy/Original files, personal training records,
public Inbox or `main` have been modified by this change.
