#!/usr/bin/env python3
"""Independent full-game verification of generated LOCAL research matches.
NOT a check that repository Swift or R15 C++ was executed.
"""
from pathlib import Path
import json,hashlib,math,statistics
ROOT=Path(__file__).resolve().parent
F={
 'astra_v9_vs_v8':'results/astra_120ms_8games_complete.jsonl',
 'sol_v9_vs_v8':'results/sol_120ms_8games_complete.jsonl',
 'astra_v9_vs_sol_v9':'results/v9_astra_vs_v9_sol_120ms_8games_complete.jsonl'
}

def winner_after(b,k,s):
 r,c=divmod(k,15)
 for dr,dc in [(1,0),(0,1),(1,1),(1,-1)]:
  ct=1
  for direction in [-1,1]:
   rr,cc=r+dr*direction,c+dc*direction
   while 0<=rr<15 and 0<=cc<15 and b[rr*15+cc]==s:
    ct+=1;rr+=dr*direction;cc+=dc*direction
  if ct>=5:return s
 return 0

def wilson(x,n,z=1.959963984540054):
 p=x/n;t=1+z*z/n
 center=(p+z*z/(2*n))/t
 radius=z*math.sqrt((p*(1-p)+z*z/(4*n))/n)/t
 return [round(center-radius,4),round(center+radius,4)]

report={'schema':'eclipse.local-research-arena.v1','scope':'LOCALLY CONSTRUCTED search core; NOT Original Swift, NOT official R15 C++','rules':'freestyle-15','groups':{},'production_strength_parity_verified':False,'real_swift_zenith_6x_matches':0}
for label,path in F.items():
 file=ROOT/path;data=[json.loads(x) for x in file.read_text().splitlines()]
 assert data[0]['type']=='config' and data[-1]['type']=='summary'
 conf=data[0];games=[x for x in data if x['type']=='game'];su=data[-1]
 assert len(games)==su['games']==8 and len(data)==10 and conf['budget_ms']==120
 pairs={};p_stats={};wins={'A':0,'B':0,'draw':0}
 for game in games:
  seq=game['moves'];b=[0]*225;won=0
  assert seq[:2]==game['opening'] and len(seq)==game['plies']
  assert len(seq)==len(set(seq)) and all(type(k)==int and 0<=k<225 for k in seq)
  for ply,k in enumerate(seq):
   s=1+ply%2;assert not won
   b[k]=s;won=winner_after(b,k,s)
  expected='draw' if not won else ('A' if (won==1)==game['A_black'] else 'B')
  assert expected==game['winner'],(label,game['pair'],game['winner'],expected)
  assert won or len(seq)==225
  pairs.setdefault(game['pair'],[]).append(game)
  wins[expected]+=1
 for p,gg in pairs.items():
  assert len(gg)==2 and gg[0]['A_black']!=gg[1]['A_black'] and gg[0]['opening']==gg[1]['opening']
  p_stats[p]=[x['winner'] for x in gg]
 assert wins['A']==su['A_wins'] and wins['B']==su['B_wins'] and wins['draw']==su['draws']
 n=len(games)
 group={'models':{'A':conf['A'],'B':conf['B']},'budget_cap_ms_per_move':120,'engine':'LOCAL research C++ shared search; actual 26D LightGBM weights','paired_openings':len(pairs),'games':n,'A_wins':wins['A'],'B_wins':wins['B'],'draws':wins['draw'],'A_match_points':wins['A']+wins['draw']*.5,'A_score_fraction':(wins['A']+wins['draw']*.5)/n,'wilson_95_interval_on_A_win_fraction_excluding_draws':wilson(wins['A'],n),'moves_sum':sum(len(g['moves']) for g in games),'actual_search_ms_A_total':sum(g['ms_A'] for g in games),'actual_search_ms_B_total':sum(g['ms_B'] for g in games),'nodes_A_total':sum(g['nodes_A'] for g in games),'nodes_B_total':sum(g['nodes_B'] for g in games),'timeouts_A_total':sum(g['timeouts_A'] for g in games),'timeouts_B_total':sum(g['timeouts_B'] for g in games),'all_games_legal_and_terminal_verified':True,'pair_results':p_stats,'raw_jsonl_sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
 report['groups'][label]=group
out=ROOT/'benchmark-audit.json';out.write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
for label,x in report['groups'].items(): print(label,x['A_wins'],x['B_wins'],x['draws'],'CI=',x['wilson_95_interval_on_A_win_fraction_excluding_draws'],'nodes=',x['nodes_A_total'],x['nodes_B_total'],'timeouts=',x['timeouts_A_total'],x['timeouts_B_total'])
print('OUTPUT',out)
