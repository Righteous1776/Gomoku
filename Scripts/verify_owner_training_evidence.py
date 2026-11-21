#!/usr/bin/env python3
"""Verify exact archived owner training evidence; never substitute simulation data."""
from __future__ import annotations
import base64
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
    if actions[0][:1] not in ("a", "h"):
        raise ValueError("Unknown first player in actual match")
    black_tag = actions[0][:1]
    other_tag = "h" if black_tag == "a" else "a"
    for ply in actions:
        if not isinstance(ply, str) or len(ply) < 2:
            raise ValueError("Malformed action")
        actor = {black_tag: 1, other_tag: 2}.get(ply[:1])
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
    if not winner:
        return "draw" if len(actions) == 225 else "unfinished"
    winner_tag = black_tag if winner == 1 else other_tag
    return "humanWon" if winner_tag == "h" else "aiWon"


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


# Exact original 2026-11-13 exports, verified independently from the Library
# by a complete SHA-256 on raw bytes BEFORE GitHub ingestion. The labels of five
# partial restore fragments are not trustworthy even though the envelope is.
NOVEMBER_EXPORTS = (
    {
        "name": "VeilLink-GomokuLearning-20261113-172016-404-27774F62.vltrain.json",
        "sha256": "d5cf13940bbb84dc937783700aa129303c4ec1d54a781992099675c3e6325d8b",
        "fnv": "93dcccb56c4ec952",
        "recent": 107, "positions": 1611, "valid": 48, "unique": 44,
        "unfinished": 56, "quarantined_ordinals": (11, 17, 64),
    },
    {
        "name": "VeilLink-GomokuLearning-20261113-181938-942-EB7990D0.vltrain.json",
        "sha256": "050f5abbac2c3f7991db5dbcad4b4d1bd33f49eb1aeeacb5025b17d0696ce325",
        "fnv": "a9737700c7cd421f",
        "recent": 78, "positions": 1140, "valid": 57, "unique": 48,
        "unfinished": 19, "quarantined_ordinals": (28, 32),
    },
)


def november_path(entry: dict) -> Path:
    return ROOT / "Migration/OwnerEvidence/20261113" / entry["name"]


def audit_november_export(data: bytes, entry: dict) -> dict:
    if hashlib.sha256(data).hexdigest() != entry["sha256"]:
        raise ValueError("Original November owner training SHA256 mismatch")
    source = json.loads(data)
    if (source.get("format") != "veillink.board-learning.export.v1" or
            source.get("checksumAlgorithm") != "fnv1a64-canonical-json"):
        raise ValueError("Unexpected November training format")
    payload = source["payload"]
    # The source SHA256 has already verified the *entire* original file.
    # Apple's v29 JSONEncoder encoded Date doubles at a different precision;
    # reserializing with Python/other Foundation versions changes the FNV.
    # Record and verify the original claimed FNV without inventing parity.
    if (source["payloadChecksum"] != entry["fnv"] or payload["schema"] != 1):
        raise ValueError("Original November checksum claim or schema changed")
    games = payload["recentGames"]
    if len(games) != entry["recent"] or len(payload["positions"]) != entry["positions"]:
        raise ValueError("Original November game or aggregate count changed")
    complete = incomplete = 0
    unique = set()
    quarantine = []
    for ordinal, match in enumerate(games):
        if match.get("game") != "gomoku":
            raise ValueError("Unexpected non-Gomoku November record")
        actual = replay(match["actions"])
        claimed = match["result"]
        if actual != claimed:
            if (actual == "unfinished" and claimed != "unfinished" and
                    ordinal in entry["quarantined_ordinals"]):
                quarantine.append(ordinal)
                continue
            raise ValueError("Unexpected historical owner training result mismatch")
        if actual == "unfinished":
            incomplete += 1
            continue
        complete += 1
        unique.add(tuple(int(m[1:]) for m in match["actions"]))
    if (complete != entry["valid"] or
            len(unique) != entry["unique"] or
            incomplete != entry["unfinished"] or
            tuple(quarantine) != entry["quarantined_ordinals"]):
        raise ValueError("Original November matches altered or incorrectly classified")
    return {
        "sha256": entry["sha256"],
        "validTerminal": complete,
        "independentGames": len(unique),
        "legalIncomplete": incomplete,
        "quarantinedOrdinals": quarantine,
        "hashOnlyPositions": len(payload["positions"]),
    }



def audit_native_seed(data: bytes) -> dict:
    if blob_sha1(data) != NATIVE_SEED_BLOB:
        raise ValueError("Original native game seed bytes changed")
    original = json.loads(data)
    records = original["records"]
    if (original.get("format") != "veillink.native-gomoku-real-selfplay.v1" or
            original.get("engineRevision") !=
            "bc919b454379841180fb8698a9e0addec87e7af0" or
            original.get("count") != 2000 or len(records) != 2000):
        raise ValueError("Native game seed format or count changed")
    digest = bytearray()
    unique = set()
    outcomes = {"a": 0, "h": 0, "d": 0}
    for record in records:
        if not isinstance(record["s"], int) or record["s"] < 0:
            raise ValueError("Invalid native seed value")
        digest.extend(f'{record["s"]}|{record["r"]}|{record["m"]}\n'.encode())
        raw_moves = base64.b64decode(record["m"], validate=True)
        if not (5 <= len(raw_moves) <= 225):
            raise ValueError("Invalid native compressed move count")
        legal_result = replay(
            [("h" if ply % 2 == 0 else "a") + str(point)
             for ply, point in enumerate(raw_moves)]
        )
        mapped = {"a": "aiWon", "h": "humanWon", "d": "draw"}
        if record["r"] not in mapped or legal_result != mapped[record["r"]]:
            raise ValueError("Invalid native terminal claim")
        outcomes[record["r"]] += 1
        unique.add(bytes(raw_moves))
    if fnv1a64(digest) != original["fnv1a64"]:
        raise ValueError("Native seed FNV mismatch")
    if len(unique) != 236 or outcomes != {"a": 860, "h": 1102, "d": 38}:
        raise ValueError("Native unique evidence count or outcomes changed")
    return {
        "originalRecords": len(records),
        "legalTerminalRecords": len(records),
        "distinctCompletedGames": len(unique),
        "duplicateGames": len(records) - len(unique),
        "outcomes": outcomes,
        "fnv1a64": original["fnv1a64"],
    }


def main() -> None:
    report = audit_bytes(ARCHIVE.read_bytes())
    for entry in NOVEMBER_EXPORTS:
        real = audit_november_export(november_path(entry).read_bytes(), entry)
        print("Verified original November owner training:", json.dumps(real, sort_keys=True))
    native_path = ROOT / "Apps/iOS/Gomoku/Resources/GomokuNativeTrainingSeed.json"
    seed = audit_native_seed(native_path.read_bytes())
    print("Native self-play deduplicated:", json.dumps(seed, sort_keys=True))


if __name__ == "__main__":
    main()
