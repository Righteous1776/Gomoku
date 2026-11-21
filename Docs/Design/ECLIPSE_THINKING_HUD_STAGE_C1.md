# ECLIPSE Thinking HUD — Stage C1 verified candidate

Parent: Draft PR #52 / Issue #50. This is **not** Stage C full completion.

## Actual data

The C++ read-only Stage B snapshot contains the move selected by its last **fully completed** search depth. If the active loaded C++ model is real, the owner has explicitly entered developer teaching mode, the current board position has that cell empty and the HUD is still on that same live search, the C1 HUD reports that move as an *unproven current best candidate*, never as a proven win.

The existing wood board also displays a low-refresh, dashed, noninteractive hint circle only in that same authorized teaching mode and only when the existing visual opt-in is enabled. It is never enabled in formal matches. The overlay does not intercept board touches and does not introduce a second board or instrument card.

## Security and limitations

- `visibleTeachingCandidate` always hides the raw candidate for formal/postgame and incomplete-depth states, even if a malformed fixture sets a candidate.
- The actual C++ ranker has not yet emitted all candidate scores, a calibrated evaluation, the legal PV reply sequence or proof trees: **no heatmap/PV/forced tactic proof is claimed**.
- Test coverage: unit tests for formal/incomplete/invalid-coordinate fail-closed logic; remaining gate is iOS screenshot and interactive touch testing on a real device.
- Preserves original VeilLink UI outside the opt-in teaching hint, trained model identity, search decisions, compute policy, private training data and release branch.
