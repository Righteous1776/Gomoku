"""Paired-opening benchmark for CLI engines. Does NOT claim ELO equivalence.
Each engine must provide --best comma-index-history --ms N -> JSON {move:...}.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Training"))
from validate_dataset import winner_after


def choose(exe: Path, moves: list[int], ms: int) -> int:
    result = subprocess.run([str(exe.resolve()), "--best", ",".join(map(str,moves)), "--ms", str(ms)], capture_output=True, text=True, check=True, timeout=30)
    return json.loads(result.stdout)["move"]


def game(a: Path, b: Path, a_black: bool, ms: int, opening: int) -> int:
    board = [0] * 225
    moves = [opening]
    board[opening] = 1
    while len(moves) < 225:
        player = 1 + len(moves) % 2
        exe = a if (player == 1) == a_black else b
        mv = choose(exe, moves, ms)
        if type(mv) is not int or not 0 <= mv < 225 or board[mv]:
            raise RuntimeError(f"illegal engine output {exe}: {mv}")
        board[mv] = player; moves.append(mv)
        won = winner_after(board, mv, player)
        if won:
            return 1 if (won == 1) == a_black else 2
    return 3


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--a', type=Path, required=True)
    p.add_argument('--b', type=Path, required=True)
    p.add_argument('--pairs', type=int, default=1)
    p.add_argument('--ms', type=int, default=20)
    o = p.parse_args()
    if o.pairs < 1 or o.ms < 1:
        raise SystemExit('positive pairs/ms required')
    counts = Counter()
    openings = [112, 111, 97, 127]
    for pair in range(o.pairs):
        opening = openings[pair % len(openings)]
        for a_black in (True, False):
            outcome = game(o.a, o.b, a_black, o.ms, opening)
            counts[{1:'A', 2:'B', 3:'draw'}[outcome]] += 1
    total = 2 * o.pairs
    result = {'games': total, 'A_wins': counts['A'], 'B_wins': counts['B'], 'draws': counts['draw'], 'A_score': (counts['A']+0.5*counts['draw'])/total, 'rules': 'freestyle-15', 'qualification': 'paired side-swap benchmark; not a calibrated rank'}
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
