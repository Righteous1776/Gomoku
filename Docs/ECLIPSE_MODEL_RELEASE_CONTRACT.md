# ECLIPSE · Model Registry / Training Agent / Swift Parity Contract — R15

## Naming authority and semantics

**Owner decides product acceptance; model-system coordinator names released families and versions; the separate training Agent trains models and submits checkpoints.** These responsibilities are independent. The coordinator never renames a budget increase as a new trained generation.

The canonical user-facing format is **ECLIPSE {generation} {family}**, e.g. **ECLIPSE 1.0 Astra**. The product currently exposes four model families:

| Model identity | Positioning | Real current backend | Default effort |
|---|---|---|---|
| `eclipse-1.0-luna` — 1.0 Luna | 轻量经典 | Original Swift Classic search | 标准 |
| `eclipse-1.0-terra` — 1.0 Terra | 稳健均衡 | Original Swift R10/R12/R13 unified | 标准 |
| `eclipse-1.0-sol` — 1.0 Sol | 攻防策略 | Original Swift R10/R12/R13 unified | 标准 |
| `eclipse-1.0-astra` — 1.0 Astra | 高算力深层推演 | Original Swift R10/R12/R13 unified | 极高 |

The former compute effort options (**轻度、标准、高、极高**) survive solely for **historical original-Swift compatibility** and user preference. They are NOT binding limits for a new training-Agent checkpoint. A verified trainer-controlled model may disable this legacy selector entirely.

**Owner correction (R16):** the seven historical HIGH-profile Swift budgets **130/260/520/950/1900/3800/5700 ms** are comparison baselines only, not maximum permitted training/inference time. Neither model version nor Astra branding fixes a time/node ceiling. The specialized **training Agent is the sole authority for each trained checkpoint's stopping/computation strategy**. A null wall-time or node ceiling explicitly means *no deadline*, and the runtime must not replace it with a 30ms/5.7s/20s or 180k/3M-node hidden clamp. Search still needs finite, trainer-chosen depth/branching, cooperative cancellation, privacy, memory/thermal protections, and safe app lifecycle behavior. Do not misrepresent a high hardware cost as Elo strength.

**Important:** The four shipped-option *search-policy* families do not yet correspond to four independently trained neural checkpoints. Luna really uses Classic Swift; Terra/Sol/Astra share frozen R10 ordering and Swift UnifiedSearch with distinct budget/depth/width configurations. Do not call this a four-weight neural product until the training Agent supplies independently auditable artifacts.

## What is "R29"?

`R29` is treated as a **training revision / candidate checkpoint**, NOT a release name, NOT GitHub PR #29, and NOT proof it is the best model. No R29 artifact / cryptographic fingerprint is currently confirmed in the accessible repository. Until its actual checkpoint, metadata and execution route have been provided and audited, the UI must not show "R29 Astra" as a production option.

A newly trained revision becomes `ECLIPSE 1.1 Astra` or `1.1 Sol` only after its model family, actual loaded artifact SHA-256, separate engine interface, data provenance and strength gates are verified and the Owner authorizes promotion. Do not modify the bytes behind existing `1.0` model IDs.

## Trainer-controlled compute contract (R16)

The private handoff schema is `eclipse.trainer.handoff.v2`, including `compute_policy` (not a hard-coded list of historical times). A valid policy specifies:

- `mode = adaptive` and `max_wall_time_ms = null`: no artificial wall-clock cutoff, or `mode = budgeted` with **any positive trainer-chosen value**. No arbitrary 5.7s/20s maximum.
- `max_nodes = null`: no fixed global node limit, or any positive trainer-chosen node target.
- `max_depth`, `root_width`, `reply_width`, `continuation_width`, `forced_line_depth`, and `candidate_radius`: the training Agent's search geometry, validated against real 15×15 board semantics, not a product-tier lookup table.
- `compute_policy_sha256` is included in the candidate's `--identity` output, in addition to the actual loaded checkpoint SHA-256. Two matching names without matching bytes are not accepted.

The iOS integration's `EclipseVerifiedTrainerExecution` requires matching loaded-checkpoint and policy hashes before allowing trainer-selected settings to replace original Swift budgets. It is an **integration token**, not itself proof that the external binary executed: runtime attestation is independently required by `trainer_handoff_gate.py`. No such R29 candidate is currently registered in public production; until then the old Swift is a **reference fallback**, not a model budget decision by this integration Agent.

The original seven budget headless arena remains frozen as a historical regression benchmark. New trained candidate testing may use any positive budget or no wall deadline; strength promotion remains a separate game outcome gate.

## Separate Training Agent handoff

The training Agent must provide **privately**:
1. Candidate name, training revision (e.g. R29), architecture and model policy family; immutable checkpoint file plus SHA-256; exact load/verification method; base-checkpoint lineage.
2. Source evidence manifests and training setup (learning schedule, seeds, epochs, dedup/weight policy, reproducible training script), excluding private raw match histories from shared CI.
3. **Repeated tactical history is not disposable duplicate data.** Preserve ordered actions, individual provenance, maxima within overlapping source snapshots, and source-identical groups; do not count D4 rotations as independent wins.
4. A real deterministic inference runner that accepts `--best <ordered legal move indices> --ms <budget>` and reports `move, elapsed_ms, nodes, completed_depth`, plus independent model identity + actually loaded checkpoint hash.
5. Evaluations: color-swapped paired games vs the **original trained Swift** in comparable conditions, per-model effort and device class; mandatory five/block, defense/forks/VCF, no-search timeout regressions, legal move + privacy checks. Exploratory bootstrap ≠ proven noninferiority.

Only the coordinating integration branch selects the actual candidate model after checking identity, hash and gates. Research C++ prototype is **not promoted** merely because earlier 200 games scored C++ 99 / Swift 101 at 75 ms under EMPTY private Swift learning. All seven production effort budgets, real trained private memory and iOS device verification remain hard blockers.

## Version and archive migration

Version is a real **training/algorithm generation**, not a compute switch. `ModelSelection(model,compute)` is archived as `eclipse-1.0-astra|extreme`. Old raw tiers (`relaxed..zenith`) and earlier draft `eclipse-1.1-sol`, `eclipse-1.1-astra`, `eclipse-1.2-astra` are migrated on read into model+effort; no signed source history is rewritten. Switching model or effort during an active match prompts and resets to avoid mixed training attribution. `lastExecutedModel` is set only on real legal search output; emergency fallback is never counted as model success.

## Release gates / governance

All candidate upgrades remain DRAFT and separate from VeilLink/main. No user-private checkpoint or match history may be pushed to public GitHub/Inbox. Validate the exact PR head with Core/Inbox, headless real Swift/C++ tactical and strength tests, iOS XCTest/Release/privacy, and local trained-state and hardware audits. Then Owner reviews whether a **new** model generation may become selectable. Do not auto-merge, overwrite old versions or release IPA.
