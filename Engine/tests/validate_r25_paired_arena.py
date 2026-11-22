#!/usr/bin/env python3
"""Independently replay and validate R25-vs-R07 same-engine full games."""
from __future__ import annotations
import argparse
from collections import Counter
import json
from pathlib import Path

OPENINGS = {
    "orthogonal_one": [112, 97],
    "diagonal_one": [112, 98],
    "orthogonal_two": [112, 82],
    "diagonal_two": [112, 84],
    "cross_four": [112, 97, 111, 98],
    "diagonal_four": [112, 98, 127, 113],
}
R07_SHA = "d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234"
R25_SHA = "bc9b1aabb6ae00de22e77943f5bd8c35ecff1b490e2ea74d5b10609b876f428d"


def winner_after(board: list[int], move: int, side: int) -> bool:
    row, col = divmod(move, 15)
    for dr, dc in ((0, 1), (1, 0), (1, 1), (1, -1)):
        count = 1
        for sign in (-1, 1):
            r, c = row + sign * dr, col + sign * dc
            while 0 <= r < 15 and 0 <= c < 15 and board[r * 15 + c] == side:
                count += 1
                r += sign * dr
                c += sign * dc
        if count >= 5:
            return True
    return False


def replay(game: dict):
    moves = game["moves"]
    opening = OPENINGS[game["opening"]]
    assert moves[:len(opening)] == opening, "opening not preserved"
    assert 2 <= len(moves) <= 225
    board = [0] * 225
    terminal = 0
    for ply, move in enumerate(moves):
        assert terminal == 0, "game kept going after a win"
        assert type(move) is int and 0 <= move < 225 and board[move] == 0, "illegal move"
        side = 1 + ply % 2
        board[move] = side
        if winner_after(board, move, side):
            terminal = side
    if not terminal and len(moves) == 225:
        terminal = 3
    assert terminal in (1, 2, 3), "game not completed"
    assert game["winner_color"] == terminal
    assert game["winner"] == (
        game["black"] if terminal == 1 else
        game["white"] if terminal == 2 else "draw"
    )
    assert game["plies"] == len(moves)
    assert game["search_calls"] == len(moves) - len(opening)
    assert game["total_search_elapsed_ms"] >= 0
    assert game["total_nodes"] >= 0
    assert game["forced_tactical_moves"] <= game["search_calls"]
    assert game["time_limit_responses"] <= game["search_calls"]
    p = game["policy"]
    assert 10 <= p["ms"] <= 5700 and 2 <= p["depth"] <= 7
    assert 100 <= p["nodes"] <= 30000
    assert (p["root_width"],p["reply_width"],p["continuation_width"],
            p["forced_line_depth"],p["candidate_radius"]) == (18,30,20,6,3)


def validate(path: Path) -> dict:
    records = [json.loads(x) for x in path.read_text().splitlines() if x.strip()]
    meta = [r for r in records if r.get("type") == "meta"]
    games = [r for r in records if r.get("type") == "game"]
    summaries = [r for r in records if r.get("type") == "summary"]
    assert len(meta) == len(summaries) == 1
    m = meta[0]
    assert m["schema"] == "eclipse.r26.same-engine-paired.v1"
    assert m["model_r07_sha256"] == R07_SHA and m["model_r25_sha256"] == R25_SHA
    assert m["source"] == "public_synthetic"
    assert m["paired_color_swaps"] is True and m["same_cpp_pvs_vcf_engine"] is True
    assert m["certified_elo"] is False and m["real_full_games"] is True
    assert len(games) == m["games"] and len(games) % 2 == 0
    counts = Counter()
    for game in games:
        assert game["schema"] == m["schema"] and game["rules"] == "freestyle-15"
        assert {game["black"],game["white"]} == {"R07","R25"}
        replay(game)
        counts[(game["opening"],game["black"])] += 1
    for opening in {g["opening"] for g in games}:
        assert counts[(opening,"R07")] == counts[(opening,"R25")] == 1
    a = summaries[0]
    assert a["model"] == "R25" and a["opponent"] == "R07"
    w = sum(g["winner"] == "R25" for g in games)
    l = sum(g["winner"] == "R07" for g in games)
    d = sum(g["winner"] == "draw" for g in games)
    assert (a["wins"],a["losses"],a["draws"],a["games"]) == (w,l,d,len(games))
    assert abs(a["score_fraction"]-(w+0.5*d)/len(games)) < 1e-5
    result = {"games":len(games),"wins":w,"losses":l,"draws":d,
              "score_fraction":(w+0.5*d)/len(games),
              "openings":len(games)//2,"certified_elo":False}
    print(json.dumps(result,indent=2))
    return result


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("jsonl",type=Path)
    validate(p.parse_args().jsonl)
