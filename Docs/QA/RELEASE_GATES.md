# Release acceptance checklist (evidence first)

Every item starts **NOT VERIFIED**. Never mark PASS without logs, test names and commit SHA. Never infer iOS success from Linux compilation.

## Provenance

- [ ] New `Righteous1776/Gomoku` repository exists and is under correct owner, PRIVATE initially.
- [ ] Pinned upstream commit checked out and immutable SHA256 audit passes for original modules.
- [ ] Source-to-adapted diff ledger completed; no unrelated service or hidden fork regressions.
- [ ] MIT license and nested licenses included; no private data, secrets, unrelated weights, unauthorized materials.

## Playable app and fidelity

- [ ] `Gomoku` standalone Bundle ID installs/starts without VeilLink.
- [ ] `instrumentAuto` original source visuals match in dark/light/system; only permitted theme.
- [ ] Original `GomokuBoardView`, settings, archives, search/compute instruments, self-play and teaching tools work.
- [ ] Original Swift ECLIPSE selected by default until valid C++ promotion.
- [ ] Seven tiers, 2×/4×/6× search budget, black/white selection, resume, forced win/block, 15x15 win/draw pass.
- [ ] No scroll gesture hijacking or UI blocking while AI thinks; measure response and frame pacing.

## Storage and network

- [ ] Gomoku data separate from Xiangqi and the source app sandbox.
- [ ] Import old exported learning data; duplicate/invalid/rollback handling and 100% source record audit.
- [ ] No hard arbitrary game-count or 512KB archive limits; large incremental tests pass.
- [ ] Standalone two-device BLE/E2EE invite, move, reconnect, clock-offset ordering pass on real hardware.

## Engine/training/CI

- [ ] CMake C++20 build + CTest pass on Linux/macOS.
- [ ] Training JSONL self-play validates all legal moves, final status and provenance.
- [ ] Optional PyTorch pipeline runs only with allowed verified research dataset.
- [ ] Model score comparisons done against original under equal hardware/time, both colors, multiple openings. Report confidence and no unsupported Elo claims.
- [ ] iOS `xcodebuild` simulator Debug/Release and XCTest pass. Physical device tests recorded.

## Distribution

- [ ] Distinguish unsigned artifact from signed, installable IPA.
- [ ] Only securely provided signing cert/profiles and matching Bundle ID, no credentials in Git.
- [ ] Owner approved release version/tag, generated changelog, SHA256 and install verification.

**Release must be blocked if any mandatory artifact/provenance/parity/functional/security criterion is missing or failed.** Partial engineering completion may be committed, but may not be marketed as finished Gomoku app.
