# Gomoku V1.0.0 RC1 — unsigned engineering preview

This is a **prerelease**, not the signed and installable final V1.0.0.

- App bundle identifier: \`studio.zeo.gomoku\`; marketing version \`1.0.0\`.
- Migration source pinned to PR #13 at \`b567ab07eaf819b28a878a2c9a5bd292ce0313a4\`. This public release branch is squashed onto clean \`main\` history; it excludes \`Migration/\` owner game evidence and \`Legacy/Original/\` nonruntime archives.
- Built from XcodeGen on macOS with a generic \`Release-iphoneos\` device target and \`CODE_SIGNING_ALLOWED=NO\`. Actual \`.app\` and \`.ipa\` are scanned to exclude personal training archives; simulator XCTest must pass before prerelease publication.
- **The included IPA is UNSIGNED. It cannot be installed normally on an iPhone.** Signed physical-device delivery needs Apple developer signing, provisioning and real device acceptance.
- Still not fully verified: physical BLE two-phone match, owner-only local training ingestion, 10,000-game endurance, night/day iPhone/iPad screenshot comparison and final independent AppIcon.
- Private historical commits on development PR #13 remain independently visible in the public repository. A clean release snapshot does **not** retroactively make those commits private.

The original 2,000 self-play seed records contain 236 distinct completed trajectories, not 2,000 independent games; 102 owner-private games live outside this release candidate.
