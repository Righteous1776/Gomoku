#!/usr/bin/env python3
"""Validate *actual* original VeilLink Swift Zenith 6x vs R25 full-game logs."""
from __future__ import annotations
from pathlib import Path
import argparse
import json
from collections import Counter

from validate_r25_paired_arena import winner_after

OPENINGS = {
    "orthogonal_one":[112,97],
    "diagonal_one":[112,98],
    "orthogonal_two":[112,82],
    "diagonal_two":[112,84],
}
R25_SHA="bc9b1aabb6ae00de22e77943f5bd8c35ecff1b490e2ea74d5b10609b876f428d"
POLICY="1,5700,30000,7,18,30,20,6,3"


def replay(row: dict) -> None:
    assert row["schema"]=="eclipse.r26.r25-vs-original-zenith6x.v1"
    assert row["rules"]=="freestyle-15"
    assert {row["black"],row["white"]}=={"Zenith6x","R25"}
    assert row["cpp_policy"]==POLICY
    assert row["private_learning_disabled"] is True
    moves=row["moves"]
    assert moves[:len(OPENINGS[row["opening"]])]==OPENINGS[row["opening"]]
    assert len(moves)==row["plies"] and 2<=len(moves)<=225
    board=[0]*225
    terminal=0
    for ply,move in enumerate(moves):
        assert terminal==0 and type(move) is int and 0<=move<225 and board[move]==0
        side=1+ply%2
        board[move]=side
        if winner_after(board,move,side):
            terminal=side
    if not terminal and len(moves)==225:terminal=3
    assert terminal==row["winner_color"] and terminal in (1,2,3)
    assert row["winner"]==(
        "draw" if terminal==3 else row["black"] if terminal==1 else row["white"]
    )
    for field in ("total_search_elapsed_ms","total_process_elapsed_ms","total_nodes"):
        assert set(row[field])=={"R25","Zenith6x"}
        assert all(type(v) is int and v>=0 for v in row[field].values())


def validate(path: Path) -> dict:
    rows=[json.loads(line) for line in path.read_text().splitlines() if line.strip()]
    heads=[x for x in rows if x.get("type")=="meta"]
    games=[x for x in rows if x.get("type")=="game"]
    sums=[x for x in rows if x.get("type")=="summary"]
    assert len(heads)==len(sums)==1
    m=heads[0]
    assert m["student_checkpoint_sha256"]==R25_SHA
    assert m["source"]=="public_synthetic_only"
    assert m["paired_color_swaps"] is True
    assert m["same_max_wall_time_ms"]==5700
    assert m["max_depth"]==7 and m["max_nodes"]==30000
    assert m["same_search_algorithm"] is False
    assert m["certified_elo"] is False and m["real_complete_games"] is True
    assert len(games)==m["games"] and len(games)%2==0
    counts=Counter()
    for g in games:
        replay(g)
        counts[(g["opening"],g["black"])]+=1
    for opening in set(g["opening"] for g in games):
        assert counts[(opening,"R25")]==counts[(opening,"Zenith6x")]==1
    s=sums[0]
    w=sum(g["winner"]=="R25" for g in games)
    l=sum(g["winner"]=="Zenith6x" for g in games)
    d=sum(g["winner"]=="draw" for g in games)
    assert (s["r25_wins"],s["zenith_wins"],s["draws"],s["games"])==(w,l,d,len(games))
    assert abs(s["r25_score_fraction"]-(w+0.5*d)/len(games))<1e-9
    return {"games":len(games),"r25_wins":w,"zenith_wins":l,"draws":d,
            "r25_score_fraction":(w+0.5*d)/len(games),
            "certified_elo":False,"source":"independent move replay"}


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("jsonl",type=Path)
    print(json.dumps(validate(p.parse_args().jsonl),indent=2))
