# Gomoku / ECLIPSE — independent repository engineering package

**Purpose:** A ready-to-give-to-ChatGPT-Work bootstrap repository and a reproducible migration harness to extract the *actual* VeilLink five-in-a-row application into an independent Gomoku IPA and grow the ECLIPSE cross-platform chess/board-AI research stack.

**Important status:** This package contains a compiled and tested **C++20 experimental baseline**, an isolated native iOS shell, basic Python self-play / dataset validation / research policy training, migration automation, CI workflows, and a complete Work handoff. **It does NOT yet contain the current VeilLink Swift ECLIPSE original code, a compiled signed IPA, an already created GitHub remote, or a measured parity-certified C++ port.** These are explicit Work execution requirements in [`WORK_HANDOFF.md`](WORK_HANDOFF.md).

## Product targets

| Dimension | Contract |
|---|---|
| Product | `Gomoku` |
| Owner/repo | `Righteous1776/Gomoku` (create PRIVATE first) |
| Bundle ID | `studio.zeo.gomoku` |
| AI | `ECLIPSE`, original Swift retained until parity gates pass |
| iOS design | Exact VeilLink `instrumentAuto` (“拟物仪器”), light/dark/system palette retained; all other theme pickers removed |
| Rules | Original freestyle 15x15; rule variants only via explicit separate rule-set interfaces |
| Research stack | C++20 + Python/PyTorch |
| App | Swift 5.9 + SwiftUI; XcodeGen `project.yml` |
| Platform target | iOS 17+ / iPadOS 17+ (intentional new app minimum; source app may differ) |
| Original repo | `Righteous1776/VeilLink` at pinned SHA `0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32` |
| License | MIT, preserve ZeoStudio notice and third-party provenance |

## Contents

- `Apps/iOS/Gomoku/`: Buildable SwiftUI + C bridge shell. **The theme is provisional until exact upstream UI transplant.**
- `Engine/`: Independent C++20 15x15 freestyle rules/search prototype + C ABI + terminal CLI + smoke tests.
- `Training/`: Standard Python JSONL self-play/validation and optional PyTorch research policy.
- `Arena/`: Paired black/white automatic match harness.
- `Migration/`: Pinned original-source inventory, extraction and data contracts.
- `Legacy/Original/`: Source-fidelity stage destination (empty until Work runs migration).
- `Docs/`: Full requirements, architecture, acceptance and release gates.
- `.github/`: Non-destructive CI and manual developer unsigned IPA packaging.
- `AGENT_INBOX/`: Owner/Governor/Lane staging protocol, isolated from upstream governance.

## Linux/Windows/macOS: validate portable engine

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel
ctest --test-dir build --output-on-failure
python3 -m unittest discover -s Training/tests -v
python3 Training/selfplay.py --engine build/Engine/gomoku_cli --games 1 --ms 2 --out Training/outputs/sample.jsonl
python3 Training/validate_dataset.py --path Training/outputs/sample.jsonl
```

## macOS only: generate and build iOS shell

```sh
brew install xcodegen
xcodegen generate --spec project.yml
xcodebuild -project Gomoku.xcodeproj -scheme Gomoku -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

This is a build procedure, not a claim that iOS compilation was tested here. Work must execute it on a macOS runner and fix compiler/integration errors.

## Stage exact current VeilLink source (Work)

```sh
git clone https://github.com/Righteous1776/VeilLink.git /tmp/VeilLink-gomoku-source
git -C /tmp/VeilLink-gomoku-source checkout 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32
python3 Scripts/migrate_from_veillink.py --source /tmp/VeilLink-gomoku-source
python3 Scripts/migrate_from_veillink.py --source /tmp/VeilLink-gomoku-source --execute
python3 Scripts/audit_migration.py
```

These commands STAGE, not COMPILE, the legacy source. The actual one-to-one Swift source and design extraction is owned by Work as specified in its handoff.

## Where to start

**Work:** Read [`WORK_HANDOFF.md`](WORK_HANDOFF.md) in full and execute all named integration gates. **Human:** Open [`Docs/Roadmap/DELIVERY_PLAN.md`](Docs/Roadmap/DELIVERY_PLAN.md) and [`Docs/QA/RELEASE_GATES.md`](Docs/QA/RELEASE_GATES.md).

## Safe selected-data ZIP prototype

```sh
# Explicitly select a folder containing ONLY supported Gomoku export files.
python3 Migration/package_user_data.py --create /path/to/selected/gomoku-data --archive /safe/output/gomoku-backup.zip
python3 Migration/package_user_data.py --verify --archive /safe/output/gomoku-backup.zip
python3 Migration/package_user_data.py --extract /path/to/new/empty/restore-folder --archive /safe/output/gomoku-backup.zip
```

This is an offline desktop verification helper, not an implementation of iOS cross-sandbox data access.

## Verification status

See [`VERIFICATION_STATUS.md`](VERIFICATION_STATUS.md). The package's portable C++/Python tests pass. The **current exact upstream Swift modules, complete iOS design parity, BLE and signed IPA remain Work deliverables**, not achievements of the bootstrap bundle.
