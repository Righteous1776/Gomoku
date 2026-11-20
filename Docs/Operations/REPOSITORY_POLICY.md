# Repository governance and privacy

## Split scope

New repo `Righteous1776/Gomoku` is independent from `Righteous1776/VeilLink`; upstream read-only under existing INBOX_ONLY governance. New repo default visibility PRIVATE until source/weight/license/privacy audit. Do not add unrestricted GitHub Actions secrets; keep signing secrets in protected environments with approvals.

## Branch model

`main` integrated only by authorized governor; `feature/source-extraction`, `feature/ios-original-parity`, `feature/cpp-engine`, `feature/training`, `feature/local-migration`, `feature/ble-game-link`; PR-based review with test evidence and source diffs. Each cross-module change has clear owner and non-overlapping file list.

## New repo assets

All original source files staged under `Legacy/Original` and metadata in `Provenance/`. No IPAs or `DerivedData/` in Git. Binary weights in a model registry or release asset with hash, provenance and license; Git LFS only if correctly configured and size/license constraints permit. User-owned game records are never committed.

## Version strategy

Independent `1.0.0` from product side; do not import VeilLink's marketing build number. ECLIPSE engine and model revisions have separate identifiers, e.g. `swift-upstream-<sha>` and `cpp-prototype-v0.1`. A changed engine search policy does not automatically imply a new App marketing version. Keep source attribution.
