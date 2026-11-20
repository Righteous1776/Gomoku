"""Produce fully validated dataset + provenance; samples come from C++ prototype only.
WARNING: not original Swift ECLIPSE self-play data and NOT a demonstrated strength upgrade.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from datetime import datetime, timezone
from validate_dataset import validate_file


def run(engine: Path, games: int, milliseconds: int, seed: int, destination: Path):
    if games < 1 or milliseconds < 1:
        raise ValueError("positive games and milliseconds required")
    destination.parent.mkdir(parents=True, exist_ok=True)
    cmd = [str(engine.resolve()), "--selfplay", "--games", str(games), "--ms", str(milliseconds), "--seed", str(seed), "--out", str(destination.resolve())]
    subprocess.run(cmd, check=True)
    count = validate_file(destination)
    sha = hashlib.sha256(destination.read_bytes()).hexdigest()
    info = {
        "schema": "eclipse.dataset.manifest.v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "engine_kind": "C++ experimental prototype - not Swift ECLIPSE parity",
        "engine_path": str(engine),
        "seed": seed, "games_generated_in_this_run": games,
        "total_records_in_file": count,
        "file": destination.name, "sha256": sha,
        "rules": "freestyle-15",
    }
    manifest = destination.with_suffix(destination.suffix + ".manifest.json")
    manifest.write_text(json.dumps(info, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--engine", type=Path, default=Path("build/Engine/gomoku_cli"))
    p.add_argument("--games", type=int, default=2)
    p.add_argument("--ms", type=int, default=20)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--out", type=Path, default=Path("Training/outputs/selfplay.jsonl"))
    opts = p.parse_args()
    print(run(opts.engine, opts.games, opts.ms, opts.seed, opts.out))
