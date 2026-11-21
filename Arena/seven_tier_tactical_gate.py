#!/usr/bin/env python3
"""Full original Swift GomokuBot seven-tier tactical safety audit vs C++.

Checks 7 real product difficulty budgets and exact mandatory tactical
obligations. This does not claim seven-tier strength/learning parity.
"""
from __future__ import annotations
from pathlib import Path
import argparse
import json
import subprocess
from compare_swift_cpp import TACTICAL, replay_board, choose

# These values are intentionally asserted against original Swift
# GomokuBotBudget.forDifficulty(..., profileLabel: "HIGH"). If the original
# changes, this test must be updated after reviewing the product tier policy.
TIERS = [
    ("relaxed", 130), ("balanced", 260), ("advanced", 520),
    ("master", 950), ("grandmaster", 1900),
    ("legendary", 3800), ("zenith", 5700)
]


def swift_tier_move(exe: Path, moves: list[int], tier: str, ms: int) -> dict:
    p = subprocess.run(
        [str(exe.resolve()), "--best", ",".join(map(str, moves)),
         "--ms", str(ms), "--tier", tier],
        capture_output=True, text=True, timeout=70)
    if p.returncode:
        raise RuntimeError(f"Swift tier {tier} failed: {p.stderr[-600:]}")
    result = json.loads(p.stdout)
    if result.get("tier") != tier or result.get("budget_ms") != ms:
        raise AssertionError(f"Swift tier policy mismatch: {tier}: {result}")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--swift", required=True, type=Path)
    parser.add_argument("--cpp", required=True, type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    records = []
    for tier, ms in TIERS:
        same = 0
        passed = 0
        for name, history, allowed in TACTICAL:
            board, winner = replay_board(history)
            if winner:
                raise AssertionError(f"Invalid tactical fixture: {name}")
            native = swift_tier_move(args.swift, history, tier, ms)
            cpp = choose(args.cpp, history, ms)
            for label, move in (("Swift", native["move"]), ("C++", cpp)):
                if not isinstance(move, int) or not 0 <= move < 225 or board[move]:
                    raise AssertionError(f"{tier}/{name}: illegal {label} move: {move}")
                if move not in allowed:
                    raise AssertionError(f"{tier}/{name}: tactical {label} failure: {move}")
            passed += 1
            same += native["move"] == cpp
        records.append({
            "tier": tier, "budget_ms_per_move": ms,
            "tactical_obligations_passed_by_both": passed,
            "tactical_obligations_total": len(TACTICAL),
            "exact_move_agreement": same
        })
    result = {
        "schema": "eclipse.swift-gomokubot.seven-tier-tactical.v1",
        "reference": "original compiled Swift GomokuBot.forDifficulty HIGH",
        "candidate": "research C++20 search with time budget only",
        "source_tier_budgets_verified": True,
        "independent_tactical_tests_per_tier": len(TACTICAL),
        "tier_count": len(records),
        "aggregate_tactical_obligations_passed_by_both": sum(
            r["tactical_obligations_passed_by_both"] for r in records),
        "aggregate_tactical_obligations_total": len(records)*len(TACTICAL),
        "tiers": records,
        "seven_tier_playing_strength_parity_verified": False,
        "qualification": "Only tactical floor, not full width/depth/learning parity; "
                         "C++ has not implemented all 7 native product budget policies."
    }
    output = json.dumps(result, ensure_ascii=False, indent=2)+"\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output, encoding="utf-8")
    print(output, end="")


if __name__ == "__main__":
    main()
