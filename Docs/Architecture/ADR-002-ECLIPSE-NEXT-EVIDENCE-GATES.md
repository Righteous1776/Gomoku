# ADR-002 · ECLIPSE NEXT evidence-gated architecture (2026-11-21)

Status: **proposed on isolated feature branch**, not approved for production promotion.

## Direction: one product, three independently verifiable layers

| Layer | Ownership | Current binding |
| --- | --- | --- |
| SwiftUI + original native Swift ECLIPSE | Current production/default decision maker and seven-level experience | Keep unchanged; instrumentAuto UI and legacy learning contracts remain authoritative |
| C++20 portable rules/search with a versioned C ABI | Experimental engine for portable search and arena comparisons | Existing `eg_rules_replay_v1` and `eg_best_move`; **not** promoted |
| Python research + Arena | Dataset validation, experiment provenance, training and comparison | Python JSONL validator, append-only counts, independent position/replay tests |

This repository **already contains** all three scaffolds. Do not rewrite the working native Swift engine solely to claim a new language stack. A real migration requires an evidence-backed, independently switchable implementation. The proposed sequence is:

1. Freeze Swift behavior and provenances, preserve seven levels and verified training sources.
2. Make C++ rules / status / legal move behavior match independent Python and adapted native Swift fixtures.
3. Establish defensive/tactical corpus and fail the build on C++ forced-move regressions.
4. Add explicit cancellation, board snapshot and search diagnostics to an additive **versioned C API**, with Owner review before modifying public interfaces.
5. Replay the same curated positions against native Swift and C++ under comparable time, device and rules; report results, not anecdotal Elo.
6. Only after measured non-regression and an explicit Owner approval, consider switching the app's default. No automatic cutover.

## Research safety gate introduced in this PR

- `Arena/tactical_gate.py` consumes strictly synthetic, versioned tactical positions and launches the research CLI. Each scenario verifies history legality, the tactical obligation and the selected move.
- `Arena/fixtures/freestyle15_tactics_v1.json` defines initial direct wins and forced single-move blocks. This is a **minimum safety gate**, not proof of strong search or parity to Tianyuan/Swift ECLIPSE.
- GitHub C++/Python CI executes this Arena check. Its results must not be reused to label Swift parity or six-times strength as PASS.

## Real training data: repetition is evidence, not disposable redundancy

`Training/tactical_evidence.py` audits only **explicitly supplied and already normalized** `eclipse.selfplay.v1` JSONL. It validates every completed game and counts every record:

- An exact ordered move sequence and its multiplicity; same full final board with a different move order stays distinct.
- An order-sensitive prefix at configurable length, so frequent strategic continuations can be investigated.
- Dataset SHA256 and aggregated frequency counters, with no raw player games in reports.
- A deterministic audit that never silently removes samples, chooses a training weight, or asserts that a repetition beats Tianyuan 6.

**Distinguish evidence from conclusions:** repeated sequences are interesting candidates. To assert that an opening reliably defeats a particular engine requires independent reproducible matches with alternating colors, known opponent build/settings, legal move proof, and uncertainty estimates. No player data is staged into GitHub by this PR.

This audit does **not** convert private `.vltrain.json` records: VeilLink's original export schema and the user's consent must be validated before conversion. Until then, those files stay local and outside Git. Existing `train_policy.py` remains an explicitly experimental baseline, with no promotion or new inference weights in the iOS target.

## PR review and rollout gates

- [x] Isolated change; no `Legacy/Original`, VeilLink, signing, IPA or iOS runtime edit.
- [x] Add Python unit tests checking duplicate preservation, ordered prefixes and invalid-record rejection.
- [x] Add C++ CLI tactical gate to CI with synthetic fixtures.
- [ ] GitHub C++/Python Actions green on this **exact** branch head.
- [ ] Native Swift/C++ tactical parity evaluation on matched scenarios and devices.
- [ ] Independent real-game training migration and provenance audit.
- [ ] Owner approval for any runtime default or public ABI promotion.

Rollback: close this PR or revert its changes; the production Swift AI, existing datasets, legacy import and C ABI are untouched.
