# ECLIPSE Thinking HUD — Stage A implementation ledger

- Requirement: [Issue #50](https://github.com/Righteous1776/Gomoku/issues/50).
- UI reference: [PR #49](https://github.com/Righteous1776/Gomoku/pull/49) `bf31cbbc133189ca8d8adc892dc132d729452cb3`.
- This feature branch is **separate** from model binding PR #48 and the source design PR #49. No merge or app release implied.

## Actually implemented, Stage A

1. `EclipseThinkingHUDView` is a collapsible, low-rate text footer inside the ONE original VeilLink `VeilEclipseRuntimeInstruments` card. It adds **no new gauge card** or board overlay, and preserves the original source code of all four independently attested VeilLink visual components. Persistent detail settings: **简洁 / 专业 / 开发者**; original wooden board gestures and themes unchanged.
2. `EclipseThinkingHUDSnapshot.version=1` is a read-only presentation projection. Each in-flight `searchID` is a new UUID associated with the actual current board turn and selected verified runtime. It is cleared on match restart, model swap, side swap, incomplete match restore and developer teaching exit. Native C++ startup identity is attested by the existing `EclipseCppProductionAdapter.make` / C ABI V4 forest SHA before the UI is given a SHA. A missing or failed native runtime is explicitly shown as **Swift fallback**, not Astra/Sol.
3. Actual elapsed time is derived from `ProcessInfo.processInfo.systemUptime` (monotonic). Swift running depth/nodes are read from the preexisting tokenized measured trace store. C++ V2 has no continuous callback: its nodes and depth **remain unavailable until completion**. At return, original C ABI provides actual `run.search.reason`; the selected C++ `GomokuBotMove.nativeStopReason` carries this directly without changing search behavior. Its time-limit code cannot distinguish time vs node limit, so the HUD says both.
4. Detailed panel averages measured node count by elapsed for *average NPS* only when data actually exists and elapsed≥0.5 seconds. No fabricated phase, PV, win probability, candidate heatmap, tactical proof or score. `GomokuBotMove.score=0` is not shown.
5. Developer view shows optional actual SHA-256, search ID and position revision. Sensitive owner `.vltrain`, SQLite, and private positions are never fed to HUD.
6. Strict formal-match disclosure: no best move, PV, forced defensive move or threat overlay before AI has played. Teaching is only selected by the existing authenticated `developerTeachingMode` path; spectator mode is not advertised as working yet. Existing board visual opt-in is explicitly gated to the authorized teaching mode, with the board overlay and search trace producer both rejecting live formal-match branches; regular match fairness is protected.

## Not implemented / prerequisites

- **Stage B:** C++ additive, versioned, snapshot-only live API, monotonic epoch and per-iteration proof, cancellation safety across concurrency, and real iPhone overhead.
- **Stage C:** validated playable PV / genuine candidate ranking / tactical proof / comparable evaluation scores. Unsupported here.
- **Stage D:** true Astra/Sol resource fallback switch and Pareto/latency/energy diagnostics. No new compute policy changes.
- Exact iOS XCTest and screenshot comparison, 60fps drag/board touches, iPad dynamic type and thermals must be verified from CI/device. Local source checks alone are not a sign-off.

## Protected controls

No changes to `Engine/src/search.cpp`, model forests, checkpoint hashes, compute policies, self-play or raw training evidence. No main merge, signing, or publishing. A failed C++ move cannot be counted as a 2.0 model win.
