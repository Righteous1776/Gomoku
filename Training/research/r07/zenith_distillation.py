#!/usr/bin/env python3
"""Conservative LightGBM R07 student training from real Zenith 6x decisions.

No human/owner training records. Uses real original Swift teacher top-1 moves
and completed-depth telemetry, NEVER pretending a teacher choice is proven
optimal. The student learns an ordering prior, not the search algorithm itself.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent / "source"))
from zenith_features import features34
sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "Arena"))
from zenith_teacher_dataset import replay

BASE_SHA = "d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234"
BASE_MODEL = Path(__file__).resolve().parent / "checkpoints" / "eclipse_r07_34d_249_trees.txt"


def check_records(path: Path):
    records = []
    seen = set()
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        row = json.loads(line)
        if (row.get("schema") != "eclipse.zenith6x.supervision.v1"
                or row.get("source") != "public_synthetic_only"
                or row.get("teacher_profile") != "HIGH/zenith"
                or row.get("teacher_budget_ms") != 5700
                or row.get("to_move") not in (1, 2)):
            raise ValueError(f"unverified teacher provenance at line {lineno}")
        history = row["history"]
        board = replay(history)
        move = row["teacher_move"]
        roots = row["candidate_roots"]
        if (not isinstance(roots, list) or len(roots) < 2
                or len(roots) != len(set(roots))
                or type(move) is not int or move not in roots):
            raise ValueError(f"illegal teacher candidate at line {lineno}")
        if any(type(v) is not int or not 0 <= v < 225 or board[v] for v in roots):
            raise ValueError(f"occupied / invalid candidate at line {lineno}")
        if row["to_move"] != 1 + len(history) % 2:
            raise ValueError(f"teacher side mismatch at line {lineno}")
        key = tuple(history)
        if key in seen:
            raise ValueError(f"duplicate teacher position at line {lineno}")
        seen.add(key)
        if not isinstance(row["family"], str) or len(row["family"]) != 24:
            raise ValueError("missing D4 opening-family group")
        if row["teacher_depth"] < 0 or row["teacher_nodes"] < 0:
            raise ValueError("invalid teacher work telemetry")
        records.append((row, board))
    if not records:
        raise ValueError("empty teacher dataset")
    return records


def split_family(family: str) -> str:
    # Group-level, deterministic separation; opening families never span splits.
    return "validation" if int(hashlib.sha256(family.encode()).hexdigest()[:8], 16) % 5 == 0 else "train"


def make_groups(records, *, min_depth: int = 1):
    by_split = {"train": [], "validation": []}
    family_split = {}
    excluded = 0
    for row, board in records:
        family = row["family"]
        split = split_family(family)
        if family in family_split and family_split[family] != split:
            raise AssertionError("D4 family leaked")
        family_split[family] = split
        # Mandatory-rule answers (depth 0) remain audited, but are never
        # treated as equivalent to deeper teacher search labels.
        if row["teacher_depth"] < min_depth:
            excluded += 1
            continue
        moves = row["candidate_roots"]
        side = row["to_move"]
        matrix = np.stack([features34(board, move, side) for move in moves])
        labels = np.asarray([3 if move == row["teacher_move"] else 0
                             for move in moves], dtype=np.int32)
        by_split[split].append((row, matrix, labels))
    return by_split, excluded, family_split


def pack(groups):
    if not groups:
        raise ValueError("empty training/validation groups")
    return (np.concatenate([a[1] for a in groups]),
            np.concatenate([a[2] for a in groups]),
            [len(a[2]) for a in groups])


def agreement(model, groups, *, num_threads: int = 2):
    x, _, _ = pack(groups)
    pred = model.predict(x, num_threads=num_threads)
    pos = 0
    correct = top3 = 0
    for row, _, _ in groups:
        length = len(row["candidate_roots"])
        scores = pred[pos:pos + length]
        moves = row["candidate_roots"]
        ranked = sorted(range(length), key=lambda j: (-float(scores[j]), moves[j]))
        correct += int(moves[ranked[0]] == row["teacher_move"])
        top3 += int(row["teacher_move"] in {moves[j] for j in ranked[:3]})
        pos += length
    return {"groups": len(groups), "top1": correct, "top3": top3,
            "top1_rate": round(correct / len(groups), 6),
            "top3_rate": round(top3 / len(groups), 6)}


def train(dataset: Path, output_dir: Path, *, rounds: int = 24,
          min_train: int = 18, min_val: int = 5) -> dict:
    import lightgbm as lgb

    raw = BASE_MODEL.read_bytes()
    if hashlib.sha256(raw).hexdigest() != BASE_SHA:
        raise RuntimeError("exact R07-249 baseline SHA-256 mismatch")
    baseline = lgb.Booster(model_file=str(BASE_MODEL))
    if baseline.num_trees() != 249 or baseline.num_feature() != 34:
        raise RuntimeError("incorrect R07 base model structure")
    records = check_records(dataset)
    samples, excluded, family_splits = make_groups(records)
    if len(samples["train"]) < min_train or len(samples["validation"]) < min_val:
        raise RuntimeError(f"insufficient independent search labels: "
                           f"train={len(samples['train'])}, val={len(samples['validation'])}; "
                           f"excluded_depth0={excluded}")

    x, y, groups = pack(samples["train"])
    before_train = agreement(baseline, samples["train"])
    before_val = agreement(baseline, samples["validation"])
    params = {
        "objective": "lambdarank", "metric": "ndcg",
        "ndcg_eval_at": [1, 3],
        "learning_rate": 0.02, "num_leaves": 11,
        "min_data_in_leaf": 20, "feature_fraction": 1.0,
        "lambdarank_truncation_level": 15,
        "seed": 20261122, "deterministic": True,
        "force_col_wise": True, "verbosity": -1, "num_threads": 2,
    }
    data = lgb.Dataset(x, label=y, group=groups, free_raw_data=False)
    student = lgb.train(params, data, num_boost_round=rounds, init_model=str(BASE_MODEL))
    if student.num_trees() != 249 + rounds or student.num_feature() != 34:
        raise RuntimeError("bad student model structure")
    after_train = agreement(student, samples["train"])
    after_val = agreement(student, samples["validation"])

    output_dir.mkdir(parents=True, exist_ok=True)
    path = output_dir / f"eclipse_r07_zenith_teacher_{249 + rounds}_trees.txt"
    student.save_model(str(path))
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    check = lgb.Booster(model_file=str(path))
    if check.num_trees() != student.num_trees():
        raise RuntimeError("student weight reload failed")
    report = {
        "schema": "eclipse.zenith6x.r07-distillation-candidate.v1",
        "teacher": "real-original-Swift-Zenith-6x-HIGH-empty-private-learning",
        "student": "R07 34D + LightGBM LambdaRank residual teacher imitation",
        "source": "public_synthetic_only",
        "base_checkpoint_sha256": BASE_SHA,
        "teacher_dataset_sha256": hashlib.sha256(dataset.read_bytes()).hexdigest(),
        "student_checkpoint_sha256": sha,
        "new_trees": rounds, "total_trees": student.num_trees(),
        "feature_dims": student.num_feature(),
        "input_positions": len(records),
        "excluded_mandatory_rule_or_zero_depth": excluded,
        "train_groups": len(samples["train"]),
        "validation_groups": len(samples["validation"]),
        "independent_d4_families": len(family_splits),
        "prior_teacher_agreement_train": before_train,
        "student_teacher_agreement_train": after_train,
        "prior_teacher_agreement_validation": before_val,
        "student_teacher_agreement_validation": after_val,
        "heldout_top1_did_not_regress": after_val["top1"] >= before_val["top1"],
        "promotion_authorized": False,
        "certified_zenith_6x_strength_parity": False,
        "trained_search_budget_allocator": False,
        "limitations": [
            "This learns static candidate ranking only; mandatory rules and PVS/VCF must still run in an actual engine.",
            "Synthetic local trajectories are not independent human or expert games.",
            "Teacher is a bounded heuristic search, not a verified optimal-move oracle.",
            "Teacher trace and source SHA must be preserved; exact strength requires paired games and tactical gates.",
            "Source checkpoint already derives from the owner's earlier research and is not a blind fresh-data baseline.",
        ],
    }
    (output_dir / "zenith_distillation_report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return report


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--dataset", type=Path, required=True)
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--rounds", type=int, default=24)
    p.add_argument("--min-train", type=int, default=18)
    p.add_argument("--min-val", type=int, default=5)
    args = p.parse_args()
    if not 1 <= args.rounds <= 80:
        p.error("rounds must be 1..80")
    print(json.dumps(
        train(args.dataset, args.out_dir, rounds=args.rounds,
              min_train=args.min_train, min_val=args.min_val),
        ensure_ascii=False, indent=2,
    ))


if __name__ == "__main__":
    main()
