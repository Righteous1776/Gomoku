#!/usr/bin/env python3
"""Actual compiled Swift UnifiedSearch vs C++ CLI, deterministic synthetic arena.

This is a correctness/smoke measurement. It is NOT a verified full GomokuBot
noninferiority result. No owner histories or model/user personal data used.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import random
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Training"))
from validate_dataset import winner_after

TACTICAL = [
    ("black-immediate-five", [0,15,1,16,2,17,3,18], {4}),
    ("black-must-block", [112,0,140,1,200,2,204,3], {4}),
    ("white-must-block", [0,112,1,140,2,200,3], {4}),
    ("black-distinct-double", [110,0,111,15,113,30], {112}),
    ("white-distinct-double", [0,110,17,111,34,113,51], {112}),
    ("counter-fork-defense", [0,110,17,111,34,113], {109,112,114}),
    ("empty-board-center", [], {112}),
]


def choose(exe: Path, moves: list[int], milliseconds: int) -> int:
    p = subprocess.run(
        [str(exe.resolve()), "--best", ",".join(map(str,moves)),
         "--ms", str(milliseconds)],
        capture_output=True, text=True, timeout=60
    )
    if p.returncode != 0:
        raise RuntimeError(f"{exe.name} exited {p.returncode}: {p.stderr[-600:]}")
    decoded = json.loads(p.stdout)
    return decoded["move"]


def replay_board(history: list[int]) -> tuple[list[int], int]:
    board = [0] * 225
    winner = 0
    for ply, move in enumerate(history):
        if type(move) is not int or not 0 <= move < 225 or board[move] or winner:
            raise ValueError("illegal synthetic fixture / play after terminal")
        who = 1 + (ply % 2)
        board[move] = who
        winner = winner_after(board, move, who)
    return board, winner


def run_tactics(swift: Path, cpp: Path, ms: int) -> tuple[int, int, int]:
    checked = 0
    exact = 0
    for name, history, eligible in TACTICAL:
        board, winner = replay_board(history)
        if winner:
            raise AssertionError(f"{name}: terminal fixture")
        native = choose(swift, history, ms)
        research = choose(cpp, history, ms)
        for variant, move in (("Swift", native), ("C++", research)):
            if type(move) is not int or not 0 <= move < 225 or board[move]:
                raise AssertionError(f"{name}: {variant} illegal move {move}")
            if move not in eligible:
                raise AssertionError(f"{name}: {variant} failed forced tactical gate; move={move}")
        checked += 1
        exact += (native == research)
    return checked, exact, len(TACTICAL)


def game(swift: Path, cpp: Path, swift_black: bool, ms: int,
         opening: list[int]) -> str:
    # Same full opening sequence in the side-swapped partner game.
    history = opening.copy()
    board, won = replay_board(history)
    if won:
        raise ValueError("Opening must not be terminal")
    while len(history) < 225:
        player = 1 + len(history) % 2
        is_swift = (player == 1) == swift_black
        chosen = choose(swift if is_swift else cpp, history, ms)
        if type(chosen) is not int or not 0 <= chosen < 225 or board[chosen]:
            raise AssertionError("illegal move during paired game")
        board[chosen] = player
        history.append(chosen)
        if winner_after(board, chosen, player):
            return "Swift" if is_swift else "Cpp"
    return "draw"


def arena(swift: Path, cpp: Path, pairs: int, milliseconds: int) -> dict:
    if pairs < 1 or milliseconds < 1:
        raise ValueError("pairs and milliseconds must be positive")
    checked, identical, expected = run_tactics(swift, cpp, milliseconds)
    counts = Counter()
    side_counts = Counter()
    paired_points = []
    openings_used = set()
    anchors = [r*15+c for r in range(5,10) for c in range(5,10)]
    for pair in range(pairs):
        # Unrepeated synthetic 2-ply openings; avoid repeatedly measuring
        # the same center game and misreporting correlated samples.
        first = anchors[pair % len(anchors)]
        options = [
            r*15+c for r in range(max(0,first//15-3), min(15,first//15+4))
            for c in range(max(0,first%15-3), min(15,first%15+4))
            if r*15+c != first
        ]
        rng = random.Random(20261121 + pair * 7919)
        rng.shuffle(options)
        opening = next(
            ([first, response] for response in options
             if (first, response) not in openings_used), None
        )
        if opening is None:
            raise ValueError("No fresh opening; reduce pair count")
        openings_used.add(tuple(opening))
        score = 0.0
        for swift_black in (True, False):
            outcome = game(swift, cpp, swift_black, milliseconds, opening)
            counts[outcome] += 1
            if outcome == "Cpp":
                score += 1.0
                side_counts["Cpp_black" if not swift_black else "Cpp_white"] += 1
            elif outcome == "draw":
                score += 0.5
        paired_points.append(score / 2)
    games = pairs * 2
    # Reproducible paired-opening bootstrap, only for reporting uncertainty.
    rng = random.Random(20261121)
    bootstrap = sorted(
        sum(rng.choice(paired_points) for _ in paired_points) / pairs
        for _ in range(2000)
    )
    ci = [bootstrap[49], bootstrap[1949]]
    return {
        "schema": "eclipse.swift-cpp.headless-arena.v1",
        "swift_reference": "actual compiled VeilGomokuUnifiedSearch.swift + R10",
        "cpp_candidate": "ECLIPSE C++20 research engine",
        "rules": "freestyle-15",
        "timing": {"equal_per_move_budget_ms": milliseconds},
        "forced_tactical_cases_passed_by_both": checked,
        "forced_tactical_cases_total": expected,
        "exact_move_agreement_within_forced_cases": identical,
        "color_swapped_paired_games": games,
        "distinct_opening_pairs": len(openings_used),
        "Cpp_score_pair_bootstrap_95_interval": ci,
        "Cpp_wins_as_black": side_counts["Cpp_black"],
        "Cpp_wins_as_white": side_counts["Cpp_white"],
        "Swift_wins": counts["Swift"],
        "Cpp_wins": counts["Cpp"],
        "draws": counts["draw"],
        "Cpp_score_fraction": (counts["Cpp"] + 0.5*counts["draw"]) / games,
        "full_original_GomokuBot_parity_verified": False,
        "statistical_strength_parity_verified": False,
        "qualification": "paired-opening exploratory bootstrap, NOT a noninferiority proof; no personalized learning or calibrated Elo"
    }


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--swift", type=Path, required=True)
    p.add_argument("--cpp", type=Path, required=True)
    p.add_argument("--pairs", type=int, default=1)
    p.add_argument("--ms", type=int, default=50)
    p.add_argument("--out", type=Path)
    args = p.parse_args()
    result = arena(args.swift, args.cpp, args.pairs, args.ms)
    output = json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output, encoding="utf-8")
    print(output, end="")


if __name__ == "__main__":
    main()
