# ECLIPSE R25 · Tianyuan 6× original teacher → R07-249 student

**Status: research pipeline, not model promotion.** This is the first *actual* source-executing teacher/student transfer; it does not claim that a 249-tree forest has learned or replaced the entire search algorithm.

## 1. What the original teacher actually executes

The compilation target for the teacher is **the frozen original VeilLink Swift** `Legacy/Original/VeilLink/Agent/Games/`, not a reimplementation or a guessed lookalike.

The source audit on 2026-11-22 compared seven key frozen Gomoku files with `Righteous1776/VeilLink@main` using exact Git Blob SHA; all seven match.

| Decision chain | Original teacher source | Transfer behavior |
|---|---|---|
| Board legality and terminal checks | `GomokuDomain.swift`, `GomokuBot.swift` | **Preserve original code**; no neural/GBDT replacement for legal moves |
| Immediate winning five and forced block | `GomokuBot.swift` mandatory scan | Keep rule authority; record teacher final move; cannot treat rule labels as learned search |
| Immediate two-turn winning fork / opponent fork safety | `GomokuCounterForkR4.swift` | Source-preserved; never allow a heuristic learned root score to override a proven loss |
| R10 ranking, positional learning, formation guidance | `EclipseTrainedOrdering.swift`, `GomokuFormationLearning.swift` | Teacher currently uses **empty private learning**, **disabled personal formation preferences**; no private data |
| Forced four and PVS iterative deepening | `VeilGomokuUnifiedBridge.swift`, `VeilGomokuUnifiedSearch.swift` | Keep full original algorithm; record each real completed-depth trace and legal PV |
| 6× computing budget | `EclipseDifficultyPolicy.swift` | `HIGH` + `zenith`: 5700 ms / 30000 nodes / depth 7 / width 18 / forced line depth 6 |

The 6× tier means **compute-budget multiplier**, not a 6× strength multiplier. Time, node, depth and forcing-depth values are caps, not observed achievements. Empty personal learning is essential: the teacher does not silently ingest owner or friend's saved records.

## 2. Actual implementation

1. `Arena/SwiftGomokuBotReference.swift`: additive `--trace` when invoked with `--tier zenith --ms 5700`; emits measured nodes, wall time, final legal move and **only real** completed-depth traces including PV; normal existing `--best` behavior is unchanged.
2. `Arena/zenith_teacher_dataset.py`: creates strictly public synthetic, legal and nonterminal positions; executes the compiled original Swift teacher on each. Checks actual teacher profile, returned move legality, PV replay, completed-depth consistency, source hashes and D4 opening-family IDs. All rows are labeled `public_synthetic_only`.
3. `Training/research/r07/source/zenith_features.py`: standalone exact R04 26D + R07 8D port; regression vectors were obtained from the original local R04/R07 files, not invented.
4. `Training/research/r07/zenith_distillation.py`: verifies original **R07-249 SHA-256** `d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234`, rejects invalid teacher records, excludes depth-zero rule decisions from search-imitation training, splits by D4 opening family and appends limited LightGBM LambdaRank residual trees. It evaluates independent holdout teacher Top-1/Top-3 **before and after**.
5. `.github/workflows/eclipse-zenith-teacher-distillation.yml`: builds **original Swift** from its frozen source, runs feature/safety tests, collects actual 6× decisions, trains candidate checkpoint, publishes exact generated checkpoint + source/metrics as an **Actions artifact**, with no `main` merge or production selection.

### Reproduction via GitHub Actions

The PR runs a 48-public-position research smoke plus residual training. A deliberate manual `workflow_dispatch` allows 96/192/384 independent synthetic positions. For a local Ubuntu environment with Swift, Python 3 and pip installed, use the same build/source commands from the workflow, then:

```bash
python3 Arena/zenith_teacher_dataset.py \
  --swift build/swift_zenith6x_teacher \
  --samples 192 --seed 20261122 --budget-ms 5700 \
  --source-root . \
  --out Arena/evidence/zenith6x-teacher-public-synthetic.jsonl

python3 Training/research/r07/zenith_distillation.py \
  --dataset Arena/evidence/zenith6x-teacher-public-synthetic.jsonl \
  --out-dir Training/research/r07/outputs/zenith_candidate \
  --rounds 24
```

Do not run teacher data generation on user privacy archives. The training code **does not** upload private records.

## 3. Four explicit quality boundaries

- **Source parity vs chess strength:** source hash parity proves the teacher actually executes the original code. It does not prove that its search is objectively optimal or that an R07 student can imitate it perfectly.
- **Static ordering vs deep search:** residual LightGBM only learns the teacher's *root action preferences*. VCF, PVS, candidate-width control, attack/defense search, cancellation and legal checks remain **deterministic engine algorithms**. These cannot honestly be claimed to reside inside a 34D static-ranking weight.
- **Teacher-move agreement vs win rate:** holdout Top-1 measures imitation, not games won. Both student and baseline must be compared in the **same full search engine**, with identical compute, color-swapped openings, tactical gates, and confidence intervals before claiming strength gain.
- **Training vs release:** new checkpoint hashes are output by CI; all output is `promotion_authorized:false`. No automatic Swift/C++ runtime activation, no model-ID spoofing, no `main` merge, no IPA release.

## 4. What full learning would additionally require

To learn **how long to think**, collect **per-depth** teacher traces with outcome or stronger deeper-oracle decision-regret labels and measured node/time cost; a single teacher action is insufficient. To transfer **counter-fork / VCF proof behavior**, train tactical reasoning on independently proven attack-defense sequences and retain the original solver as a hard safety gate. To transfer **personal formation learning**, a separate explicit privacy-reviewed consent and clean data split is required; this implementation does not use it.

Next promotion gates: (1) source/feature parity; (2) heldout teacher agreement without regression; (3) no new missed wins/blocks on independent tactics; (4) ≥100 color-swapped opening pairs against original exact `zenith` on matched device budgets; (5) P50/P95, nodes, thermal and checkpoint attribution; (6) owner review. A partial, exploratory trained checkpoint is **not** renamed to the verified Astra 3.0 model.
