#!/usr/bin/env python3
"""Independent C++/Python freestyle-15 board-state parity.

Tests RULES, NOT search strength or tactical search equivalence to Swift ECLIPSE.
This script cannot promote the C++ prototype to the actual iOS game.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import random
import subprocess

SIDE = 15
DIRS = ((1, 0), (0, 1), (1, 1), (1, -1))


def state_after(moves):
    board = [0] * (SIDE * SIDE)
    winner = 0
    for ply, move in enumerate(moves):
        if (not isinstance(move, int) or not 0 <= move < 225 or
                board[move] or winner):
            raise ValueError("invalid replay")
        player = 1 + ply % 2
        board[move] = player
        row, col = divmod(move, SIDE)
        for dr, dc in DIRS:
            count = 1
            for sign in (-1, 1):
                rr, cc = row + sign * dr, col + sign * dc
                while (0 <= rr < SIDE and 0 <= cc < SIDE and
                       board[rr * SIDE + cc] == player):
                    count += 1
                    rr += sign * dr
                    cc += sign * dc
            if count >= 5:
                winner = player
                break
    if not winner and len(moves) == 225:
        winner = 3
    # Identical to Swift GomokuState: terminal does not advance currentPlayer.
    to_move = (1 + ((len(moves) - 1) % 2) if winner
               else 1 + len(moves) % 2)
    return {"board": board, "to_move": to_move, "status": winner,
            "plies": len(moves), "rules_abi": 1}


def fixtures():
    cases = [
        [], [112], [112, 113], [0, 15, 1, 16, 2, 17, 3, 18, 4],
        [15, 0, 30, 1, 45, 2, 60, 3, 100, 4],
        [0, 1, 16, 2, 32, 3, 48, 4, 64],
    ]
    for seed in range(8):
        rng = random.Random(2026 + seed)
        history = []
        available = list(range(225))
        for ply in range(65):
            move = available.pop(rng.randrange(len(available)))
            history.append(move)
            if ply in (0, 1, 7, 19, 39, 64):
                cases.append(history.copy())
            if state_after(history)["status"] != 0:
                break
    return cases


def compare(engine: Path):
    checked = 0
    for history in fixtures():
        expected = state_after(history)
        args = [str(engine.resolve()), "--state", ",".join(map(str, history))]
        proc = subprocess.run(args, text=True, capture_output=True,
                              timeout=20, check=True)
        actual = json.loads(proc.stdout)
        if actual != expected:
            first_diffs = [i for i, (a, b) in enumerate(
                zip(actual.get("board", []), expected["board"])
            ) if a != b][:6]
            raise AssertionError(
                f"C++/Python rules diverged at {len(history)} plies, "
                f"first board differences={first_diffs}; "
                f"other fields={(actual['status'],actual['to_move'])} vs "
                f"{(expected['status'],expected['to_move'])}"
            )
        checked += 1
    for illegal in ([112, 112], [225], [-1],
                    [0, 15, 1, 16, 2, 17, 3, 18, 4, 20]):
        invalid = subprocess.run(
            [str(engine.resolve()), "--state", ",".join(map(str, illegal))],
            capture_output=True, text=True, timeout=20,
        )
        if invalid.returncode == 0:
            raise AssertionError(f"C++ accepted illegal history {illegal}")
    print(f"C++20/Python independent rule replay parity PASS: "
          f"{checked} valid, 4 invalid histories (NOT search parity)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True, type=Path)
    args = parser.parse_args()
    compare(args.engine)


if __name__ == "__main__":
    main()
