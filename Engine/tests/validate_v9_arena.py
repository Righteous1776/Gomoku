#!/usr/bin/env python3
"""Independent freestyle board replay of real Astra/Sol/R10 C++ V2 full games."""
import argparse
import collections
import json
from pathlib import Path

OPENINGS = {
    "orthogonal_one": [112,97],
    "diagonal_one": [112,98],
    "orthogonal_two": [112,82],
    "diagonal_two": [112,84],
    "cross_four": [112,97,111,98],
    "diagonal_four": [112,98,127,113],
}
PAIRS = [("Astra","Sol"),("Astra","R10"),("Sol","R10")]

def check_win(board, move, player):
    row, col = divmod(move,15)
    for dr, dc in ((0,1),(1,0),(1,1),(1,-1)):
        streak = 1
        for step in (-1,1):
            r, c = row+dr*step, col+dc*step
            while 0 <= r < 15 and 0 <= c < 15 and board[15*r+c]==player:
                streak += 1
                r += dr*step
                c += dc*step
        if streak >= 5:
            return True
    return False

def replay(game):
    history = game["moves"]
    assert isinstance(history,list) and 2 <= len(history) <= 225
    assert history[:len(OPENINGS[game["opening"]])] == OPENINGS[game["opening"]],game
    board = [0]*225
    terminal = 0
    for ply, move in enumerate(history):
        assert terminal==0 and type(move) is int and 0 <= move < 225,game
        assert board[move]==0,game
        side=1+(ply%2)
        board[move]=side
        if check_win(board,move,side):
            terminal=side
    if terminal==0 and len(history)==225:terminal=3
    assert terminal in (1,2,3),game
    assert game["winner_color"]==terminal,game
    assert game["winner"] == (
        game["black"] if terminal==1 else game["white"] if terminal==2 else "draw"),game
    assert game["plies"]==len(history),game
    assert game["searched_moves"]==len(history)-len(OPENINGS[game["opening"]]),game
    assert game["budget_ms_per_move"]>0 and game["total_nodes"]>=0
    assert game["total_search_elapsed_ms"]>=0
    return terminal

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("jsonl",type=Path)
    args=parser.parse_args()
    records=[json.loads(s) for s in args.jsonl.read_text().splitlines() if s.strip()]
    meta=[r for r in records if r.get("type")=="meta"]
    games=[r for r in records if r.get("type")=="game"]
    sums=[r for r in records if r.get("type")=="summary"]
    assert len(meta)==1 and len(sums)==3, (len(meta),len(sums))
    info=meta[0]
    assert info["source"]=="public_synthetic" and info["generation"]=="V9"
    assert info["production_checkpoint_attested"] is False
    assert info["paired_color_swaps"] is True and info["real_full_games"] is True
    assert info["policy"]["max_nodes"]==18000
    assert len(games)==len(PAIRS)*2*info["openings"],(len(games),info["openings"])
    seen=collections.Counter()
    for game in games:
        replay(game)
        assert game["generation"]=="V9" and game["rules"]=="freestyle-15"
        assert game["black"]!=game["white"]
        pair=next((p for p in PAIRS if {game["black"],game["white"]}==set(p)),None)
        assert pair is not None,game
        seen[(pair,game["opening"],game["black"])]+=1
        assert game["budget_ms_per_move"]==info["policy"]["max_wall_time_ms"]
    for pair in PAIRS:
        pair_games=[g for g in games if {g["black"],g["white"]}==set(pair)]
        assert len(pair_games)==2*info["openings"]
        assert sum(g["black"]==pair[0] for g in pair_games)==info["openings"]
        assert sum(g["black"]==pair[1] for g in pair_games)==info["openings"]
        for name in list(OPENINGS)[:info["openings"]]:
            assert seen[(pair,name,pair[0])]==1
            assert seen[(pair,name,pair[1])]==1
        summary=next(s for s in sums if s["model"]==pair[0] and s["opponent"]==pair[1])
        wins=sum(g["winner"]==pair[0] for g in pair_games)
        losses=sum(g["winner"]==pair[1] for g in pair_games)
        draws=sum(g["winner"]=="draw" for g in pair_games)
        assert (summary["wins"],summary["losses"],summary["draws"],summary["games"])==(
            wins,losses,draws,len(pair_games)),summary
        assert summary["searched_moves"]==sum(g["searched_moves"] for g in pair_games)
        assert summary["total_nodes"]==sum(g["total_nodes"] for g in pair_games)
        assert summary["total_search_elapsed_ms"]==sum(
            g["total_search_elapsed_ms"] for g in pair_games)
        print(f"VALIDATED {pair[0]} vs {pair[1]}: W {wins} / L {losses} / D {draws}, "
              f"n={len(pair_games)}, paired-color openings={info['openings']}")
    print(f"VALIDATED all {len(games)} actual complete synthetic C++ V2 games. "
          "No Swift 6x non-inferiority or Elo certification implied.")

if __name__=="__main__":
    main()
