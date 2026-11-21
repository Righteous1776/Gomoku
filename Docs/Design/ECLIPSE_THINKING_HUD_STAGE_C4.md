# ECLIPSE Thinking HUD — Stage C4: operational developer teaching analysis

## Problem fixed

Stages C1/C2/C3 implemented actual native hints, root ranks and TT-backed PV prefixes, but the existing **developer teaching mode only let the user manually place stones**. It never scheduled AI analysis and therefore those teaching visualizations had no runtime entry point.

## Actual behavior

- The existing, owner-authenticated, manual teaching UI now exposes **“分析当前局面 · 不自动落子”** inside the original, collapsible VeilLink runtime instruments footer.
- Only `developerTeachingMode && developerAuthorization.isAuthorized && !isThinking && status == 0` can start it. The device-owner authorization is rechecked at completion and whenever exposing a candidate.
- Requires a **successfully attested native C++ Astra/Sol checkpoint and exact trainer compute policy**; unavailable models explicitly report no verified analysis. No heuristic fake candidate or Swift fallback is attributed to the native model.
- The detached worker uses the same `GomokuLearningRepertoire`, `EclipseCppRootLearningPolicy`, model policy and formation inputs as regular ECLIPSE dispatch, with the player to analyze set to the board's current turn.
- The successful C++ result is kept in memory on the unchanged board as an **idle, read-only native handle** for genuine ranked root heatmap and replay-verified PV prefix. It is never made into an actual move. The teaching board and user-recorded lesson sequence are unchanged.
- Any manual move, reset, model/side change or leaving teaching drops the previous result. If device-owner authorization expires, the data is not disclosed, and a worker completing after expiry discards its evidence.
- All visualizations use the original wood board, stay opt-in, are rate-limited to ≤2 Hz, and have `allowsHitTesting(false)` for all overlays. The latest incomplete/unknown search values never get a fake completion percentage.

## Deliberately NOT included

- No automatic AI move during manual teaching, no generated training game, no private `.vltrain` export, no learned-weight mutation, no GitHub main merge or release.
- No full-length PV, fabricated outcome probability, scored all-225 heatmap or forced-win certificate.
- Physical iPhone/iPad CPU/RSS, energy, touch latency and thermal behavior still require actual-device acceptance.

## Verification plan

1. Native CTest / all source regression gates from Stages B/C1/C2/C3, plus exact-head iOS simulator build & XCTest.
2. XCTest verifies unauthorized analysis does not start/mutate the board and that a post-run review snapshot is never visible in formal mode.
3. On iPhone/iPad, manually authenticate, stage a legal midgame position, invoke analysis, check **no stone is placed** and visualizations persist until the next manual move or authorization expiry.
4. Confirm the original match archive count, training journal and model-identity receipts remain unchanged by teaching analysis.
