#!/usr/bin/env python3
"""LOCAL-ONLY ECLIPSE Swift/C++ tactical regression from private evidence SQLite.

Never commit a real database or full match history. Reads database read-only.
Only emits aggregate counts. By default DOES NOT execute engines.
"""
from __future__ import annotations
import argparse
import collections
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess

TRUSTED = frozenset({"canonical_match", "historical_sha_pinned"})
AXES = ((1, 0), (0, 1), (1, 1), (1, -1))


def five_at(board, index, side):
    row, col = divmod(index, 15)
    for dr, dc in AXES:
        run = 1
        for sign in (-1, 1):
            r, c = row + sign * dr, col + sign * dc
            while 0 <= r < 15 and 0 <= c < 15 and board[r * 15 + c] == side:
                run += 1
                r += sign * dr
                c += sign * dc
        if run >= 5:
            return True
    return False


def immediate(board, side):
    return [i for i, v in enumerate(board) if not v and five_at(board, i, side)]


def extract(database):
    """Return private in-memory cases and public-safe aggregate diagnostics."""
    db = sqlite3.connect(f"file:{Path(database).resolve()}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    try:
        if db.execute("pragma integrity_check").fetchone()[0] != "ok":
            raise ValueError("SQLite integrity check failed")
        schema = {r[0] for r in db.execute(
            "select name from sqlite_master where type='table'")}
        if not {"metadata", "sources", "sequences", "game_observations"} <= schema:
            raise ValueError("unsupported private evidence schema")
        policy = db.execute(
            "select v from metadata where k='data_policy'").fetchone()
        if not policy or "LOCAL_ONLY" not in policy[0]:
            raise ValueError("missing local-only evidence boundary")
        rows = db.execute("""
            select s.id sequence_id, s.actions_json, g.diagnostic,
                   src.integrity, src.id source_id, count(*) repeats
              from sequences s
              join game_observations g on g.sequence_id=s.id
              join sources src on src.id=g.source_id
             group by s.id,src.id,g.result,g.diagnostic
             order by s.id,src.id""").fetchall()
        groups = collections.defaultdict(list)
        for row in rows:
            groups[row["sequence_id"]].append(row)
        found = {}
        stats = collections.Counter()
        for seq_id, observations in groups.items():
            trusted = [r for r in observations if r["integrity"] in TRUSTED]
            if not trusted:
                stats["quarantined_only_sequences"] += 1
                continue
            if any(r["diagnostic"] != "ok" for r in trusted):
                stats["rejected_trusted_diagnostics"] += 1
                continue
            acts = json.loads(observations[0]["actions_json"])
            if not isinstance(acts, list) or not all(isinstance(x,str) for x in acts):
                raise ValueError("bad action array in trusted source")
            if hashlib.sha256("\0".join(acts).encode()).hexdigest() != seq_id:
                raise ValueError("sequence digest mismatch")
            if not acts:
                continue
            stats["trusted_distinct_sequences"] += 1
            board = [0] * 225
            history = []
            prior_actor = None
            terminal = False
            for ply, token in enumerate(acts):
                if (len(token) < 2 or token[0] not in ("a", "h")
                        or not token[1:].isdigit()):
                    raise ValueError("invalid trusted action token")
                square = int(token[1:])
                side = 1 + ply % 2
                if (terminal or not 0 <= square < 225
                        or board[square] or token[0] == prior_actor):
                    raise ValueError("invalid trusted sequence replay")
                own = immediate(board, side)
                enemy = immediate(board, 3 - side)
                kind, allowed = ("immediate_win", own) if own else (
                    ("forced_single_block", enemy) if len(enemy) == 1 else (None, []))
                if kind:
                    key = (hashlib.sha256(bytes(board) + bytes([side])).hexdigest(),
                           kind, side)
                    rec = found.setdefault(key, {
                        "kind": kind, "side": side, "allowed": allowed,
                        "history": history.copy(), "witnesses": set(),
                        "source_ids": set(), "max_repeat": 0
                    })
                    if rec["allowed"] != allowed:
                        raise AssertionError("rule label conflict")
                    rec["witnesses"].add(seq_id)
                    rec["source_ids"].update(r["source_id"] for r in trusted)
                    # Maximum within ONE verified snapshot, not sum of snapshots.
                    rec["max_repeat"] = max(
                        rec["max_repeat"], max(r["repeats"] for r in trusted))
                board[square] = side
                history.append(square)
                prior_actor = token[0]
                terminal = five_at(board, square, side)
                if terminal and ply != len(acts)-1:
                    raise ValueError("moves after terminal in trusted data")
        cases = list(found.values())
        cases.sort(key=lambda rec: (
            -int(rec["max_repeat"] > 1), -rec["max_repeat"],
            -len(rec["witnesses"]), rec["kind"],
            hashlib.sha256(bytes(rec["history"])).hexdigest()))
        stats.update({
            "unique_tactical_positions": len(cases),
            "repeated_tactical_positions": sum(c["max_repeat"] > 1 for c in cases),
            "unique_immediate_win": sum(c["kind"] == "immediate_win" for c in cases),
            "unique_forced_single_block": sum(
                c["kind"] == "forced_single_block" for c in cases),
            "observed_witness_links": sum(len(c["witnesses"]) for c in cases)
        })
        return cases, dict(stats)
    finally:
        db.close()


def sample(cases, maximum):
    if maximum == 0:
        return cases
    # Balanced between wins and blocks; prioritize repeated tactical sequences.
    buckets = {kind: [c for c in cases if c["kind"] == kind]
               for kind in ("immediate_win", "forced_single_block")}
    chosen = []
    while len(chosen) < maximum and any(buckets.values()):
        for kind in ("immediate_win", "forced_single_block"):
            if buckets[kind]:
                chosen.append(buckets[kind].pop(0))
                if len(chosen) >= maximum:
                    break
    return chosen


def engine_move(executable, moves, milliseconds):
    cmd = [str(Path(executable).resolve()), "--best",
           ",".join(map(str, moves)), "--ms", str(milliseconds)]
    try:
        proc = subprocess.run(cmd, capture_output=True, check=True,
                              text=True, timeout=80)
        move = json.loads(proc.stdout)["move"]
    except (OSError, subprocess.SubprocessError, ValueError, KeyError):
        raise RuntimeError("private engine case failed (history redacted)") from None
    if type(move) is not int or not 0 <= move < 225 or move in moves:
        raise RuntimeError("private engine illegal move (history redacted)")
    return move


def compare(cases, swift, cpp, ms):
    stats = collections.Counter()
    for case in cases:
        s = engine_move(swift, case["history"], ms)
        c = engine_move(cpp, case["history"], ms)
        stats["tested"] += 1
        stats["swift_correct"] += int(s in case["allowed"])
        stats["cpp_correct"] += int(c in case["allowed"])
        stats["exact_agreement"] += int(s == c)
        kind = case["kind"]
        stats[kind + "_tested"] += 1
        stats[kind + "_cpp_regressions"] += int(c not in case["allowed"])
        if case["max_repeat"] > 1:
            stats["repeated_tested"] += 1
            stats["repeated_cpp_correct"] += int(c in case["allowed"])
    return dict(stats)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path)
    parser.add_argument("--swift", type=Path)
    parser.add_argument("--cpp", type=Path)
    parser.add_argument("--ms", type=int, default=75)
    parser.add_argument("--limit", type=int, default=48,
                        help="0 runs all; dry audit always scans all")
    parser.add_argument("--out", type=Path,
                        help="LOCAL aggregate report; never contains moves")
    args = parser.parse_args()
    if (args.swift is None) != (args.cpp is None):
        parser.error("provide both --swift and --cpp")
    if args.ms < 1 or args.ms > 20000 or args.limit < 0:
        parser.error("invalid budget or limit")
    cases, audit = extract(args.db)
    chosen = sample(cases, args.limit)
    report = {
        "schema": "eclipse.private-tactical-regression.v1",
        "privacy": "LOCAL_ONLY; aggregate-only; zero histories logged",
        "reference_data_trust": "canonical checksum or historical SHA pinned",
        "audit": audit,
        "sampled_cases": len(chosen),
        "tested_with_actual_engines": bool(args.swift),
        "strength_noninferiority_verified": False
    }
    if args.swift and args.cpp:
        report["engine_comparison"] = compare(chosen, args.swift, args.cpp,
                                               args.ms)
        report["per_move_budget_ms"] = args.ms
    output = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        args.out.write_text(output, encoding="utf8")
    print(output, end="")


if __name__ == "__main__":
    main()
