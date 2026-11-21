# Gomoku local CI reproduction · 2026-11-21

**Do not mark repository Actions green based on these local results.** This is an independently tested, partial checkout of the critical C++/Python sources retrieved from PR #13. The execution environment is Linux (Debian, GCC 14.2, CMake, Python 3), NOT macOS/Xcode. The container cannot clone the private repository directly because network/DNS access is unavailable, so source subsets were reconstructed from exact repository file contents for C++/Python testing; this is not a byte-for-byte whole checkout.

## Executed successfully before submitting this change

- `cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug` and `cmake --build build --parallel 2`: C++ experimental ECLIPSE library, CLI and C++ test executable built locally.
- `ctest --test-dir build --output-on-failure`: **1/1 PASS** (`eclipse_rules`).
- `python3 -m unittest discover -s Training/tests -v`: **7/7 PASS** (dataset replay and ZIP migration).
- `python3 Training/selfplay.py --engine build/Engine/gomoku_cli --games 1 --ms 2 --out Training/outputs/smoke.jsonl`: **PASS**, generated one legal `cpp-prototype` game. `validate_dataset.py` validated **1 completed game**.
- `python3 Scripts/inbox.py check-board`: **BOARD_VALID**.
- `python3 -m unittest discover -s Scripts/tests -p test_inbox.py -v`: **16/16 PASS**. The full `Scripts/tests` directory includes additional provenance/UI tests not copied into this partial reconstruction, so do not claim the entire GitHub job passed.
- `bash -n Scripts/local_ci_preflight.sh`, followed by both `core` and `inbox` on the corresponding reconstructed source subsets: **PASS**.

## Reproduce on a *complete* checkout

Use `bash Scripts/local_ci_preflight.sh core`, `bash Scripts/local_ci_preflight.sh inbox`, `bash Scripts/local_ci_preflight.sh provenance` and (on macOS with Xcode + XcodeGen + an available iPhone simulator) `bash Scripts/local_ci_preflight.sh ios`. `full` runs all four and requires macOS. The script performs actual commands; it never skips failed unit tests or masks missing tools. Experimental C++ is not a replacement for original native Swift ECLIPSE.

## Actual GitHub Actions blocker

As of earlier PR commits through `f09c4d1`, all three hosted workflows failed **before checkout**, on both `macos-15` and `ubuntu-24.04`: task steps empty, runner_name empty, log blobs unavailable; direct retry reproduced this. Therefore no repository-wide green check, no successful Swift Xcode/Debug/Release/XCTest result and no native iOS screenshot evidence. The repository owner's private Actions account budget, billing state, or hosted-runner service restriction requires inspection on GitHub; no root cause asserted without the GitHub UI annotation. Re-running the jobs cannot overcome a scheduler/account rejection without resolving it.

**Policy:** PR #13 remains Draft; do not merge/release because this local result is partial and the production native Swift app remains unbuilt in a macOS environment.
