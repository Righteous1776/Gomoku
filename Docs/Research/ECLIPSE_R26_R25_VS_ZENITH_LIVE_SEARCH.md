# ECLIPSE R26 · R25-273 Native Search vs Original VeilLink Tianyuan 6×

**Current scope:** actual research-only native 34D ranking forest integration and
headless color-swapped games. **Not** a production upgrade or a claim that
R25 learned the full decision algorithm.

## The two distinct comparisons

1. **Isolate the new weight:** C++ R07-249 versus C++ R25-273. Each side
   executes the **same** native C++ PVS/VCF source, identical time, nodes,
   search depths, candidate widths and forced-line policy; models differ only
   by SHA-pinned LightGBM 34D forest. Both games for each synthetic opening
   swap contestant colors and independently replay every move.
2. **Test real product-level competition:** original compiled VeilLink Swift
   `GomokuBot` with tier `zenith`, profile `HIGH`, no owner/private
   personalization, versus R25-273 actually loaded inside C++ PVS/VCF.
   Both receive 5,700ms per move, 30,000 node and depth 7 limits.
   C++ uses root width 18, reply width 30, continuation 20, forcing depth 6
   and radius 3. Original Swift tactical preflight and C++ internals remain
   **different algorithms**, so identical budgets alone do not isolate the
   effect of weights in this second comparison.

## Weight and execution identity

| Candidate | Trees | Features | Original text SHA-256 |
|---|---:|---:|---|
| R07-249 | 249 | 34 | `d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234` |
| R25-273 | 273 | 34 | `bc9b1aabb6ae00de22e77943f5bd8c35ecff1b490e2ea74d5b10609b876f428d` |

R25 is a **real** new 273-tree research model from the original Tianyuan
384-position synthetic teacher experiment. Its heldout teacher Top-1 stayed
21/42 = 50% before and after imitation training; it has not earned promotion.

New distinct native C ABI `eg_load_zenith_r25_student_v6`,
`eg_active_zenith_r25_sha256_v6`, and
`eg_zenith_r25_score_v6` fail closed on wrong bytes, count, digest,
model identity or invalid forest structure. The existing ABI v5 R07 model
remains intact, and `eg_active_trained_checkpoint_sha256_v2` still cannot
falsely attest a non-promoted model. R25 binds a forest pointer to the same
**actual** C++ `Search::analyze` used by V2, not a UI alias.

### Engineering caveats

- The C++ engine does have mandatory tactical wins/blocks, forced-line proof
  and PVS. This is not byte-identical to the original Swift decision pipeline:
  `GomokuBot` has its own root safety and learning rules.
- The R07/R25 26D feature extractor is a preserved C++ port. CI checks
  representative exact 34D Python source fixtures. Full randomized parity
  against the owner's original private R04 feature implementation is an
  additional release gate before using this model on device.
- Training on a teacher's *final move* does not teach its original search tree
  traversal, confidence, budget adaptation, full attack-defense proof or
  personal learning policy. The native solver **must remain** alongside R25.
- Native whole-game comparisons are on CI/Linux, not an iPhone 13 Pro.
  Device P50/P95, memory, energy and thermal behavior remain unmeasured.
- An 8-game pilot can establish engine execution correctness and catch
  regressions, **not** certify Elo or dominance.

## Runnable commands

Native R25 tactical and weight-gate test:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel 2 --target eclipse_r25_zenith_search_tests eclipse_r25_vs_r07_arena gomoku_cli
ctest --test-dir build -R '^eclipse_r25_zenith_search$' --output-on-failure
```

Same engine R07 vs R25, with exchanged colors (each opening is two games):

```bash
build/Engine/eclipse_r25_vs_r07_arena \
  --r07 Training/research/r07/checkpoints/eclipse_r07_34d_249_trees.txt \
  --r25 Training/research/r07/candidates/zenith_r25/eclipse_r07_zenith_teacher_273_trees.txt \
  --ms 300 --depth 5 --nodes 30000 --openings 4 \
  > Arena/evidence/r26-r25-r07-300ms-games.jsonl

python3 Engine/tests/validate_r25_paired_arena.py \
  Arena/evidence/r26-r25-r07-300ms-games.jsonl
```

Direct original Swift 6x headless match (actual Swift binary compiled in
`.github/workflows/eclipse-r26-zenith-live-arena.yml`):

```bash
python3 Arena/zenith_r25_vs_original.py \
  --swift build/swift_original_zenith6x \
  --cpp build/Engine/gomoku_cli \
  --weights Training/research/r07/candidates/zenith_r25/eclipse_r07_zenith_teacher_273_trees.txt \
  --pairs 1 --source-root . \
  > Arena/evidence/r26-r25-vs-original-zenith6x-5700ms.jsonl

python3 Engine/tests/validate_r25_vs_original.py \
  Arena/evidence/r26-r25-vs-original-zenith6x-5700ms.jsonl
```

The CI workflows upload **every actual game move** in JSONL. An independent
Python replay independently verifies win, draw, legality and paired
black/white accounting. No user `.vltrain`, SQLite or private archives enter
the job.

## Promotion decision

A strong declaration requires **both**:
- Safe tactical parity with no regression, real weights/identity and
  deterministic full-board validation (actual CI passing).
- Larger, independent and diverse paired games with confidence intervals;
  compute fairness including whole-decision latency and real-device
  performance. No promotion if win rate cannot be distinguished from a tie or
  if the new ordering increases missed forced defenses.

**Never replace the installed Astra model automatically from an R26 research
branch**, even when a build is green.
