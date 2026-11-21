#!/usr/bin/env python3
"""Freestyle tactical regression gate for the research C++ CLI.

Checks mandatory one-ply wins/blocks and legality on synthetic fixtures.
This is NOT parity with Swift ECLIPSE and NOT evidence of playing strength.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Training"))
from check_cpp_rules_parity import state_after
from validate_dataset import winner_after


def check_fixture(engine: Path, case: dict, milliseconds: int) -> None:
    history = case["history"]
    expected = case["expected_moves"]
    if not expected or not all(type(m) is int for m in expected):
        raise ValueError(f"{case['id']}: expected moves must be nonempty integers")
    state = state_after(history)
    if state["status"] != 0:
        raise ValueError(f"{case['id']}: fixture must be a nonterminal game")
    board = state["board"]
    side = state["to_move"]
    target = side if case["obligation"] == "win" else 3 - side
    if case["obligation"] not in ("win", "block"):
        raise ValueError(f"{case['id']}: unknown obligation")
    for m in expected:
        if not 0 <= m < 225 or board[m]:
            raise ValueError(f"{case['id']}: expected square is illegal")
        probe = board.copy()
        probe[m] = target
        if winner_after(probe, m, target) != target:
            raise ValueError(f"{case['id']}: expected square is not a tactical {case['obligation']}")
    cmd = [str(engine.resolve()), "--best", ",".join(map(str, history)),
           "--ms", str(milliseconds)]
    proc = subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=30)
    selected = json.loads(proc.stdout)["move"]
    if type(selected) is not int or not 0 <= selected < 225 or board[selected]:
        raise AssertionError(f"{case['id']}: C++ produced an illegal move: {selected}")
    if selected not in expected:
        raise AssertionError(f"{case['id']}: C++ chose {selected} instead of {expected}")


def check(engine: Path, fixtures: Path, milliseconds: int) -> dict:
    if milliseconds < 1 or milliseconds > 20000:
        raise ValueError("milliseconds must be between 1 and 20000")
    data = json.loads(fixtures.read_text(encoding="utf-8"))
    if data.get("schema") != "eclipse.tactical-regression.v1" or not data.get("cases"):
        raise ValueError("unexpected tactical fixture schema or empty cases")
    seen = set()
    for case in data["cases"]:
        if case["id"] in seen:
            raise ValueError("duplicate fixture id")
        seen.add(case["id"])
        check_fixture(engine, case, milliseconds)
    return {"gate": "cpp-experimental-tactical-safety", "passed": len(seen),
            "failed": 0, "swift_parity_verified": False,
            "strength_upgrade_verified": False}


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--engine", type=Path, required=True)
    p.add_argument("--fixtures", type=Path, required=True)
    p.add_argument("--ms", type=int, default=100)
    args = p.parse_args()
    print(json.dumps(check(args.engine, args.fixtures, args.ms), sort_keys=True))


if __name__ == "__main__":
    main()
