# ECLIPSE algorithmic parity and strength evaluation

## A. Baseline preservation

Freeze original Swift `GomokuBot.swift`, `VeilGomokuUnifiedSearch.swift`, `VeilGomokuUnifiedBridge.swift`, `EclipseTrainedOrdering.swift`, ECLIPSE R12/R13 feature toggles, `GomokuCounterForkR4.swift`, local self-play, formation learning. Record exact source hash, compile original and run original upstream XCTest fixtures in an adapted native test host. Do not replace original code with C++ until true end-to-end tests exist.

## B. Deterministic semantic corpus

1. Empty board center, first/second color, legal move (225 positions).
2. Opponent threatens immediate five — forced block, even near timeout.
3. Own immediate five — wins before arbitrary heuristic.
4. Double threat, fork, counter-fork, defense after 1/2/3 plies.
5. Boundary and diagonals, simultaneous threats, overline according to original freestyle semantics.
6. Full board draw, end-of-match no-move, restart, undo and nonterminal state restored.
7. Seven difficulty budgets including exact 2×/4×/6× cap behavior and unmodified original tactical obligations.
8. Imported learned data and formation preference cannot force illegal move or override tactical loss.
9. Runtime cancellation and stale search callback cannot modify newer game.
10. Repeated replay yields identical board hash and validated winner on both engine implementations.

## C. Competitive comparison

- Evaluate paired games with swapped colors under same hardware device class, time per move and rules; multiple openings and randomized seeds. Report W/L/D and confidence interval, not manufactured human rank or Elo.
- Benchmarks separated for native iPhone/iPad CPU, desktop x86/arm and thermal state. Compare common time or node budgets, never equate 6× search with sixfold chess strength.
- Real ECLIPSE source with native training evidence remains default until C++ has no tactical regressions and no statistically meaningful strength regression on large enough matched corpus. Promotion requires explicit owner approval and recorded data.

## D. Diagnostics

Every search event should include: engine revision, ruleset ID, search phase, root candidates, completed depth, nodes, elapsed ms, fallback reason, selected legal move, model ID, session ID and board hash. Never log chat text, unrelated personal data, or fabricate branches.
