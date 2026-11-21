# Gomoku V2.0.0 — ECLIPSE × VeilLink

## Included in the app
- Original VeilLink-derived 15×15 Gomoku board, owner-approved ECLIPSE icon and original instrument layout.
- Verified Astra V9 (314-tree) / Sol V9 (160-tree) native model binding, each attributed to its actual checkpoint SHA. Existing Swift fallback remains explicitly identified.
- Native Thinking HUD: elapsed time, completed search depth, nodes, last search termination, source-verified teaching-only candidate ranking and partial TT-backed PV evidence.
- Developer-only "analyze current position" action that never automatically plays or writes a formal training match.
- Improved concurrent native telemetry, measured P50/P95 sample gate and OS thermal pressure reporting.
- Experimental Adaptive Search V3 diagnostics kept distinct from formal tactical proof and classic V2 geometry.

## New MODEL generation: ECLIPSE 3.0 — research assets

The newly uploaded R07 family is designated **ECLIPSE 3.0 (research generation)**, distinct from the **Gomoku application V2.0.0** release version. Five full 34D R07 weights — 244, 249, 259, 274 and 289 LightGBM trees — are preserved in the source repository and each is registered with its own immutable SHA-256. R04 239-tree weights remain the historical predecessor, not renamed as generation 3.0.

The iOS developer diagnostics can identify **ECLIPSE 3.0 · R07-249 (34D / 249 trees)** but MUST show **research only / not loaded**. The active playable compiled model remains Astra V9 314-tree or Sol V9 160-tree (**ECLIPSE 2.0**) until a genuine 34D native feature extractor, identical feature vectors, independent tactical regression and checkpoint attestation all pass.

The R07-249 research candidate passed **8/9** exploratory evaluation gates and is not an approved production replacement. No 3.0 Sol distilled weight is present, so none is invented or labelled as deployed. Research weights are NOT automatically included in the iOS IPA as runnable engine models.

## IPA artifact disclosure
The attached IPA is an **unsigned Release-iphoneos package** built by GitHub Actions and verified with the SHA-256 checksum. It is NOT an Apple-signed installable App Store/TestFlight build; installing on an ordinary iPhone requires an appropriate signing/provisioning workflow.

Bundle identifier: `studio.zeo.gomoku`  
App version: **2.0.0**  
Build: **200**

## Release assurance
GitHub Actions gates validate actual C++ CTest, Python tests and model digests, iOS simulator XCTest, Release-iphoneos build, IPA and private-data bundle scan. This is not a claim of physical-device CPU/thermal/energy certification or R07 production chess-strength acceptance.

No private `.vltrain` raw exports, original user/friend match histories, private SQLite training stores or keys are intentionally bundled.
