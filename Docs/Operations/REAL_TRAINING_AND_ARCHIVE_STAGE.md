# Native self-play and match archive candidate

- Source: real NativeGomokuSelfPlay with original GomokuBot. Only legal completed games with fully verified move history are committed atomically to standalone app Application Support/Gomoku/NativeSelfPlayV1/<UUID>.json. No arbitrary file count cap.
- Original VeilGomokuMatchArchive persists actual human/AI matches per session under the new app sandbox; no cross-app direct access.
- Training UI button runs one authentic self-play game and shows only durably recorded count.
- IMPORTANT: stored training games do NOT yet feed back into the AI's learned ranking store, and no original user history has been imported. Release requires full learning feedback, validated export/import, XCTest, device checks, and security review.
