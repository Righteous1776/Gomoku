# Gomoku package file index

Extraction creates `Gomoku/` (the new repository root).

Payload before index and integrity list: **64 files**.

## Top-level

- `.gitattributes` — 1 file(s)
- `.github` — 5 file(s)
- `.gitignore` — 1 file(s)
- `AGENTS.md` — 1 file(s)
- `AGENT_INBOX` — 4 file(s)
- `Apps` — 6 file(s)
- `Arena` — 1 file(s)
- `CMakeLists.txt` — 1 file(s)
- `Docs` — 11 file(s)
- `Engine` — 9 file(s)
- `LICENSE` — 1 file(s)
- `Legacy` — 1 file(s)
- `Makefile` — 1 file(s)
- `Migration` — 4 file(s)
- `Provenance` — 1 file(s)
- `README.md` — 1 file(s)
- `Scripts` — 4 file(s)
- `Training` — 7 file(s)
- `VERIFICATION_STATUS.md` — 1 file(s)
- `WORK_HANDOFF.md` — 1 file(s)
- `WORK_START_HERE.txt` — 1 file(s)
- `project.yml` — 1 file(s)

## Full inventory

| File | Bytes |
|---|---:|
| `.gitattributes` | 203 |
| `.github/CODEOWNERS` | 160 |
| `.github/ISSUE_TEMPLATE/integration_request.md` | 571 |
| `.github/workflows/cpp-python-ci.yml` | 920 |
| `.github/workflows/ios-build.yml` | 930 |
| `.github/workflows/unsigned-ipa-dev.yml` | 1,279 |
| `.gitignore` | 400 |
| `AGENTS.md` | 1,893 |
| `AGENT_INBOX/00_READ_ME_FIRST.md` | 737 |
| `AGENT_INBOX/01_GOVERNOR_IDENTITY.md` | 424 |
| `AGENT_INBOX/02_RULES.md` | 907 |
| `AGENT_INBOX/submissions/.gitkeep` | 0 |
| `Apps/iOS/Gomoku/BoardInstrumentView.swift` | 2,973 |
| `Apps/iOS/Gomoku/EngineBridge.swift` | 2,721 |
| `Apps/iOS/Gomoku/GomokuApp.swift` | 146 |
| `Apps/iOS/Gomoku/InstrumentHomeView.swift` | 3,939 |
| `Apps/iOS/Gomoku/Native/Bridge.h` | 82 |
| `Apps/iOS/GomokuTests/GomokuBridgeTests.swift` | 547 |
| `Arena/compare.py` | 2,261 |
| `CMakeLists.txt` | 115 |
| `Docs/Architecture/ARCHITECTURE.md` | 4,037 |
| `Docs/Architecture/DATA_AND_RULES.md` | 3,847 |
| `Docs/Architecture/MULTIPLAYER.md` | 1,692 |
| `Docs/Architecture/SOURCE_FIDELITY.md` | 2,718 |
| `Docs/Architecture/UI_FIDELITY.md` | 2,123 |
| `Docs/Operations/EXECUTION_COMMANDS.md` | 1,785 |
| `Docs/Operations/IPA_BUILD.md` | 1,694 |
| `Docs/Operations/REPOSITORY_POLICY.md` | 1,411 |
| `Docs/QA/PARITY_TEST_PLAN.md` | 2,373 |
| `Docs/QA/RELEASE_GATES.md` | 2,621 |
| `Docs/Roadmap/DELIVERY_PLAN.md` | 2,638 |
| `Engine/CMakeLists.txt` | 856 |
| `Engine/include/eclipse_c_api.h` | 968 |
| `Engine/src/board.cpp` | 3,659 |
| `Engine/src/board.hpp` | 585 |
| `Engine/src/eclipse_c_api.cpp` | 1,083 |
| `Engine/src/gomoku_cli.cpp` | 3,297 |
| `Engine/src/search.cpp` | 3,081 |
| `Engine/src/search.hpp` | 502 |
| `Engine/tests/test_rules.cpp` | 1,498 |
| `LICENSE` | 1,066 |
| `Legacy/Original/.gitkeep` | 0 |
| `Makefile` | 446 |
| `Migration/contracts/gomoku_export_v1.schema.json` | 966 |
| `Migration/evidence/.gitkeep` | 0 |
| `Migration/package_user_data.py` | 8,587 |
| `Migration/source_inventory.json` | 17,534 |
| `Provenance/UPSTREAM.json` | 823 |
| `README.md` | 5,077 |
| `Scripts/audit_migration.py` | 786 |
| `Scripts/migrate_from_veillink.py` | 4,099 |
| `Scripts/prepare_repo.sh` | 505 |
| `Scripts/verify_package.py` | 1,073 |
| `Training/configs/research_policy_v1.json` | 395 |
| `Training/requirements-train.txt` | 108 |
| `Training/selfplay.py` | 2,002 |
| `Training/tests/test_migration_package.py` | 2,020 |
| `Training/tests/test_validate_dataset.py` | 1,133 |
| `Training/train_policy.py` | 3,182 |
| `Training/validate_dataset.py` | 2,558 |
| `VERIFICATION_STATUS.md` | 2,247 |
| `WORK_HANDOFF.md` | 16,538 |
| `WORK_START_HERE.txt` | 1,876 |
| `project.yml` | 1,487 |

Original current VeilLink Swift sources are staged later by `Scripts/migrate_from_veillink.py` and not represented in this bootstrap ZIP.
