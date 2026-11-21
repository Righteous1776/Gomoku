#!/usr/bin/env python3
"""Public synthetic CLI smoke: explicit V9 research-mode search, never production."""
import json
from pathlib import Path
import subprocess
import sys

CLI = str(Path(sys.argv[1]).resolve())
POLICY = "1,1500,100000,1,1,1,1,0,2"
FORCED = "10,4,79,19,95,34,111,49"

def run(*args, ok=True):
    result = subprocess.run([CLI, *args], text=True, capture_output=True,
                            timeout=15)
    if ok:
        assert result.returncode == 0, (args, result.stderr, result.stdout)
        return json.loads(result.stdout)
    assert result.returncode != 0, (args, result.stdout)
    assert "ERROR" in result.stderr
    return None

def check(name):
    for history, forced in (("112,97", False), (FORCED, True)):
        data = run("--best", history, "--policy-v2", POLICY,
                   "--research-ranker", name)
        assert data["research_ranker"] == name, data
        assert data["applied_compute_policy"]["root_width"] == 1, data
        assert data["applied_compute_policy"]["max_wall_time_ms"] == 1500, data
        assert "checkpoint_sha256" not in data, data
        assert "production_loaded" not in data, data
        if forced:
            assert data["move"] == 64, data
        else:
            assert data["move"] not in (112, 97), data
            assert 0 <= data["move"] < 225, data

def main():
    check("v9-astra")
    check("v9-sol")
    default = run("--best", "112,97", "--policy-v2", POLICY)
    assert "research_ranker" not in default, default
    run("--best", "112,97", "--policy-v2", POLICY,
        "--research-ranker", "bad", ok=False)
    run("--best", "112,97", "--ms", "1",
        "--research-ranker", "v9-astra", ok=False)
    run("--best", "112,97", "--research-ranker", "v9-sol", ok=False)
    run("--best", "112,97", "--policy-v2", POLICY,
        "--research-ranker", "v9-sol", "--research-ranker", "v9-astra",
        ok=False)
    print("V9 CLI opt-in: both real-tree rankers, forced defense 64, "
          "strict flags, legacy output compatibility PASSED")

if __name__ == "__main__":
    main()
