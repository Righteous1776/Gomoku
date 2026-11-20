# Original VeilLink personal Gomoku training evidence — migration

Source: Righteous1776/VeilLink at 0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32; AGENT_INBOX/submissions/board-training-agent/20261031-owner-gomoku-xiangqi-bagua-r1/FILES/VeilLink/Resources/VeilLink-Gomoku-OwnerTraining-20261031.json.

The original 285074 bytes are preserved in this private repo under Migration/OwnerEvidence/VeilLink-Gomoku-OwnerTraining-20261031.vltrain.json. Git blob SHA-1: 811255cc73f3d79ef2aa4c768a2b5ed1679ba8a4. Source canonical FNV1a64 checksum: c52154f68a0cb20c. Filename extension changed; bytes did not.

Independent original game replay: 28 records, 10 valid unique terminal games (4 humanWon, 3 aiWon, 3 draw), 18 legally unfinished games, 1205 retained hash-only aggregate positions. Ten terminal histories may inform the native search ONLY after authorised import. Eighteen interrupted games and hashed-only aggregates are not terminal learning evidence. The raw source remains untouched in VeilLink.

Normal Gomoku bundles do NOT contain this private resource. The original native Gomoku self-play seed is already byte-identical: 2000 source records, Git blob b9f017ee9b40c877c3f6124a6911eef15a8cd19c, in Apps/iOS/Gomoku/Resources/GomokuNativeTrainingSeed.json. An independent decoder/replayer verified all 2000 original legal terminal games and recomputed FNV 29e9808a4a69618b. They contain exactly **236 distinct complete move sequences** and **1764 duplicates** (860 AI wins, 1102 human wins, 38 draws as recorded labels). New Python and XCTest checks guard the 236/1764 unique result. This is not equivalent to 2000 independent training games.

Use the existing developer-only device-owner authorised import: save the private evidence JSON to iOS Files, open 开发训练室, verify device holder, select VeilLink .vltrain.json. The existing importer validates checksum and moves; it is wired to ImportedLegacyLearningV1 and GomokuLearningRepertoire. No device test has run yet.

For optional **owner-only private builds**, explicitly run:
    python3 Scripts/stage_owner_training.py --owner-build --acknowledge-private-bundle
The developer lab will offer importing the packaged personal evidence. The generated resource path is ignored by Git. After owner-only testing, remove via:
    python3 Scripts/stage_owner_training.py --unstage
Bundling means the personal record is readable inside the IPA; never publish this build without consent.

Audit via python3 Scripts/verify_owner_training_evidence.py and Scripts/tests/test_owner_training_evidence.py. GitHub Actions hosted runners remain unavailable, so this is staged and independently audited, not an iOS TESTED/ACCEPTED state.

Outstanding raw data gaps: upstream R6/R8 reports describe 5141 historical completed native games with only 276 unique full sequences, but no full raw downloadable archive is tracked in upstream GitHub; 62500 is a Numba-surrogate experiment summary, not native Swift games. An agent policy ranker VLPOL1 shares Gomoku/Xiangqi/Ludo weights and is not an Eclipse-native model. The 224848275-byte three-game dataset is documented by a manifest only, not available as raw data. None of these counts can legitimately be added to the imported 10 games or to the native seed.

On-device import retention (subsequent integration): ImportedLegacyLearningV1/RawSources keeps the complete original validated envelope under a SHA-256 filename, with protected atomic writes and directory backup/rollback. Repeat import deduplicates complete games, retains all earlier raw sources, and verifies unfinished game legality before committing. Raw hash-only positions and unfinished matches are preserved as evidence but never promoted into bot training. The importer reports counts after commit; an accepted new complete history refreshes the coach. The corresponding XCTest fixture also checks repeat import, byte-preserving retention, and refusal of a later corrupt package. CI and physical device execution still pending.

Archive-only import rule: a fully checksum-verified source containing exclusively legal unfinished games or hash-only position statistics is allowed to persist its intact envelope and returns 0 learning games; no synthetic terminal record is created. Empty/corrupt input is still rejected. An XCTest fixture covers this no-inflation path; iOS runner evidence remains pending.
