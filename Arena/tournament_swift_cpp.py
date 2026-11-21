#!/usr/bin/env python3
"""Stratified, paired-color Swift-vs-C++ ECLIPSE evidence. Synthetic positions only.

The Swift binary is built from the original VeilGomokuUnifiedSearch.swift source.
This is a descriptive pilot, NOT an equivalence certification of full GomokuBot.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import random
from pathlib import Path

from compare_swift_cpp import choose, replay_board, run_tactics, winner_after

# Fixed independent synthetic starting positions. Never contains user match data.
# Each entry is replay-validated before the benchmark, and is used twice
# with Swift/C++ colors swapped; all remaining moves are chosen by the engines.
OPENINGS = [
    [112], [111], [97], [127],
    [112,111,98,97], [112,97,111,126],
    [112,113,97,98], [112,96,113,81,127,110],
    [111,112,97,113,127,98], [97,112,113,111],
    [112,128,96,97,111,113], [98,112,113,97,128,111],
    [112,97,98,113,126,127], [111,112,126,96,97,128],
    [113,112,98,111,127,97], [112,111,127,128,97,98],
]


def validate_openings() -> None:
    for index, history in enumerate(OPENINGS):
        board, winner = replay_board(history)
        if winner or len(set(history)) != len(history):
            raise ValueError(f"illegal/terminal synthetic opening {index}")
        if not 1 <= len(history) <= 8 or any(b not in (0, 1, 2) for b in board):
            raise ValueError(f"unexpected opening {index}")


def game(swift: Path, cpp: Path, opening: list[int],
         swift_black: bool, ms: int) -> str:
    moves = opening[:]
    board, winner = replay_board(moves)
    if winner:
        raise AssertionError("benchmark opening unexpectedly ended game")
    while len(moves) < 225:
        who = 1 + len(moves) % 2
        swift_turn = (who == 1) == swift_black
        idx = choose(swift if swift_turn else cpp, moves, ms)
        if type(idx) is not int or not 0 <= idx < 225 or board[idx] != 0:
            raise AssertionError(f"illegal move: ply={len(moves)} side={who} move={idx}")
        board[idx] = who
        moves.append(idx)
        if winner_after(board, idx, who):
            return "Swift" if swift_turn else "Cpp"
    return "draw"


def cpp_points(outcome: str) -> float:
    return {"Cpp": 1.0, "Swift": 0.0, "draw": 0.5}[outcome]


def paired_bootstrap_ci(scores: list[float], seed: int) -> list[float]:
    """Resample opening *pairs*, not individual games, to preserve dependence.

    This exploratory percentile interval is NOT a calibrated strength bound
    for a wider opening distribution; N can be very small.
    """
    rng = random.Random(seed)
    estimates: list[float] = []
    n = len(scores)
    for _ in range(5000):
        estimates.append(sum(scores[rng.randrange(n)] for __ in range(n)) / n)
    estimates.sort()
    return [round(estimates[124], 4), round(estimates[4874], 4)]


def run(swift: Path, cpp: Path, pairs_by_ms: list[tuple[int, int]],
        seed: int) -> dict:
    validate_openings()
    if any(not 1 <= ms <= 20000 or not 1 <= pairs <= 10000
           for ms, pairs in pairs_by_ms):
        raise ValueError("invalid budget/pairs")
    # These are deliberately simple synthetic testing obligations, not data
    # distilled from any of the user's private match exports.
    tactical, exact, total_tactics = run_tactics(swift, cpp, min(ms for ms, _ in pairs_by_ms))
    rows = []
    total_games = 0
    overall = Counter()
    for tier, (ms, count) in enumerate(pairs_by_ms):
        counts = Counter()
        scores = []
        opening_indices = []
        for pair in range(count):
            # Shift the opening coverage deterministically between budget tiers.
            index = (pair + tier * 5 + seed % len(OPENINGS)) % len(OPENINGS)
            opening = OPENINGS[index]
            opening_indices.append(index)
            results = [
                game(swift, cpp, opening, swift_black=True, ms=ms),
                game(swift, cpp, opening, swift_black=False, ms=ms)
            ]
            counts.update(results)
            scores.append(sum(cpp_points(x) for x in results) / 2.0)
        total_games += 2 * count
        overall.update(counts)
        rows.append({
            "per_move_budget_ms": ms,
            "paired_openings": count,
            "color_swapped_games": 2 * count,
            "synthetic_opening_ids": opening_indices,
            "Swift_wins": counts["Swift"],
            "Cpp_wins": counts["Cpp"],
            "draws": counts["draw"],
            "Cpp_score_fraction": round(sum(scores) / count, 4),
            "exploratory_paired_bootstrap_95pct": paired_bootstrap_ci(scores, seed + ms),
        })
    return {
        "schema": "eclipse.swift-cpp.stratified-paired.v1",
        "engine_reference": "original compiled Swift VeilGomokuUnifiedSearch + original R10",
        "candidate": "experimental C++20 ECLIPSE research engine",
        "rules": "unrestricted freestyle 15x15",
        "fixed_seed": seed,
        "synthetic_opening_count": len(OPENINGS),
        "tactical_cases_passed_by_both": tactical,
        "tactical_cases_total": total_tactics,
        "forced_tactical_exact_agreement": exact,
        "tiers": rows,
        "total_paired_games": total_games,
        "overall": {
            "Swift_wins": overall["Swift"],
            "Cpp_wins": overall["Cpp"],
            "draws": overall["draw"],
        },
        "full_native_GomokuBot": False,
        "statistical_noninferiority_pass": False,
        "ship_gate": "BLOCKED",
        "qualification": (
            "Exploratory synthetic game pilot, paired opening and swapped color. "
            "Not a seven-tier production GomokuBot comparison. Paired bootstrap "
            "intervals are descriptive with low sample size, not a release proof."
        ),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift", required=True, type=Path)
    parser.add_argument("--cpp", required=True, type=Path)
    parser.add_argument("--tier", action="append", metavar="MS:PAIRS",
                        default=[], help="e.g. --tier 75:8 --tier 250:6 --tier 950:4")
    parser.add_argument("--seed", type=int, default=20261121)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    parsed = []
    for tier in args.tier or ["75:8", "250:6", "950:4"]:
        ms, pairs = tier.split(":", maxsplit=1)
        parsed.append((int(ms), int(pairs)))
    report = run(args.swift, args.cpp, parsed, args.seed)
    payload = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(payload, encoding="utf-8")
    print(payload, end="")


if __name__ == "__main__":
    main()
