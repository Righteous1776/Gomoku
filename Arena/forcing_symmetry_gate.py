#!/usr/bin/env python3
"""Public synthetic four-family, 8-symmetry ECLIPSE forcing tactical gate.

All 32 cases are generated from synthetic patterns. No owner's game histories,
training data, hashes, or personalized replay are imported or committed.
Eight symmetries per family are CORRELATED, not 32 independent tactics.
"""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess

from private_forcing_forks import completed_five, neighbors, direct_wins, double_win_targets

BASE = {
    "black_line": [110,0,111,15,113,30],
    "white_line": [0,110,17,111,34,113,51],
    "black_cross": [110,0,111,31,113,62,82,93,97,124,127,155],
    "white_cross": [0,110,31,111,62,113,93,82,124,97,155,127,187],
}


def transformed(square, symmetry):
    r, c = divmod(square, 15)
    variants = (
        (r, c), (c, 14-r), (14-r, 14-c), (14-c, r),
        (r, 14-c), (14-r, c), (c, r), (14-c, 14-r)
    )
    row, col = variants[symmetry]
    return row*15+col


def fixtures():
    scenarios = []
    for family, original in BASE.items():
        for symmetry in range(8):
            history = [transformed(i, symmetry) for i in original]
            board = [0]*225
            for ply, square in enumerate(history):
                if board[square]:
                    raise AssertionError("duplicate synthetic square")
                board[square] = 1+ply%2
                if completed_five(board, square, board[square]):
                    raise AssertionError("terminal synthetic fixture")
            side = 1+len(history)%2
            candidate_squares = neighbors(board)
            if direct_wins(board, side, candidate_squares) or direct_wins(
                    board, 3-side, candidate_squares):
                raise AssertionError("higher-priority tactic in synthetic fixture")
            winning_roots = {
                square: targets for square in candidate_squares
                if (targets := double_win_targets(
                    board, side, square, enemy_wins_before=[]))
            }
            if transformed(112, symmetry) not in winning_roots:
                raise AssertionError("synthetic double-threat was not certified")
            scenarios.append((family, symmetry, history, winning_roots))
    if len(scenarios) != 32:
        raise AssertionError("expected four pattern families times eight transforms")
    return scenarios


def real_move(executable, moves, milliseconds):
    proc = subprocess.run(
        [str(Path(executable).resolve()), "--best",
         ",".join(map(str, moves)), "--ms", str(milliseconds)],
        capture_output=True, text=True, timeout=70)
    if proc.returncode != 0:
        raise RuntimeError("real engine failed synthetic forcing position")
    result = json.loads(proc.stdout)
    return result["move"]


def arena(swift, cpp, milliseconds):
    groups = Counter()
    report = []
    for family, variant, history, known in fixtures():
        s = real_move(swift, history, milliseconds)
        c = real_move(cpp, history, milliseconds)
        if s not in known:
            raise AssertionError(f"Swift missed {family} symmetry {variant} "
                                 f"at {milliseconds}ms: {s}")
        if c not in known:
            raise AssertionError(f"C++ missed {family} symmetry {variant} "
                                 f"at {milliseconds}ms: {c}")
        groups[family] += 1
        report.append({"family": family, "matched": s == c})
    return {
        "budget_ms": milliseconds,
        "cases_both_legal_and_proven": len(report),
        "cases_expected": 32,
        "same_move": sum(case["matched"] for case in report),
        "per_family_pass": dict(groups)
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift", type=Path, required=True)
    parser.add_argument("--cpp", type=Path, required=True)
    parser.add_argument("--budgets", type=int, nargs="+", default=[75, 260])
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    if not args.budgets or any(ms < 1 or ms > 20000 for ms in args.budgets):
        parser.error("invalid budgets")
    reports = [arena(args.swift, args.cpp, ms) for ms in args.budgets]
    payload = {
        "schema": "eclipse.public-synthetic-forcing-symmetry.v1",
        "privacy": "synthetic fixture only; no private data",
        "reference": "original compiled Swift GomokuBot.empty",
        "candidate": "research C++20",
        "rules": "freestyle-15",
        "distinct_pattern_families": len(BASE),
        "d4_symmetries_per_family": 8,
        "budget_results": reports,
        "all_strength_tiers_verified": False,
        "personal_training_parity_verified": False,
        "qualification": "Correlated symmetry variants of 4 patterns, not statistical win-rate evidence"
    }
    body = json.dumps(payload, ensure_ascii=False, indent=2)+"\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(body, encoding="utf-8")
    print(body, end="")


if __name__ == "__main__":
    main()
