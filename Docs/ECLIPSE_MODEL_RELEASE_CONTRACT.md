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

Four independent *compute effort* options: **轻度、标准、高、极高**. This preserves the source's actual seven original Swift profile tiers through an explicit model+effort mapping (not a name-only display toggle). The separate existing full/economy search-mode preference remains user controlled.

The seven original HIGH-profile native budgets remain precisely **130/260/520/950/1900/3800/5700 ms** and are measured/compared via the original Swift source and research C++ engine. Budget is an upper bound, not an Elo multiple, guaranteed node count, or literal battery expense. Astra + 极高 maps to the original zenith 6× profile.

**Important:** The four shipped-option *search-policy* families do not yet correspond to four independently trained neural checkpoints. Luna really uses Classic Swift; Terra/Sol/Astra share frozen R10 ordering and Swift UnifiedSearch with distinct budget/depth/width configurations. Do not call this a four-weight neural product until the training Agent supplies independently auditable artifacts.

## What is "R29"?

`R29` is treated as a **training revision / candidate checkpoint**, NOT a release name, NOT GitHub PR #29, and NOT proof it is the best model. No R29 artifact / cryptographic fingerprint is currently confirmed in the accessible repository. Until its actual checkpoint, metadata and execution route have been provided and audited, the UI must not show "R29 Astra" as a production option.

A newly trained revision becomes `ECLIPSE 1.1 Astra` or `1.1 Sol` only after its model family, actual loaded artifact SHA-256, separate engine interface, data provenance and strength gates are verified and the Owner authorizes promotion. Do not modify the bytes behind existing `1.0` model IDs.

## Training Agent adaptive-search governance (Owner proposal)

The specialized Training Agent governance charter is at [Docs/Operations/TRAINING_AGENT_CONSTITUTION.md](Operations/TRAINING_AGENT_CONSTITUTION.md). It defines Astra/Sol paired candidate training, adaptive-think early-stop evidence, hard-limit accounting, strict forced-tactic safety, separate search-stop metrics, private artifact handling, and Owner-only authorization of handoff / Node C. This charter is **proposed** until Owner review and merge. Existing production 130/260/520/950/1900/3800/5700 ms budgets and the exact strict handoff metadata schema remain unchanged. Extra adaptive diagnostics belong in a separate local/private evaluation sidecar until an authorized schema revision.

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
