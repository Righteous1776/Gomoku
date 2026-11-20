# Single-execution integration workstreams

| Gate | Code and deliverables | Must produce |
|---|---|---|
| P0 baseline | Pin upstream SHA, inspect live source, verify licensing, snapshot features | Pin + manifest + verification log |
| P1 repository | Private `Righteous1776/Gomoku`, initialize new code, independent version and CI | URL + repo initial commit |
| P2 source stage | Run exact copy and SHA audit from pinned VeilLink, enumerate transitive deps | `Provenance/migrated_sources.sha256.json` |
| P3 app parity | Replace provisional shell with full upstream Swift ECLIPSE app/game views, fixed `instrumentAuto` theme | iOS simulator build + screenshots + XCTest |
| P4 portable engine | C++20 core and C ABI parity research, 7 tiers and tactical invariants | CTest, paired-match evidence; original Swift remains fallback |
| P5 training | Python validated selfplay, experiment policy, data provenance, benchmarks | Dataset checksums, model manifests, reproduce commands |
| P6 data | Independent namespace and explicit import/export of Gomoku formats | Synthetic fixture migration and rollback test |
| P7 multiplayer | Purpose-scoped standalone BLE/E2EE, ordered turn/session protocol | Protocol tests + two-device verification if hardware |
| P8 packaging | iOS Debug/Release builds, signing validation and manual distribution | SHA256 verified IPA if credentials available |
| P9 maintenance | README user guide, Architecture ADRs, changelog, license/source-diff logs | Release evidence + owner sign-off |

## All in one Work assignment, not one uncontrolled merge

Work should execute workstreams in sequence using PRs and integration gates, without requiring user to manually restate every phase. However no phase is allowed to be labeled complete before its objective tests run. If macOS, GitHub permissions, physical iOS devices or signing are unavailable, complete all platform-independent work and mark blocked gates explicitly, with reproducible commands rather than imaginary success claims.

## Intended future after first verified release

1. Promote **measured** C++ parity behind separate engine version; add cancellation/deadline API and transposition table.
2. Expand automatic tournament and learning evaluation with paired openings/seed variation/hardware-matched time.
3. Isolate native neural inference from trained artifacts; compare NNUE-like and Policy/Value approaches before shipping.
4. Add structured game-engine plug-ins for Xiangqi/chess only after Gomoku engine API and data contracts stabilize.
5. Optionally split reusable `ECLIPSE-Core` out of mono-repo once genuine external consumers exist.
