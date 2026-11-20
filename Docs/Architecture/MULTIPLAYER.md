# Independent BLE + E2EE Gomoku session boundary

## Problem

Existing VeilLink game sessions run inside messenger conversations. `MiniGameHubView` and `MiniGameSessionView` assume `AppModel`, `ConversationSummary`, `ChatMessage` and existing BLE/E2EE message infrastructure. Copying `MiniGameViews.swift` into new app as-is will not compile and is a dependency/privacy liability.

## Intended new boundary

- `GameTransport`: discovery, connection, encrypted envelope exchange, disconnect/reconnect signal.
- `GameSessionProtocol`: schema version, invite/accept/cancel, select color, rules negotiation, start handshake, move, resign, request snapshot, snapshot, finish.
- `GameReducer`: deterministic board transitions from verified `sessionId` + ordered `ply` + actor + previous board hash.
- `GameUI`: independent invitation and board scene with no `AppModel`/chat relation.

All state transitions must be independent of the other device's wall clock. Duplicate message `(session_id, sequence)` idempotently ignored. Out-of-order must be buffered only within safety limits and then trigger resynchronization. Encrypted handshake must bind a session and replay window; never assume BLE transport alone authenticates sender. Support session teardown; no chat logs in any exported game archive.

## Device tests

Two real phones are required to claim end-to-end success: local discovery, simultaneous invites, color disagreement, alternating turns, one phone clock offset by 2 minutes, disconnect mid-turn, resync, app foreground/background interruption, resignation, replay and duplicate messages. Note actual iOS background BLE restrictions; do not promise indefinite background streaming.
