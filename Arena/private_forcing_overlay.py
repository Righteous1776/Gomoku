#!/usr/bin/env python3
"""LOCAL-ONLY rule-proved ECLIPSE tactical opening cache, not model weights.

Keep this output off public GitHub. All listed roots are re-certified before
writing and again at query. No guessed Elo, no automatic Swift replacement.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import sqlite3
from private_forcing_forks import double_win_targets, completed_five


def board_at(history):
    board = [0] * 225
    for ply, move in enumerate(history):
        if type(move) is not int or not 0 <= move < 225 or board[move]:
            raise ValueError("invalid private move history")
        side = 1 + ply % 2
        board[move] = side
        if completed_five(board, move, side) and ply != len(history)-1:
            raise ValueError("moves after terminal")
    return board


def board_key(board, side):
    return hashlib.sha256(bytes(board) + bytes([side])).hexdigest()


def build_overlay(private_suite, output_database):
    raw = Path(private_suite).read_bytes()
    dataset = json.loads(raw)
    if dataset.get("report", {}).get("schema") not in (
        "eclipse.private-forcing-forks.v1",
        "eclipse.private-r12.forcing-discovery.v1"
    ):
        raise ValueError("not an audited private forcing suite")
    target = Path(output_database)
    if target.exists():
        raise ValueError("will not overwrite existing private research database")
    db = sqlite3.connect(target)
    try:
        db.executescript("""
          create table metadata(key text primary key, value text not null);
          create table positions(
              board_key text primary key, side integer not null,
              max_trusted_repeats integer not null, source_count integer not null);
          create table ordered_prefixes(
              board_key text not null, sequence_key text not null,
              history_json text not null, max_trusted_repeats integer not null,
              primary key(board_key, sequence_key));
          create table forcing_moves(
              board_key text not null, move integer not null,
              completion_targets_json text not null,
              reply_count integer not null,
              primary key(board_key, move));
        """)
        for key, value in (
            ("schema", "eclipse.private-tactical-overlay.v1"),
            ("policy", "LOCAL_ONLY; research-only; not model weights"),
            ("source_suite_sha256", hashlib.sha256(raw).hexdigest())
        ):
            db.execute("insert into metadata values (?,?)", (key, value))
        for case in dataset["private_cases"]:
            history, side = case["history"], case["side"]
            board = board_at(history)
            if side != 1 + len(history) % 2:
                raise ValueError("incorrect player in forcing source")
            identifier = board_key(board, side)
            sequence = hashlib.sha256(",".join(map(str, history)).encode()).hexdigest()
            repeats = int(case["max_within_source_repetitions"])
            sources = int(case.get("distinct_sources",
                                   case.get("distinct_source_count", 0)))
            if repeats < 1 or sources < 1:
                raise ValueError("untrusted repetition count")
            db.execute("""
                insert into positions values (?, ?, ?, ?)
                on conflict(board_key) do update set
                max_trusted_repeats = max(max_trusted_repeats, excluded.max_trusted_repeats),
                source_count = max(source_count, excluded.source_count)
            """, (identifier, side, repeats, sources))
            db.execute("insert or ignore into ordered_prefixes values (?,?,?,?)",
                       (identifier, sequence, json.dumps(history), repeats))
            target_map = case.get("completion_targets", case.get("completion_cells"))
            for move in case["proven_moves"]:
                targets = target_map[str(move)]
                verified = double_win_targets(board, side, move)
                if verified is None or verified != targets:
                    raise ValueError("two-turn proof certificate mismatch")
                db.execute("insert or replace into forcing_moves values (?,?,?,?)",
                           (identifier, move, json.dumps(verified),
                            225 - sum(bool(x) for x in board) - 1))
        db.commit()
        if db.execute("pragma integrity_check").fetchone()[0] != "ok":
            raise ValueError("private tactical DB integrity failed")
        totals = {
            table: db.execute(f"select count(*) from {table}").fetchone()[0]
            for table in ("positions", "ordered_prefixes", "forcing_moves")
        }
        return {
            "schema": "eclipse.private-tactical-overlay.v1",
            "privacy": "LOCAL_ONLY",
            "counts": totals,
            "full_strength_parity_verified": False,
            "stored_as_model_weights": False
        }
    except BaseException:
        db.close()
        target.unlink(missing_ok=True)
        raise
    finally:
        try:
            db.close()
        except sqlite3.Error:
            pass


def lookup_verified(database, history):
    board = board_at(history)
    side = 1 + len(history) % 2
    if history and completed_five(board, history[-1], 3-side):
        return []  # terminal position; never ask an engine for another move
    con = sqlite3.connect(
        f"file:{Path(database).resolve()}?mode=ro", uri=True)
    try:
        marker = con.execute(
            "select value from metadata where key='schema'").fetchone()
        if not marker or marker[0] != "eclipse.private-tactical-overlay.v1":
            raise ValueError("not a private ECLIPSE tactical overlay")
        records = con.execute(
            "select move,completion_targets_json from forcing_moves "
            "where board_key=? order by move", (board_key(board, side),)
        ).fetchall()
        return [
            move for move, stored in records
            if double_win_targets(board, side, move) == json.loads(stored)
        ]
    finally:
        con.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--suite", required=True, type=Path)
    parser.add_argument("--out-db", required=True, type=Path)
    parser.add_argument("--aggregate-out", type=Path)
    args = parser.parse_args()
    report = build_overlay(args.suite, args.out_db)
    if args.aggregate_out:
        args.aggregate_out.write_text(
            json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
