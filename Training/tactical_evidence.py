#!/usr/bin/env python3
"""Privacy-minimal, multiplicity-preserving audit of verified ECLIPSE JSONL games.

The audit DOES NOT deduplicate games, infer an opponent's strength, or train a
model. Ordered move sequences must not be canonicalized by final board state:
different orders may encode different tactics. No game moves are printed.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path

from validate_dataset import validate_record


def _key(rules: str, moves: list[int]) -> str:
    payload = json.dumps([rules, moves], separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(payload.encode("ascii")).hexdigest()


def audit(path: Path, prefix_plies: int = 8, top: int = 20) -> dict:
    if prefix_plies < 1 or top < 0:
        raise ValueError("prefix_plies must be positive and top must be nonnegative")
    path = Path(path)
    digest = hashlib.sha256()
    exact: Counter[str] = Counter()
    ordered_prefix: Counter[str] = Counter()
    winners: Counter[int] = Counter()
    total = 0
    with path.open("rb") as source:
        for line_number, raw in enumerate(source, 1):
            digest.update(raw)
            if not raw.strip():
                continue
            try:
                record = json.loads(raw.decode("utf-8"))
                validate_record(record)
                moves = record["moves"]
                rule = record["rules"]
            except (UnicodeDecodeError, json.JSONDecodeError, ValueError, TypeError, KeyError) as exc:
                raise ValueError(f"invalid game at line {line_number}: {exc}") from exc
            # Each occurrence is counted. Never remove exact repetitions.
            exact[_key(rule, moves)] += 1
            # Order-sensitive prefix: transpositions are NOT treated as equal.
            ordered_prefix[_key(rule, moves[:prefix_plies])] += 1
            winners[record["winner"]] += 1
            total += 1
    if not total:
        raise ValueError("empty dataset")

    def repeated(counter: Counter[str]) -> list[dict]:
        return [
            {"sha256": key, "occurrences": count}
            for key, count in sorted(counter.items(), key=lambda pair: (-pair[1], pair[0]))
            if count > 1
        ][:top]

    return {
        "schema": "eclipse.tactical-evidence.audit.v1",
        "rules": "freestyle-15",
        "source_sha256": digest.hexdigest(),
        "records_retained": total,
        "winner_counts": {str(k): winners[k] for k in sorted(winners)},
        "exact_ordered_sequences": len(exact),
        "extra_exact_occurrences": sum(count - 1 for count in exact.values()),
        "repeated_exact_groups": sum(count > 1 for count in exact.values()),
        "prefix_plies": prefix_plies,
        "ordered_prefix_groups": len(ordered_prefix),
        "repeated_prefix_groups": sum(count > 1 for count in ordered_prefix.values()),
        "repeated_exact_examples": repeated(exact),
        "repeated_prefix_examples": repeated(ordered_prefix),
        "policy": {
            "duplicates_removed": 0,
            "order_sensitive": True,
            "tactical_strength_verified": False,
            "training_performed": False,
            "notes": "Repetitions are candidate tactical evidence, not proven victories over another engine."
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", type=Path, required=True,
                        help="Explicitly selected, pre-normalized eclipse.selfplay.v1 JSONL")
    parser.add_argument("--prefix-plies", type=int, default=8)
    parser.add_argument("--top", type=int, default=20)
    parser.add_argument("--out", type=Path, help="Optional aggregate report; never raw moves")
    args = parser.parse_args()
    result = audit(args.dataset, args.prefix_plies, args.top)
    encoded = json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(encoded, encoding="utf-8")
        print(f"wrote aggregate audit for {result['records_retained']} records")
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
