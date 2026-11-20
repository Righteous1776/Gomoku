#!/usr/bin/env python3
"""Verify exact archived owner training evidence; never substitute simulation data."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "Migration/OwnerEvidence/VeilLink-Gomoku-OwnerTraining-20261031.vltrain.json"
SOURCE_BLOB = "811255cc73f3d79ef2aa4c768a2b5ed1679ba8a4"
SOURCE_FNV = "c52154f68a0cb20c"
NATIVE_SEED_BLOB = "b9f017ee9b40c877c3f6124a6911eef15a8cd19c"


def blob_sha1(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()


def canonical_bytes(obj: dict) -> bytes:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def fnv1a64(data: bytes) -> str:
    value = 14695981039346656037
    for byte in data:
        value = ((value ^ byte) * 1099511628211) & 0xffffffffffffffff
    return format(value, "x")


def replay(actions: list[str]) -> str:
    board = [0] * 225
    winner, turn = 0, 1
    if not isinstance(actions, list) or not (1 <= len(actions) <= 225):
        raise ValueError("Invalid action count")
    for ply in actions:
        if not isinstance(ply, str) or len(ply) < 2:
            raise ValueError("Malformed action")
        actor = {"h": 1, "a": 2}.get(ply[:1])
        try:
            point = int(ply[1:])
        except ValueError as exc:
            raise ValueError("Invalid action square") from exc
        if actor != turn or point not in range(225) or board[point] or winner:
            raise ValueError("Illegal move sequence")
        board[point] = actor
        row, col = divmod(point, 15)
        for dr, dc in ((1, 0), (0, 1), (1, 1), (1, -1)):
            line = 1
            for sign in (-1, 1):
                r, c = row + dr * sign, col + dc * sign
                while 0 <= r < 15 and 0 <= c < 15 and board[r * 15 + c] == actor:
                    line += 1
                    r += dr * sign
                    c += dc * sign
            if line >= 5:
                winner = actor
                break
        turn = 3 - actor
    return ("humanWon" if winner == 1 else
            "aiWon" if winner == 2 else
            "draw" if len(actions) == 225 else "unfinished")


def audit_bytes(data: bytes, *, enforce_blob: bool = True) -> dict:
    sha = blob_sha1(data)
    if enforce_blob and sha != SOURCE_BLOB:
        raise ValueError("Original private training blob changed")
    source = json.loads(data)
    if (source.get("format") != "veillink.board-learning.export.v1" or
            source.get("checksumAlgorithm") != "fnv1a64-canonical-json"):
        raise ValueError("Unexpected VeilLink training format")
    payload = source["payload"]
    canonical_fingerprint = fnv1a64(canonical_bytes(payload))
    if (canonical_fingerprint != source.get("payloadChecksum") or
            canonical_fingerprint != SOURCE_FNV or payload.get("schema") != 1):
        raise ValueError("Training checksum mismatch")
    recent = payload["recentGames"]
    positions = payload["positions"]
    if not isinstance(recent, list) or not isinstance(positions, dict):
        raise ValueError("Malformed training database")
    complete, partial = 0, 0
    seen = set()
    outcomes = {"humanWon": 0, "aiWon": 0, "draw": 0, "unfinished": 0}
    for game in recent:
        if game.get("game") != "gomoku":
            raise ValueError("Non-Gomoku data is prohibited")
        result = replay(game["actions"])
        if result != game["result"]:
            raise ValueError("Original terminal label disagrees with replay")
        outcomes[result] += 1
        if result == "unfinished":
            partial += 1
        else:
            complete += 1
            sequence = tuple(game["actions"])
            if sequence in seen:
                raise ValueError("Duplicate completed game")
            seen.add(sequence)
    if (len(recent) != 28 or complete != 10 or partial != 18 or
            len(positions) != 1205 or payload.get("completedGames") != 10):
        raise ValueError("Owner training history truncated or reclassified")
    return {"source_git_blob": sha, "recentGames": len(recent),
            "legitimateComplete": complete, "legalIncomplete": partial,
            "hashedPositionAggregates": len(positions),
            "uniqueComplete": len(seen), "outcomes": outcomes,
            "fnv1a64": canonical_fingerprint}


def main() -> None:
    report = audit_bytes(ARCHIVE.read_bytes())
    native_path = ROOT / "Apps/iOS/Gomoku/Resources/GomokuNativeTrainingSeed.json"
    native_bytes = native_path.read_bytes()
    if blob_sha1(native_bytes) != NATIVE_SEED_BLOB:
        raise ValueError("Original 2000-record native seed differs from VeilLink")
    native = json.loads(native_bytes)
    if native.get("count") != 2000 or len(native["records"]) != 2000:
        raise ValueError("Native seed record count altered")
    print("Authentic owner archive and native self-play seed PASS:")
    print(json.dumps(report, sort_keys=True))
    print("Native seed: 2000 original records (unique count not asserted)")


if __name__ == "__main__":
    main()
