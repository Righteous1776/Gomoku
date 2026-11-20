#!/usr/bin/env bash
# Reproduce the repository's CI work before pushing, without bypassing failures.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
MODE="${1:-help}"
core() (
  command -v cmake >/dev/null || { echo 'cmake missing' >&2; exit 2; }
  command -v python3 >/dev/null || { echo 'python3 missing' >&2; exit 2; }
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
  cmake --build build --parallel 2
  ctest --test-dir build --output-on-failure
  python3 -m unittest discover -s Training/tests -v
  mkdir -p Training/outputs
  local file="Training/outputs/preflight-smoke-${BASHPID}.jsonl"
  trap 'rm -f "$file" "$file.manifest.json"' EXIT
  python3 Training/selfplay.py --engine build/Engine/gomoku_cli --games 1 --ms 2 --out "$file"
  python3 Training/validate_dataset.py --path "$file"
)
inbox() {
  python3 Scripts/inbox.py check-board
  python3 -m unittest discover -s Scripts/tests -v
}
provenance() {
  python3 Scripts/check_private_bundle.py
  python3 Scripts/verify_package.py
  python3 Scripts/audit_git_blobs.py
  python3 Scripts/audit_migration.py
  python3 Scripts/verify_owner_training_evidence.py
  python3 Scripts/verify_gomoku_ui_contract.py
}
ios() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo 'BLOCKED: iOS build requires macOS + Xcode, not available here.' >&2
    exit 3
  fi
  command -v xcodebuild >/dev/null || { echo 'BLOCKED: Xcode missing' >&2; exit 3; }
  command -v xcodegen >/dev/null || { echo 'BLOCKED: XcodeGen missing' >&2; exit 3; }
  xcodebuild -version
  xcrun --sdk iphonesimulator --show-sdk-version
  python3 Scripts/check_private_bundle.py
  xcodegen generate --spec project.yml
  xcodebuild -project Gomoku.xcodeproj -scheme Gomoku -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
  local phone_id
  phone_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin)["devices"]; print(next(x["udid"] for runtime in reversed(sorted(d)) if ".iOS-" in runtime for x in d[runtime] if x["name"].startswith("iPhone")))')"
  xcodebuild -project Gomoku.xcodeproj -scheme Gomoku -configuration Debug -destination "platform=iOS Simulator,id=$phone_id" -derivedDataPath DerivedData -parallel-testing-enabled NO -resultBundlePath GomokuTests.xcresult CODE_SIGNING_ALLOWED=NO test
  xcodebuild -project Gomoku.xcodeproj -scheme Gomoku -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
  python3 Scripts/check_private_bundle.py --app DerivedData/Build/Products/Debug-iphonesimulator/Gomoku.app --app DerivedData/Build/Products/Release-iphonesimulator/Gomoku.app --manifest DerivedData/Privacy/public-build.json
}
case "$MODE" in
  core) core ;;
  inbox) inbox ;;
  provenance) provenance ;;
  ios) ios ;;
  full) core; inbox; provenance; ios ;;
  help|-h|--help) echo 'Usage: bash Scripts/local_ci_preflight.sh {core|inbox|provenance|ios|full}' ;;
  *) echo "Unknown mode: $MODE" >&2; exit 2 ;;
esac
