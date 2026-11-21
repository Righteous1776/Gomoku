#!/usr/bin/env python3
"""Human-readable GitHub Actions scoreboard for synthetic full-game V9 arena."""
import json
import sys
from pathlib import Path

print("## Gomoku ECLIPSE 2.0 Astra / Sol — actual full-game arena")
for filename in sys.argv[1:]:
    path=Path(filename)
    records=[json.loads(line) for line in path.read_text().splitlines()]
    meta=next(x for x in records if x["type"]=="meta")
    games=[x for x in records if x["type"]=="game"]
    rows=[x for x in records if x["type"]=="summary"]
    assert len(rows)==3 and len(games)==meta["openings"]*6
    policy=meta["policy"]
    print(f"### {len(games)} games — {policy['max_wall_time_ms']}ms / "
          f"depth {policy['max_depth']} / {policy['max_nodes']} nodes")
    print(f"Four synthetic opening types, color-swapped within every pair; "
          f"same compute policy for Astra, Sol and historical R10.\n")
    print("| Candidate | Opponent | W | L | D | Total | Score |")
    print("|---|---|---:|---:|---:|---:|---:|")
    for x in rows:
        score=100*(x["wins"]+x["draws"]/2)/x["games"]
        print(f"| {x['model']} | {x['opponent']} | {x['wins']} | "
              f"{x['losses']} | {x['draws']} | {x['games']} | {score:.1f}% |")
    black=sum(x["winner_color"]==1 for x in games)
    white=sum(x["winner_color"]==2 for x in games)
    print(f"\nBlack first-move wins: {black}; white wins: {white}; "
          f"draws: {len(games)-black-white}.\n")
print("**Research-only exploratory evidence**: small, correlated openings; "
      "does not establish Elo, official playing rank, original Swift Tianyuan 6× "
      "non-inferiority or an attested production checkpoint.")
