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
         opening: int) -> str:
    history = [opening]
    board, _ = replay_board(history)
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
    openings = [112, 111, 97, 127]
    counts = Counter()
    for pair in range(pairs):
        opening = openings[pair % len(openings)]
        for swift_black in (True, False):
            result = game(swift, cpp, swift_black, milliseconds, opening)
            counts[result] += 1
    games = pairs * 2
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
        "Swift_wins": counts["Swift"],
        "Cpp_wins": counts["Cpp"],
        "draws": counts["draw"],
        "Cpp_score_fraction": (counts["Cpp"] + 0.5*counts["draw"]) / games,
        "full_original_GomokuBot_parity_verified": False,
        "statistical_strength_parity_verified": False,
        "qualification": "small synthetic smoke; no personalized learning or calibrated Elo"
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
