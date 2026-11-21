#!/usr/bin/env python3
"""LOCAL-ONLY proof-grade two-turn Gomoku fork discovery from private SQLite.

No source file, game, move history, source filename, or board hash is printed.
Output aggregate report publicly ONLY; --private-out stays in private workspace.
A proven fork is a sufficient freestyle-15 two-turn winning move, not a
complete VCF/VCT solver and never proof of defeating any external AI.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sqlite3

AXES = ((1, 0), (0, 1), (1, 1), (1, -1))


def winning_at(board: list[int], square: int, side: int) -> bool:
    if board[square]:
        return False
    row, col = divmod(square, 15)
    for dr, dc in AXES:
        length = 1
        for sign in (-1, 1):
            r, c = row + sign * dr, col + sign * dc
            while 0 <= r < 15 and 0 <= c < 15 and board[15*r + c] == side:
                length += 1
                r += sign * dr
                c += sign * dc
        if length >= 5:
            return True
    return False


def completed_five(board, square, side):
    assert board[square] == side
    board[square] = 0
    try:
        return winning_at(board, square, side)
    finally:
        board[square] = side


def neighbors(board, radius=2):
    if not any(board):
        return [112]
    available = set()
    for pos, stone in enumerate(board):
        if not stone:
            continue
        row, col = divmod(pos, 15)
        for r in range(max(0, row-radius), min(15, row+radius+1)):
            for c in range(max(0, col-radius), min(15, col+radius+1)):
                idx = r*15+c
                if board[idx] == 0:
                    available.add(idx)
    return sorted(available)


def direct_wins(board, side, squares=None):
    return [pos for pos in (squares if squares is not None else neighbors(board))
            if winning_at(board, pos, side)]


def double_win_targets(board, side, move, enemy_wins_before=None):
    """Distinct five-completion squares newly created by this candidate.

    Caller can pass the preverified empty list if the original position has
    no opponent immediate wins. Our placement never creates enemy stones, so
    enemy immediate wins can only disappear, never appear.
    """
    if board[move]:
        return None
    if enemy_wins_before is None:
        enemy_wins_before = direct_wins(board, 3-side)
    if any(threat != move for threat in enemy_wins_before):
        return None
    board[move] = side
    try:
        if completed_five(board, move, side):
            return None  # one-ply win is a separate, higher gate
        row, col = divmod(move, 15)
        completions = set()
        for dr, dc in AXES:
            for offset in range(5):
                r0, c0 = row-offset*dr, col-offset*dc
                if not (0 <= r0 < 15 and 0 <= c0 < 15 and
                        0 <= r0+4*dr < 15 and 0 <= c0+4*dc < 15):
                    continue
                cells = [board[15*(r0+i*dr)+c0+i*dc] for i in range(5)]
                if cells.count(side) == 4 and cells.count(0) == 1:
                    gap = cells.index(0)
                    completions.add(15*(r0+gap*dr)+c0+gap*dc)
        return sorted(completions) if len(completions) >= 2 else None
    finally:
        board[move] = 0


def exhaust_opponent_replies(board, side, move, targets):
    """Independently check every legal enemy reply leaves an instant own win."""
    if board[move] or len(set(targets)) < 2:
        raise AssertionError("invalid forcing fork certificate")
    board[move] = side
    checked = 0
    try:
        if completed_five(board, move, side):
            raise AssertionError("immediate win labeled as two-turn fork")
        for answer in range(225):
            if board[answer]:
                continue
            if winning_at(board, answer, 3-side):
                raise AssertionError("enemy has immediate winning response")
            board[answer] = 3-side
            try:
                if not any(board[t] == 0 and winning_at(board, t, side)
                           for t in targets):
                    raise AssertionError("fork refuted by a legal answer")
            finally:
                board[answer] = 0
            checked += 1
    finally:
        board[move] = 0
    return checked


def verified_sources(db):
    with sqlite3.connect(f"file:{Path(db).resolve()}?mode=ro", uri=True) as con:
        con.row_factory = sqlite3.Row
        if con.execute("pragma integrity_check").fetchone()[0] != "ok":
            raise ValueError("bad SQLite integrity")
        policy = con.execute(
            "select v from metadata where k='data_policy'").fetchone()
        if not policy or "LOCAL_ONLY" not in policy[0]:
            raise ValueError("missing private-only evidence policy")
        query = """
            with per_source as (
                select s.id, s.actions_json, src.id source_id,
                       count(*) repeats,
                       sum(case when g.diagnostic='ok' then 0 else 1 end) bad
                  from sequences s join game_observations g on g.sequence_id=s.id
                     join sources src on src.id=g.source_id
                 where src.integrity in ('canonical_match','historical_sha_pinned')
                 group by s.id, s.actions_json, src.id
            )
            select id, actions_json, max(repeats) repeats,
                   count(source_id) source_count, sum(bad) bad
              from per_source group by id, actions_json order by id
        """
        for rec in con.execute(query):
            if rec["bad"]:
                continue
            tokens = json.loads(rec["actions_json"])
            if (not isinstance(tokens, list) or
                    hashlib.sha256("\0".join(tokens).encode()).hexdigest() != rec["id"]):
                raise ValueError("bad trusted sequence digest")
            board = [0]*225
            history = []
            last_actor = None
            for ply, token in enumerate(tokens):
                if (not isinstance(token, str) or len(token) < 2 or
                        token[0] not in ("a", "h") or not token[1:].isdigit()):
                    raise ValueError("bad trusted action")
                square, side = int(token[1:]), 1+ply%2
                if (not 0 <= square < 225 or board[square] or
                        token[0] == last_actor):
                    raise ValueError("invalid trusted history")
                board[square] = side
                if completed_five(board, square, side) and ply != len(tokens)-1:
                    raise ValueError("moves after legal terminal")
                history.append(square)
                last_actor = token[0]
            yield history, rec["repeats"], rec["source_count"]


def analyze(db, max_positions=1500):
    games = list(verified_sources(db))
    prefixes = {}
    for moves, repeats, source_count in games:
        for depth in range(6, min(len(moves), 160)):
            prior = tuple(moves[:depth])  # ORDERED, not just board occupancy
            evidence = prefixes.setdefault(prior, {
                "max_repeats": 0, "sources": 0, "observed_next": set()
            })
            evidence["max_repeats"] = max(evidence["max_repeats"], repeats)
            evidence["sources"] = max(evidence["sources"], source_count)
            evidence["observed_next"].add(moves[depth])
    ranked = sorted(prefixes.items(), key=lambda item: (
        -(item[1]["max_repeats"] > 1), -item[1]["max_repeats"],
        -item[1]["sources"], -len(item[0]), item[0]))
    if max_positions:
        ranked = ranked[:max_positions]
    cases, count = [], Counter()
    for history, evidence in ranked:
        board = [0]*225
        for ply, pos in enumerate(history):
            board[pos] = 1+ply%2
        side = 1+len(history)%2
        candidates = neighbors(board)
        # Own instant-five and opponent mandatory block are higher priorities.
        if direct_wins(board, side, candidates) or direct_wins(
                board, 3-side, candidates):
            count["positions_with_higher_priority_tactics"] += 1
            continue
        proven, target_map = [], {}
        for move in candidates:
            targets = double_win_targets(board, side, move, enemy_wins_before=[])
            if targets:
                proven.append(move)
                target_map[str(move)] = targets
                count["opponent_replies_exhaustively_checked"] += (
                    exhaust_opponent_replies(board, side, move, targets))
                count["proven_two_turn_winning_moves"] += 1
        count["searched_quiet_positions"] += 1
        if proven:
            count["proven_fork_positions"] += 1
            count["repeated_fork_positions"] += (evidence["max_repeats"] > 1)
            count["observed_next_move_was_proven"] += bool(
                evidence["observed_next"].intersection(proven))
            cases.append({
                "history": list(history), "side": side,
                "proven_moves": proven, "completion_targets": target_map,
                "max_within_source_repetitions": evidence["max_repeats"],
                "distinct_sources": evidence["sources"]
            })
    report = {
        "schema": "eclipse.private-forcing-forks.v1",
        "privacy": "LOCAL_ONLY; private cases require --private-out",
        "evidence": "source integrity previously reviewed; this tool does not reauthenticate original exports",
        "rules": "freestyle-15",
        "replayable_trusted_distinct_games": len(games),
        "distinct_ordered_prefixes": len(prefixes),
        "position_limit": max_positions,
        "counts": dict(count),
        "noninferiority_to_original_swift_verified": False,
        "victory_vs_external_tianyuan_six_verified": False
    }
    return cases, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", required=True, type=Path)
    parser.add_argument("--limit", type=int, default=1500)
    parser.add_argument("--private-out", type=Path)
    parser.add_argument("--aggregate-out", type=Path)
    args = parser.parse_args()
    if not 0 <= args.limit <= 20000:
        parser.error("invalid position limit")
    cases, report = analyze(args.db, args.limit)
    if args.private_out:
        args.private_out.write_text(json.dumps({
            "report": report, "private_cases": cases
        }, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.aggregate_out:
        args.aggregate_out.write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    # Aggregate safe to display; no actions, board hashes, filenames or seeds.
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
