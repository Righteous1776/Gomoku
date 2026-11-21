#!/usr/bin/env python3
"""R15: real native Swift vs C++ compute observations at original seven budgets.

Both engines run the same SYNTHETIC legal board positions under the same
wall-clock budget. This is telemetry, not evidence of equal playing strength,
equal search architecture, personal training or independent R29 checkpoints.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import subprocess

from compare_swift_cpp import replay_board

# Exact original HIGH-profile Swift budget, not guessed multipliers.
TIERS = [
    ("relaxed",130), ("balanced",260), ("advanced",520),
    ("master",950), ("grandmaster",1900),
    ("legendary",3800), ("zenith",5700),
]
# Only public synthetic positions; short but not all one-ply winning positions.
POSITIONS = [
    ("empty", []),
    ("center-opening", [112, 97]),
    ("split-midboard", [112, 97, 113, 98, 129, 114, 111, 143]),
    ("black-forcing-fork", [110, 0, 111, 15, 113, 30]),
]


def measure(exe: Path, history: list[int], ms: int, tier: str | None):
    command=[str(exe.resolve()),"--best",",".join(map(str,history)),"--ms",str(ms)]
    if tier is not None:
        command += ["--tier",tier]
    proc=subprocess.run(command, text=True, capture_output=True, timeout=75)
    if proc.returncode:
        raise RuntimeError("engine failure on a synthetic compute case")
    data=json.loads(proc.stdout)
    board, outcome=replay_board(history)
    if outcome:
        raise AssertionError("synthetic fixture is terminal")
    move=data.get("move")
    if type(move) is not int or not 0 <= move < 225 or board[move]:
        raise AssertionError("engine produced invalid synthetic move")
    elapsed=data.get("elapsed_ms")
    nodes=data.get("nodes")
    if type(elapsed) is not int or elapsed < 0 or type(nodes) is not int or nodes < 0:
        raise AssertionError("engine missing real elapsed_ms or node telemetry")
    return {
        "elapsed_ms":elapsed,"nodes":nodes,"move":move,
        "completed_depth":data.get("completed_depth",None)
    }


def run(swift: Path,cpp: Path):
    results=[]
    for tier,ms in TIERS:
        pairs=[]
        for _,history in POSITIONS:
            original=measure(swift,history,ms,tier)
            candidate=measure(cpp,history,ms,None)
            pairs.append({
                "swift_ms":original["elapsed_ms"],
                "cpp_ms":candidate["elapsed_ms"],
                "swift_nodes":original["nodes"],
                "cpp_nodes":candidate["nodes"],
                "swift_depth":original["completed_depth"],
                "cpp_depth":candidate["completed_depth"],
                "exact_same_move":original["move"]==candidate["move"],
                "swift_over_requested_budget":original["elapsed_ms"]>ms,
                "cpp_over_requested_budget":candidate["elapsed_ms"]>ms
            })
        results.append({
            "tier":tier,"requested_budget_ms":ms,"position_count":len(pairs),
            "swift_observed_total_ms":sum(x["swift_ms"] for x in pairs),
            "cpp_observed_total_ms":sum(x["cpp_ms"] for x in pairs),
            "swift_observed_total_nodes":sum(x["swift_nodes"] for x in pairs),
            "cpp_observed_total_nodes":sum(x["cpp_nodes"] for x in pairs),
            "exact_move_agreement":sum(x["exact_same_move"] for x in pairs),
            "swift_over_budget_cases":sum(x["swift_over_requested_budget"] for x in pairs),
            "cpp_over_budget_cases":sum(x["cpp_over_requested_budget"] for x in pairs),
            "samples":pairs
        })
    return {
        "schema":"eclipse.compute-parity-observations.v1",
        "reference":"original compiled Swift GomokuBot without private learning",
        "candidate":"C++ research core without private checkpoint",
        "scenarios_per_budget":len(POSITIONS),
        "original_swift_tier_count":len(TIERS),
        "total_actual_engine_decisions":len(TIERS)*len(POSITIONS)*2,
        "same_wall_clock_budget_requested":True,
        "equal_internal_search_policies":False,
        "trained_model_strength_parity_verified":False,
        "notes":"Observed real elapsed time/nodes; synthetic correlated scenarios, no strength claim.",
        "tiers":results
    }


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--swift",required=True,type=Path)
    parser.add_argument("--cpp",required=True,type=Path)
    parser.add_argument("--out",type=Path)
    args=parser.parse_args()
    result=run(args.swift,args.cpp)
    body=json.dumps(result,indent=2,ensure_ascii=False)+"\n"
    if args.out:
        args.out.parent.mkdir(parents=True,exist_ok=True)
        args.out.write_text(body,encoding="utf8")
    print(body,end="")


if __name__=="__main__":
    main()
