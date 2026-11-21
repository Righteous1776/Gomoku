# ECLIPSE Adaptive Search V3 — convergence, tactical risk & predicted marginal cost

**Owner request:** Stop treating `ADAPTIVE` as “think forever”; easy/clear positions should end early, but uncertain tactical positions should be allowed genuinely deeper search. The goal is actual decision quality per unit of compute, not an arbitrary universal seconds-per-move timer.

## Scope and backward compatibility

- This branch adds **opt-in versioned** `eg_analyze_compute_policy_v3` and `EGAdaptiveStopConfigV3`, preserving the exact original V2 ABI, trainer root settings, stored model checkpoint SHA, candidate ordering, verified weights and rules.
- V3 is selected for the verified native Astra/Sol **adaptive compute-policy mode** when maxDepth >= 2; budgeted mode and V1/V2 historical comparisons remain original. The engine identity must identify C++20 **V3 adaptive** to avoid mixing old/new strength evidence.
- The V3 caller supplies three **maximum useful budgets** (not minimum think times): currently 1,200 ms clear, 6,000 ms uncertain, 45,000 ms tactical/ambiguous. These are a **staging profile, not measured optimal values**. All remain bounded by a finite hard deadline; the remaining budget is not a promise to use every millisecond. MaxDepth, widths, root learning and candidate radius come from the verified trainer policy unchanged.
- No private games or positions are transmitted; no manual release/main merge.

## Actual V3 stopping evidence

1. Mandatory immediate wins/blocks and proof-first tactical checks remain ahead of heuristic stopping. They are not recast as probability estimates.
2. The initial forced-line proof is **also budgeted intelligently**: quiet boards spend only a short portion of the available budget there, while boards with detected opponent fork risk can spend up to one third of the maximum complex ceiling proving a forcing line. This avoids using nearly the entire move on the proof preflight in quiet positions.
3. After **each completely finished iterative-deepening round**, record its best move, native best-vs-runner-up *search-score gap*, best move stability, score drift and measured nodes/elapsed time. Incomplete depths NEVER count toward stability.
4. **Heuristic convergence** requires the same best move for a configured number of full rounds (currently 3), at least the minimum depth (currently 3), sufficient native runner-up separation, non-oscillating score and **no detected immediate fork risk**. This means *confidence supported by search evidence*, not “proved win.”
5. Remaining complexity budget adjusts based on current evidence: score ties, changed best move and fork risk all protect extra thinking time. Scores are uncalibrated native engine units, NOT calibrated chance of winning.
6. Predict the next round cost from the **actual previous depth node-growth factor** and elapsed time, clamped to avoid overflow/overconfidence. If the next depth is unlikely to complete inside the remaining useful budget, stop **before** spending it. The forecast is explicitly a heuristic, never reported as an observed measurement.
7. Stop outcomes preserve the distinction between `forced_win / forced_block`, `adaptive_converged`, `adaptive_effort_cap`, `adaptive_next_depth_cost`, `time_limit`, and `cancelled`. Unknown and missing metadata are never represented as proof.

## Testing and evidence controls

- `Engine/tests/test_adaptive_stop_v3.cpp`: exact V2 geometry echo, exact V3 stopping config echo, unmodified native game state, no-output-on-invalid, certified tactical win priority, single allowed legal root convergence, and original V2 compatibility.
- `EclipseThinkingHUDTests`: adaptive stop reason display keeps heuristic early termination distinct from mathematical proof.
- The additional V3 native regression includes a compulsory unique block, high requested depth under a finite hard time ceiling, and genuine V2 vs V3 behavior isolation. Proof-line ply count is **not** incorrectly reported as a completed iterative-search depth in V3.
- The developer HUD shows completed-round stability, uncalibrated native candidate gap, complexity tier and **estimated** next depth cost. Missing values are hidden rather than rendered as zero. Local P50/P95 windows are partitioned by model SHA, compute-policy SHA **and execution backend** so V2/V3 never share a latency distribution.
- **Pending until CI finishes:** exact-head CTest, iOS simulator XCTest/build, real iPhone/iPad performance, tactical regression suites, V2 versus V3 paired games with identical weights and budgets, 6x strength comparisons, and measured per-move P50/P95 + undersearch/timeout rates.
- New instrumentation evidence will be valid only after enough independent games and threat puzzles; a shorter wall-clock alone is not proof of improved quality.

## Known limitations and next calibration

- The first V3 policy uses measured **native root score gaps**, not calibrated inter-model win probability. It must not be compared directly across Astra and Sol.
- Forced VCF/VCT proof is still bounded by search-proven evidence; a partial proof result does not guarantee no hidden forced reply. Stable scores can miss long-horizon traps. Tactical regression must gate release.
- The 1.2/6/45-second tier ceilings and 3-round stability threshold are **engineering starting points**; only paired benchmarks/tactical hard positions should determine final shipped thresholds. The user-facing model does not inherit a hidden universal 20-second cap.
- Future training agents may provide distinct validated stopping profiles per checkpoint; those will require a new cryptographic policy identity and evidence ledger rather than silently changing SHA values.
