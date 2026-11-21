# ECLIPSE Thinking HUD — Stage C2 actual root-ranking heatmap

Stacked on PR #54 (D1), PR #53 (C1) and PR #52 (B). Implements part of Issue #50 Stage C; **does not claim a full PV or threat proof**.

## Data source

- The C++ `Search::analyze` already computes `ranked = root_ordered(eligible, min(root_width, ...))` after tactical and fork checks. An optional observer copies the **same ranked roots used for the actual depth search**, avoiding any second scorer pass, synthesized score or search-policy change.
- Additive `EGRankedRootsSnapshotV1` exposes at most 16 legal root indices in actual priority order, protected by the same sequence-checked atomic snapshot and per-engine search serial as Stage B.
- The Swift adapter rejects malformed rank counts, duplicate/illegal cells or mismatch with the active native search serial; the controller checks the actual local board for occupied indices and gates all disclosure to authenticated developer teaching.
- Original wooden board opt-in displays a small transparent ordinal-intensity overlay at <=2Hz; 16 true root positions max. This layer does not intercept taps, does not alter the original board in formal matches, and does not claim calibrated evaluation or win probability. The HUD explicitly labels rankings.
- Native CTest verifies shortlist count, actual move legality, uniqueness, same serial and reset invalidation; Swift XCTest verifies formal-match embargo.

## Explicitly pending

- A full search-derived legal PV with alternating moves and depth provenance, actual opponent refutations, and ability to replay the principal variation.
- Distinct tactical proof tags for forced defense, live-three, double-threat and certified VCF/VCT proof lines; an engine reason code without moves is insufficient.
- Dedicated iOS UI performance, simulator screenshot and physical iPhone/iPad drag/thermal certification.

No model switch, changed search choices, signing/release, `main` merge or private owner training data.
