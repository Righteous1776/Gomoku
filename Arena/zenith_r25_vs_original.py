#!/usr/bin/env python3
"""Real original Swift Tianyuan 6x vs R25-273 C++ PVS, color-swapped full games.

This is an exploratory cross-engine match, NOT proof of strength parity:
- Swift is actual frozen VeilLink GomokuBot HIGH/zenith with empty private learning;
- R25 is actual SHA-pinned LightGBM 273-tree C++ V2 PVS + VCF scorer;
- both receive the same 5700ms / 30000-node / depth-7 headline ceilings,
  but original Swift preflight and C++ internals are NOT algorithmically equal.
- independent freestyle replay, no owner training positions or private histories.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

OPENINGS = [
    ("orthogonal_one", [112, 97]),
    ("diagonal_one", [112, 98]),
    ("orthogonal_two", [112, 82]),
    ("diagonal_two", [112, 84]),
]
R25_SHA = "bc9b1aabb6ae00de22e77943f5bd8c35ecff1b490e2ea74d5b10609b876f428d"
ZENITH_MS = 5700
CPP_POLICY = "1,5700,30000,7,18,30,20,6,3"


def winner(board, move: int, side: int) -> bool:
    r, c = divmod(move, 15)
    for dr, dc in ((0,1),(1,0),(1,1),(1,-1)):
        consecutive = 1
        for sign in (-1,1):
            rr, cc = r + sign * dr, c + sign * dc
            while 0 <= rr < 15 and 0 <= cc < 15 and board[rr*15+cc] == side:
                consecutive += 1
                rr += sign * dr
                cc += sign * dc
        if consecutive >= 5:
            return True
    return False


def run_cmd(args: list[str]) -> tuple[dict, int]:
    started = time.perf_counter()
    proc = subprocess.run(args, capture_output=True, text=True, timeout=30)
    elapsed = round((time.perf_counter()-started)*1000)
    if proc.returncode:
        raise RuntimeError(f"engine {args[0]} exit={proc.returncode}: {proc.stderr[-800:]}")
    return json.loads(proc.stdout), elapsed


def choose(swift: Path, cpp: Path, weights: Path,
           history: list[int], is_student: bool) -> tuple[dict,int]:
    history_str = ",".join(map(str,history))
    if is_student:
        record, subprocess_ms = run_cmd([
            str(cpp.resolve()), "--best", history_str,
            "--policy-v2", CPP_POLICY,
            "--r25-weights", str(weights.resolve()),
        ])
        assert record.get("research_ranker") == "r25-zenith-student"
        assert record.get("model_sha256") == R25_SHA
        p = record["applied_compute_policy"]
        assert (p["max_wall_time_ms"],p["max_nodes"],p["max_depth"],
                p["root_width"],p["reply_width"],p["continuation_width"],
                p["forced_line_depth"],p["candidate_radius"]) == (
                    5700,30000,7,18,30,20,6,3)
    else:
        record, subprocess_ms = run_cmd([
            str(swift.resolve()), "--best", history_str,
            "--ms", str(ZENITH_MS), "--tier", "zenith",
        ])
        assert record.get("tier") == "zenith"
        assert record.get("budget_ms") == ZENITH_MS
        assert record.get("engine") == "Original native Swift GomokuBot (empty personal learning)"
    return record, subprocess_ms


def game(swift: Path, cpp: Path, weights: Path, opening: tuple[str,list[int]],
         r25_black: bool) -> dict:
    name, opening_moves = opening
    moves = opening_moves.copy()
    board = [0] * 225
    for ply, move in enumerate(moves):
        assert board[move] == 0
        side = 1 + ply % 2
        board[move] = side
        assert not winner(board,move,side), "invalid terminal opening"
    total_search_ms = {"R25":0,"Zenith6x":0}
    total_process_ms = {"R25":0,"Zenith6x":0}
    total_nodes = {"R25":0,"Zenith6x":0}
    terminal = 0
    while len(moves) < 225:
        side=1+len(moves)%2
        is_student=(side==1)==r25_black
        model="R25" if is_student else "Zenith6x"
        decision, proc_ms = choose(swift,cpp,weights,moves,is_student)
        move=decision.get("move")
        if type(move) is not int or not 0 <= move < 225 or board[move]:
            raise RuntimeError(f"{model} illegal move at ply {len(moves)}: {move}")
        board[move]=side
        moves.append(move)
        total_search_ms[model]+=decision.get("elapsed_ms",0)
        total_process_ms[model]+=proc_ms
        total_nodes[model]+=decision.get("nodes",0)
        if winner(board,move,side):
            terminal=side
            break
    if not terminal:terminal=3
    black="R25" if r25_black else "Zenith6x"
    white="Zenith6x" if r25_black else "R25"
    win_name="draw" if terminal==3 else black if terminal==1 else white
    return {
        "type":"game","schema":"eclipse.r26.r25-vs-original-zenith6x.v1",
        "rules":"freestyle-15","opening":name,"black":black,"white":white,
        "winner":win_name,"winner_color":terminal,
        "plies":len(moves),"moves":moves,
        "total_search_elapsed_ms":total_search_ms,
        "total_process_elapsed_ms":total_process_ms,
        "total_nodes":total_nodes,
        "source":"original_compiled_swift_vs_shapinned_native_cpp",
        "private_learning_disabled":True,
        "zenith_policy":"HIGH/zenith/5700ms/30000nodes/7depth/18width/6forcing",
        "cpp_policy":CPP_POLICY,
    }


def arena(swift: Path, cpp: Path, weights: Path, pairs: int,
          source_root: Path) -> list[dict]:
    assert 1 <= pairs <= len(OPENINGS)
    assert all(x.is_file() for x in (swift,cpp,weights))
    assert hashlib.sha256(weights.read_bytes()).hexdigest()==R25_SHA
    teacher_path=source_root/"Legacy/Original/VeilLink/Agent/Games/GomokuBot.swift"
    teacher_sha=hashlib.sha256(teacher_path.read_bytes()).hexdigest()
    header={
        "type":"meta","schema":"eclipse.r26.r25-vs-original-zenith6x.v1",
        "teacher":"Original VeilLink GomokuBot HIGH/zenith, not reimplementation",
        "teacher_source_sha256":teacher_sha,"student_checkpoint_sha256":R25_SHA,
        "games":2*pairs,"paired_color_swaps":True,
        "same_max_wall_time_ms":ZENITH_MS,"max_depth":7,
        "max_nodes":30000,"real_complete_games":True,
        "same_search_algorithm":False,"certified_elo":False,
        "source":"public_synthetic_only",
    }
    print(json.dumps(header,separators=(",",":")),flush=True)
    results=[]
    for opening in OPENINGS[:pairs]:
        for r25_black in (True,False):
            row=game(swift,cpp,weights,opening,r25_black)
            results.append(row)
            print(json.dumps(row,separators=(",",":")),flush=True)
    win=sum(x["winner"]=="R25" for x in results)
    loss=sum(x["winner"]=="Zenith6x" for x in results)
    draw=sum(x["winner"]=="draw" for x in results)
    summary={
        "type":"summary","schema":header["schema"],"r25_wins":win,
        "zenith_wins":loss,"draws":draw,"games":len(results),
        "r25_score_fraction":(win+0.5*draw)/len(results),
        "qualification":"exploratory matched budget; different search algorithms; not certified Elo or parity",
    }
    print(json.dumps(summary,separators=(",",":")),flush=True)
    return results


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--swift",type=Path,required=True)
    p.add_argument("--cpp",type=Path,required=True)
    p.add_argument("--weights",type=Path,required=True)
    p.add_argument("--source-root",type=Path,default=Path("."))
    p.add_argument("--pairs",type=int,default=1)
    args=p.parse_args()
    arena(args.swift,args.cpp,args.weights,args.pairs,args.source_root)
