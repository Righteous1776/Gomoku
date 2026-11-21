# Gomoku V2.0.0 — ECLIPSE × VeilLink

## Included in the app
- Original VeilLink-derived 15×15 Gomoku board, owner-approved ECLIPSE icon and original instrument layout.
- Verified Astra V9 (314-tree) / Sol V9 (160-tree) native model binding, each attributed to its actual checkpoint SHA. Existing Swift fallback remains explicitly identified.
- Native Thinking HUD: elapsed time, completed search depth, nodes, last search termination, source-verified teaching-only candidate ranking and partial TT-backed PV evidence.
- Developer-only "analyze current position" action that never automatically plays or writes a formal training match.
- Improved concurrent native telemetry, measured P50/P95 sample gate and OS thermal pressure reporting.
- Experimental Adaptive Search V3 diagnostics kept distinct from formal tactical proof and classic V2 geometry.

## Research models included in the SOURCE repository, not promoted in the IPA
R04/R07 239/244/249/259/274/289-tree LightGBM research checkpoints (34D R07) and R01–R07 audit. These models do not replace the compiled V9 Astra/Sol app engine. R07-249 failed one of nine independent safety gates and needs a separate 34-dimensional runtime, matched tactical tests and strength promotion before actual gameplay integration.

## IPA artifact disclosure
The attached IPA is an **unsigned Release-iphoneos package** built by GitHub Actions and verified with the SHA-256 checksum. It is NOT an Apple-signed installable App Store/TestFlight build; installing on an ordinary iPhone requires an appropriate signing/provisioning workflow.

Bundle identifier: `studio.zeo.gomoku`  
App version: **2.0.0**  
Build: **200**

## Release assurance
GitHub Actions gates validate actual C++ CTest, Python tests and model digests, iOS simulator XCTest, Release-iphoneos build, IPA and private-data bundle scan. This is not a claim of physical-device CPU/thermal/energy certification or R07 production chess-strength acceptance.

No private `.vltrain` raw exports, original user/friend match histories, private SQLite training stores or keys are intentionally bundled.
