#!/usr/bin/env python3
"""Generate reproducible, *public-synthetic-only* Tianyuan 6x teacher decisions.

The executable must be the actual compiled original Swift GomokuBot. It is
not a python replica; no private .vltrain, SQLite, or user positions are read.
Samples are research evidence, not verified optimal moves or training promotion.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import random
import subprocess
from pathlib import Path

DIRECTIONS = ((1, 0), (0, 1), (1, 1), (1, -1))
SYNTHETIC_TACTICS = [
    ("immediate_win", [0, 15, 1, 16, 2, 17, 3, 18]),
    ("must_block", [112, 0, 140, 1, 200, 2, 204, 3]),
    ("white_block", [0, 112, 1, 140, 2, 200, 3]),
    ("double_threat", [110, 0, 111, 15, 113, 30]),
    ("white_double", [0, 110, 17, 111, 34, 113, 51]),
    ("fork_defense", [0, 110, 17, 111, 34, 113]),
    ("opening", []),
]


def five(board: list[int], index: int, side: int) -> bool:
    r, c = divmod(index, 15)
    for dr, dc in DIRECTIONS:
        n = 1
        for sign in (-1, 1):
            rr, cc = r + sign * dr, c + sign * dc
            while 0 <= rr < 15 and 0 <= cc < 15 and board[15 * rr + cc] == side:
                n += 1
                rr += sign * dr
                cc += sign * dc
        if n >= 5:
            return True
    return False


def replay(history: list[int]) -> list[int]:
    board = [0] * 225
    for ply, move in enumerate(history):
        if type(move) is not int or not 0 <= move < 225 or board[move]:
            raise ValueError("invalid move history")
        side = 1 + ply % 2
        board[move] = side
        if five(board, move, side):
            raise ValueError("terminal/continued move history is ineligible")
    return board


def nearby(board: list[int], radius: int = 2) -> list[int]:
    occupied = [i for i, v in enumerate(board) if v]
    if not occupied:
        return [112]
    moves: set[int] = set()
    for move in occupied:
        r, c = divmod(move, 15)
        for dr in range(-radius, radius + 1):
            for dc in range(-radius, radius + 1):
                rr, cc = r + dr, c + dc
                if 0 <= rr < 15 and 0 <= cc < 15:
                    target = 15 * rr + cc
                    if board[target] == 0:
                        moves.add(target)
    return sorted(moves)


def transform(index: int, rotate: int, reflect: bool) -> int:
    r, c = divmod(index, 15)
    if reflect:
        c = 14 - c
    for _ in range(rotate):
        r, c = c, 14 - r
    return r * 15 + c


def d4_family(history: list[int]) -> str:
    prefix = history[:4]
    canonical = min(
        tuple(transform(i, rot, reflect) for i in prefix)
        for rot in range(4) for reflect in (False, True)
    )
    return hashlib.sha256(json.dumps(canonical).encode("ascii")).hexdigest()[:24]


def seeded_history(seed: int) -> list[int]:
    rng = random.Random(seed)
    first = [112, 111, 113, 97, 127, 98, 126, 96, 128][seed % 9]
    board = [0] * 225
    history: list[int] = []
    target = 6 + (seed % 17)
    for ply in range(target):
        pool = [first] if not history else nearby(board, radius=2)
        # Produce a local, diverse legal history; don't play beyond a terminal.
        viable: list[int] = []
        for candidate in pool:
            board[candidate] = 1 + ply % 2
            wins = five(board, candidate, 1 + ply % 2)
            board[candidate] = 0
            if not wins:
                viable.append(candidate)
        if not viable:
            break
        viable.sort(key=lambda x: (abs(x // 15 - 7) + abs(x % 15 - 7), x))
        if ply and rng.random() < 0.75:
            selectable = viable[:min(28, len(viable))]
        else:
            selectable = viable
        choice = rng.choice(selectable)
        board[choice] = 1 + ply % 2
        history.append(choice)
    replay(history)
    return history


def validate_pv(board: list[int], side: int, pv: list[int]) -> None:
    b = board.copy()
    for ply, move in enumerate(pv):
        if type(move) is not int or not 0 <= move < 225 or b[move]:
            raise ValueError("teacher returned invalid PV")
        actor = side if ply % 2 == 0 else 3 - side
        b[move] = actor
        # A PV must not continue after an actual terminal move.
        if five(b, move, actor) and ply != len(pv) - 1:
            raise ValueError("teacher PV continues after a win")


def classify_teacher_trace(traces: list[dict]) -> tuple[int, int]:
    """Do not confuse a VCF proof's PV length with completed PVS depth."""
    iterative = max((t["completed_depth"] for t in traces
                     if t.get("phase") == "deepening"), default=0)
    proof = max((t["completed_depth"] for t in traces
                 if t.get("rule") == "verified-forcing-four"), default=0)
    if iterative and proof:
        raise ValueError("mixed VCF proof and completed PVS depth in same teacher event")
    return iterative, proof


