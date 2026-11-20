"""Validate the append-only ECLIPSE JSONL self-play interchange format.
No third-party dependencies; validates legality and terminal winner for freestyle-15.
"""
import argparse
import json
from pathlib import Path

DIRECTIONS = ((1, 0), (0, 1), (1, 1), (1, -1))


def winner_after(board, move, player):
    r, c = divmod(move, 15)
    for dr, dc in DIRECTIONS:
        n = 1
        for sign in (-1, 1):
            rr, cc = r + sign * dr, c + sign * dc
            while 0 <= rr < 15 and 0 <= cc < 15 and board[rr * 15 + cc] == player:
                n += 1
                rr += sign * dr
                cc += sign * dc
        if n >= 5:
            return player
    return 0


def replay(moves):
    if not isinstance(moves, list) or not moves or len(moves) > 225:
        raise ValueError("nonempty move list of at most 225 elements required")
    board = [0] * 225
    winner = 0
    for turn, move in enumerate(moves):
        if type(move) is not int or not 0 <= move < 225:
            raise ValueError(f"illegal index at ply {turn}: {move}")
        if board[move] or winner:
            raise ValueError(f"occupied square or play after terminal at ply {turn}")
        player = 1 + turn % 2
        board[move] = player
        winner = winner_after(board, move, player)
    if not winner and len(moves) == 225:
        winner = 3
    if not winner:
        raise ValueError("record is not a completed game")
    return winner


def validate_record(rec):
    if not isinstance(rec, dict) or rec.get("schema") != "eclipse.selfplay.v1":
        raise ValueError("wrong schema")
    if rec.get("rules") != "freestyle-15":
        raise ValueError("wrong rules")
    result = replay(rec.get("moves"))
    if result != rec.get("winner"):
        raise ValueError(f"winner mismatch: actual {result}, declared {rec.get('winner')}")
    return result


def validate_file(path):
    n = 0
    with Path(path).open(encoding="utf-8") as f:
        for lineno, line in enumerate(f, 1):
            if not line.strip():
                continue
            try:
                validate_record(json.loads(line))
            except (ValueError, json.JSONDecodeError) as exc:
                raise ValueError(f"{path}:{lineno}: {exc}") from exc
            n += 1
    if not n:
        raise ValueError("empty dataset")
    return n


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", type=Path, required=True)
    args = parser.parse_args()
    print(f"validated {validate_file(args.path)} complete games")
