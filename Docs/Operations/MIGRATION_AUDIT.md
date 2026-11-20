# VeilLink → Gomoku migration audit

Baseline: Gomoku a819c1ea0ff82846a077ee856c49aacd7191bf10; VeilLink 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32. Source main still equals pinned baseline. Owner request: audit omissions and migrate all relevant Gomoku source. Upstream remains read-only.

## Inventory before migration
71 files: SwiftUI/C++ prototype shell; C++20 core and C ABI; Python training/data tools; Arena; migration scripts/docs; Lite Inbox and CI. No actual upstream code in Legacy/Original (only .gitkeep). Production Swift engine, original UI/theme, native training/archive, Bluetooth/security source and original tests absent.

## Exact source stage
All 69 original manifest entries exist, expanded to 110 files. Added six entries missed by the original inventory: LICENSE, AgentGameAdapter.swift, AgentGameRegistry.swift, TrainedGamePolicyRuntime.swift, two Gomoku operations documents. Total 75 entries / 116 files. Both optional and required missing counts: zero.

Ran migrate_from_veillink.py dry-run, --execute, then audit_migration.py: audited 116 files; problems 0. Each exact source byte hash is in Provenance/migrated_sources.sha256.json. Binary assets are preserved as source references, not automatically added to the shipped app. Original source licenses remain alongside copied resources. No personal match exports, chats, private certificates, unverified NPZ files or unmerged training submissions copied.

## Functional integration status
| Area | Source stage | Standalone application verification |
|---|---|---|
| Swift ECLIPSE, trained ordering, mandatory tactical gates | PASS | NOT RUN; current shell still uses C++ prototype |
| Seven tiers, 2x/4x/6x budgets | PASS | NOT RUN |
| Original board, compute console, traces, instrumentAuto | PASS | NOT RUN; provisional UI still needs replacement |
| Native self-play, formation learning, seed | PASS | NOT RUN |
| Archives, recovery, learning storage and import references | PASS | NOT RUN; sandbox-safe native migration pending |
| BLE, E2EE, pairing references | PASS | NOT RUN; standalone session separation and real devices pending |
| Original regression tests | PASS | NOT RUN; adapted iOS test host pending |
| C++/Python baseline | Already present | Existing prototype, not Swift parity certification |
| Signed IPA | NOT APPLICABLE | BLOCKED: signing and device acceptance not supplied |

## Dependency boundary
Provenance/transitive_dependency_candidates.json lists static type-reference candidates outside staged source. This is an over-approximation (comments, local names and unrelated AppModel references can match), NOT a compiler-verified closure. Original AppModel, MiniGames, Models, GameLobbyView, MiniGameViews and LocalAIGameController span messenger and other games. Copying all other app services to silence dependencies would defeat the standalone/privacy contract.

Source preservation stage is complete against the expanded inventory. Full playable-app migration is NOT complete: isolated Swift modules, UI binding, native import/recovery and purpose-scoped encrypted game transport still require implementation and macOS/iOS validation. This Linux host has no swift/swiftc/xcodebuild. Do not label source copying as app integration or a usable IPA.

## Reproduction
python3 Scripts/migrate_from_veillink.py --source /path/to/pinned-clean-VeilLink
python3 Scripts/migrate_from_veillink.py --source /path/to/pinned-clean-VeilLink --execute
python3 Scripts/audit_migration.py

## Handoff
Task SOURCE is REVIEW, not MERGED. Next: review this immutable-source PR; isolate Gomoku engine and rule models in an adapted target, retain byte-identical originals, run original XCTest corpus on a macOS runner, then replace the provisional UI. Do not promote the C++ prototype or claim release while these gates are missing.