def collect(swift: Path, count: int, out: Path, seed: int,
            budget_ms: int, source_root: Path) -> dict:
    if count < 1 or count > 4096:
        raise ValueError("samples out of permitted range")
    if budget_ms != 5700:
        raise ValueError("HIGH-profile zenith 6x teacher budget must be 5700ms")
    if not swift.is_file():
        raise FileNotFoundError(swift)
    exact_source = [
        "Legacy/Original/VeilLink/Agent/Games/GomokuBot.swift",
        "Legacy/Original/VeilLink/Agent/Games/EclipseDifficultyPolicy.swift",
        "Legacy/Original/VeilLink/Agent/Games/VeilGomokuUnifiedSearch.swift",
        "Legacy/Original/VeilLink/Agent/Games/EclipseTrainedOrdering.swift",
        "Legacy/Original/VeilLink/Agent/Games/GomokuCounterForkR4.swift",
    ]
    sources = {}
    for relative in exact_source:
        raw = (source_root / relative).read_bytes()
        sources[relative] = hashlib.sha256(raw).hexdigest()
    records = []
    for i in range(count):
        kind, history = SYNTHETIC_TACTICS[i] if i < len(SYNTHETIC_TACTICS) else (
            "synthetic_local", seeded_history(seed + 7919 * i)
        )
        board = replay(history)
        proc = subprocess.run(
            [str(swift.resolve()), "--best", ",".join(map(str, history)),
             "--ms", str(budget_ms), "--tier", "zenith", "--trace"],
            capture_output=True, text=True, timeout=75, check=True,
        )
        response = json.loads(proc.stdout)
        move = response.get("move")
        if (response.get("schema") != "eclipse.zenith6x.teacher-decision.v1"
                or response.get("tier") != "zenith"
                or response.get("budget_ms") != budget_ms
                or type(move) is not int or not 0 <= move < 225 or board[move]):
            raise ValueError(f"teacher identity/legality mismatch: record {i}")
        side = 1 + len(history) % 2
        traces = response.get("trace")
        if not isinstance(traces, list):
            raise ValueError("missing real teacher search trace")
        last_depth = 0
        for tr in traces:
            if (tr.get("completed_depth", -1) < 0 or
                    tr["completed_depth"] < last_depth or
                    tr.get("nodes", -1) < 0):
                raise ValueError("invalid completed-depth telemetry")
            last_depth = tr["completed_depth"]
            pv = tr.get("pv", [])
            if not isinstance(pv, list):
                raise ValueError("PV not an array")
            validate_pv(board, side, pv)
        if response.get("completed_depth") != last_depth:
            raise ValueError("teacher depth mismatch")
        iterative_depth, forcing_proof_plies = classify_teacher_trace(traces)
        decision_kind = ("verified_forcing_four" if forcing_proof_plies
                         else "iterative_search" if iterative_depth
                         else "mandatory_rule_or_unsearched")
        candidate_roots = nearby(board, 2)
        if move not in candidate_roots:
            candidate_roots.append(move)
            candidate_roots.sort()
        record = {
            "schema": "eclipse.zenith6x.supervision.v1",
            "source": "public_synthetic_only",
            "origin_kind": kind,
            "family": d4_family(history),
            "seed": seed + i * 7919,
            "history": history,
            "to_move": side,
            "candidate_roots": candidate_roots,
            "teacher_move": move,
            "teacher_depth": iterative_depth,
            "teacher_proof_plies": forcing_proof_plies,
            "teacher_decision_kind": decision_kind,
            "teacher_nodes": response["nodes"],
            "teacher_elapsed_ms": response["elapsed_ms"],
            "teacher_trace": traces,
            "teacher_budget_ms": budget_ms,
            "teacher_profile": "HIGH/zenith",
            "teacher_engine": response["engine"],
        }
        records.append(record)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("".join(json.dumps(r, separators=(",", ":")) + "\n"
                           for r in records), encoding="utf-8")
    meta = {"schema": "eclipse.zenith6x.teacher-dataset-manifest.v1",
            "samples": len(records), "sources_sha256": sources,
            "dataset_sha256": hashlib.sha256(out.read_bytes()).hexdigest(),
            "public_synthetic_only": True, "no_private_learning": True,
            "teacher_zenith_budget_ms": budget_ms,
            "not_independently_proven_best_moves": True,
            "output": out.name}
    (out.parent / (out.stem + ".manifest.json")).write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return meta


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--swift", type=Path, required=True)
    ap.add_argument("--samples", type=int, default=48)
    ap.add_argument("--seed", type=int, default=20261122)
    ap.add_argument("--budget-ms", type=int, default=5700)
    ap.add_argument("--source-root", type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    print(json.dumps(
        collect(args.swift, args.samples, args.out, args.seed,
                args.budget_ms, args.source_root),
        ensure_ascii=False, indent=2,
    ))


if __name__ == "__main__":
    main()
