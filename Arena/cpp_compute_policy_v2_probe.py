#!/usr/bin/env python3
"""R17: real C++20 research engine policy V2 regression (synthetic only).

Reports ACTUAL search results and echoed compute policy, not an R29 model or
a claim of trained-Swift strength equivalence. No private histories in CI.
"""
import argparse
import json
from pathlib import Path
import subprocess


def search(binary, moves, policy):
    string = ",".join(map(str, policy))
    command = [
        str(Path(binary).resolve()), "--best",
        ",".join(map(str, moves)), "--policy-v2", string,
    ]
    run = subprocess.run(command, capture_output=True, text=True, timeout=25)
    if run.returncode:
        raise AssertionError("real C++ V2 compute search failed")
    result = json.loads(run.stdout)
    name = (
        "mode", "max_wall_time_ms", "max_nodes", "max_depth",
        "root_width", "reply_width", "continuation_width",
        "forced_line_depth", "candidate_radius",
    )
    assert result["applied_compute_policy"] == dict(zip(name, policy))
    assert type(result["nodes"]) is int and result["nodes"] >= 0
    assert type(result["elapsed_ms"]) is int and result["elapsed_ms"] >= 0
    assert type(result["completed_depth"]) is int and result["completed_depth"] >= 0
    assert type(result["move"]) is int and 0 <= result["move"] < 225
    assert result["move"] not in moves
    assert "prototype" in result["engine_revision"], (
        "R29 checkpoint is not installed in the C++ research runner"
    )
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cpp", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    binary = args.cpp
    forcing = [0, 15, 1, 16, 2, 17, 3, 18]
    # Exactly the nine fields declared by EGComputePolicyV2.
    unlimited = [0, 0, 0, 15, 60, 40, 30, 10, 5]
    extended = [1, 123456, 70000000, 15, 60, 40, 30, 10, 5]
    forced = [search(binary, forcing, policy) for policy in (unlimited, extended)]
    assert all(record["move"] == 4 for record in forced), (
        "Mandatory tactical win must survive any trainer budget"
    )
    quiet = [112, 97]
    shallow = search(binary, quiet, [0, 0, 0, 1, 2, 2, 1, 0, 5])
    deeper = search(binary, quiet, [0, 0, 0, 2, 6, 4, 4, 0, 5])
    assert shallow["completed_depth"] == 1
    assert deeper["completed_depth"] == 2
    assert shallow["applied_compute_policy"]["root_width"] == 2
    assert deeper["applied_compute_policy"]["root_width"] == 6

    # Invalid policy rejected, without falling through to old legacy --ms.
    bad = subprocess.run(
        [str(binary.resolve()), "--best", ",".join(map(str, forcing)),
         "--policy-v2", "1,0,0,15,60,40,30,10,5"],
        capture_output=True, text=True, timeout=10
    )
    assert bad.returncode != 0, "budgeted mode with 0ms must fail closed"

    result = {
        "schema": "eclipse.cpp.trainer-policy-v2.actual-run.v1",
        "privacy": "public synthetic fixtures only",
        "real_cpp_compute_decisions": 4,
        "unlimited_budget_accepted": True,
        "budget_123456ms_accepted_without_20s_cap": True,
        "depth_one_and_two_executed": True,
        "forced_tactical_wins": 2,
        "trainer_settings_applied_exactly": True,
        "cpp_currently_loads_r29_checkpoint": False,
        "trained_swift_strength_parity_verified": False,
        "measurements": {
            "forced_unlimited": {
                "elapsed_ms": forced[0]["elapsed_ms"],
                "nodes": forced[0]["nodes"]
            },
            "forced_extended": {
                "elapsed_ms": forced[1]["elapsed_ms"],
                "nodes": forced[1]["nodes"]
            },
            "depth_one": {
                "elapsed_ms": shallow["elapsed_ms"],
                "nodes": shallow["nodes"]
            },
            "depth_two": {
                "elapsed_ms": deeper["elapsed_ms"],
                "nodes": deeper["nodes"]
            }
        }
    }
    body = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(body, encoding="utf8")
    print(body, end="")


if __name__ == "__main__":
    main()
