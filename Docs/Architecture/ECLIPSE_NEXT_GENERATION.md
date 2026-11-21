# ECLIPSE Next Generation · phased language migration

**Implementation status:** P1 ABI/rules/CI source staged on Draft PR #13.
Swift ECLIPSE remains the only production opponent. C++20 search is a
prototype, **not** a stronger or behavior-equivalent replacement.

## Architecture

1. **C++20 runtime** (\`Engine/\`): shared board rules, the future optimized
   tree search and threat safety checks. Current prototype search is isolated.
   C API \`eg_rules_abi_version() == 1\` and \`eg_rules_replay_v1(...)\` provide
   a stable read-only board-state contract; no Swift objects or ownership cross
   the boundary. No private training data is needed.
2. **Python training/research** (\`Training/\`, \`Arena/\`): offline self-play,
   strict legality verification, dataset provenance and opening-balanced
   research comparisons. Python and PyTorch **never run in the shipped iOS app**.
   Produced checkpoints are research-only until deterministic export,
   provenance, legality and strength gates pass. Existing original owner
   history remains outside public IPA and C++ prototype training.
3. **SwiftUI/iOS app** (\`Apps/iOS/Gomoku/\`): navigation, accessibility,
   private import, journal, ECLIPSE telemetry, original seven difficulty
   tiers and search. \`NativeGomokuAppController\` must keep using the original
   Swift \`GomokuBot\` until a measured owner-approved feature gate succeeds.

## P1 acceptance contract, without replacing the live engine

- 15x15 freestyle, Black first, one stone/ply, exactly 225 intersections.
- Five or more connected stones terminate immediately; moves after a terminal
  state, duplicates, out-of-board indices and null pointer misuse are rejected.
- Winner is 1 for Black, 2 for White; 3 means a full-board draw.
- Swift \`GomokuState\` intentionally **does not advance currentPlayer on the
  final move**. The original C++ search prototype does. The versioned
  read-only ABI normalizes this distinction without changing search scoring.
- \`eg_rules_replay_v1\` validates a whole move sequence before writing any
  output. Invalid histories **must not** partially corrupt app state.
- C++ CTest validates the ABI, Python runs independent edge/terminal/random
  replay against CLI \`--state\`, iOS XCTest compares ABI snapshots against
  the authoritative Swift \`GomokuState\`. These are three independent
  implementations/checks, not a proof of full search equivalence.

## Next gates (not accepted yet)

- **P2 tactical parity:** urgent win, forced block, open/closed 3-4 threats,
  counterfork R4, R12 horizon quiescence, R13 incremental threat index,
  unrestricted root safety, all seven tiers and 6x policy in C++20. No
  partial port may bypass the original mandatory defense gate.
- **P3 repeatable strength:** fixed seed and budgets, symmetric color-swapped
  paired matches vs Swift, Elo uncertainty, move legality and latency
  distributions (P50/P95/P99), zero tactical regressions under forced fixtures.
- **P4 shared weight checkpoint:** schema-versioned, hashed, signed or
  integrity-checked immutable policy files exported by Python, loaded by C++
  with rollback, while keeping private games scoped correctly.
- **P5 gated app runtime:** explicit feature flag default false, staged
  canary rollout and auto-fallback on invalid move, crash, timeout or mismatch;
  rollback without loss of training/journal history. iPhone thermal and memory
  profiling plus actual device owner acceptance are required.

**Do not claim complete language migration, 100% parity, trained strength
upgrade, signed IPA or public release from P1 source code.**
