#!/usr/bin/env python3
"""Equal-information mirrored-opening, rules-gated policy ranker research arena.
This is NOT the deployed V9/R19 native search engine and offers no Elo claim.

Public source snapshot. It requires the original R04/R06 research feature
dependencies and locally held 34D checkpoints; GitHub includes NO private
training weights or owner/friend raw match histories.
"""
import argparse,hashlib,json,random,sys,time,statistics
from pathlib import Path
import numpy as np
import lightgbm as lgb
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parent/'ECLIPSE_Training_R04/base'))
sys.path.insert(0,str(ROOT.parent/'ECLIPSE_Training_R06'))
from features34 import features34 as features
from train_eclipse_r02 import immediate_wins

DIRECTIONS=((1,0),(0,1),(1,1),(1,-1))

def haswin_after(b,ix,side):
 r,c=divmod(ix,15)
 for dr,dc in DIRECTIONS:
  n=1
  for sign in (-1,1):
   rr=r+sign*dr;cc=c+sign*dc
   while 0<=rr<15 and 0<=cc<15 and b[15*rr+cc]==side:
    n+=1;rr+=sign*dr;cc+=sign*dc
  if n>=5:return True
 return False

def legal_near(b,radius=2):
 ones=np.flatnonzero(b)
 if len(ones)==0:return [112]
 opts=set()
 for v in ones:
  r,c=divmod(int(v),15)
  for dr in range(-radius,radius+1):
   for dc in range(-radius,radius+1):
    rr=r+dr;cc=c+dc
    if 0<=rr<15 and 0<=cc<15 and b[15*rr+dc+dr*0+cc] == 0: # sentinel replaced below
     pass
  for dr in range(-radius,radius+1):
   for dc in range(-radius,radius+1):
    rr=r+dr;cc=c+dc
    if 0<=rr<15 and 0<=cc<15 and b[15*rr+cc]==0:opts.add(15*rr+cc)
 return sorted(opts)

def next_move(board,side,model):
 start=time.perf_counter()
 wins=immediate_wins(board,side)
 if wins:
  return min(wins),(time.perf_counter()-start)*1000,'win'
 must=immediate_wins(board,3-side)
 if len(must)==1:
  return min(must),(time.perf_counter()-start)*1000,'block'
 choices=legal_near(board)
 if not choices:choices=[int(i) for i in np.flatnonzero(board==0)]
 if not choices:return None,(time.perf_counter()-start)*1000,'full'
 f=np.stack([features(board,int(i),side) for i in choices])
 pred=model.predict(f,num_threads=1)
 choice=min(choices, key=lambda i:(-float(pred[choices.index(i)]),i))
 return choice,(time.perf_counter()-start)*1000,'rank'

def opening(seed):
 rnd=random.Random(seed)
 b=np.zeros(225,np.uint8)
 b[112]=1
 neigh=[97,111,113,127,96,98,126,128]
 white=rnd.choice(neigh);b[white]=2
 pool=[i for i in legal_near(b,2) if i!=112 and i!=white]
 black=rnd.choice(pool);b[black]=1
 pool=[i for i in legal_near(b,2) if i!=white and i!=black]
 w2=rnd.choice(pool);b[w2]=2
 return b,[112,white,black,w2]

def game(models,assignment,starting,seed):
 board,moves=opening(seed);times={s:[] for s in models};kinds={s:{} for s in models};result=None
 for ply in range(4,225):
  side=1 if ply%2==0 else 2;who=assignment[side]
  move,ms,kind=next_move(board,side,models[who]);times[who].append(ms);kinds[who][kind]=kinds[who].get(kind,0)+1
  if move is None or board[move]:raise RuntimeError(f'illegal candidate at ply {ply}')
  board[move]=side;moves.append(move)
  if haswin_after(board,move,side):result=who;break
 if result is None:result='draw'
 return {'winner':result,'black_model':assignment[1],'white_model':assignment[2],
         'moves':moves,'nplies':len(moves),'move_times_ms':times,'decision_modes':kinds,'opening_seed':seed}

def main():
 a=argparse.ArgumentParser();a.add_argument('--pairs',type=int,default=36);args=a.parse_args()
 mod={'R04':lgb.Booster(model_file=str(ROOT/'r04_239tree_34d_compatible_base.txt')),
      'R07':lgb.Booster(model_file=str(ROOT/'eclipse_r07_34d_249_trees.txt'))}
 records=[];tic=time.time()
 for i in range(args.pairs):
  seed=20261129000+i
  for assign in ({1:'R04',2:'R07'},{1:'R07',2:'R04'}):
   records.append(game(mod,assign,None,seed))
  if (i+1)%6==0: print('MATCHES',len(records),'completed',round(time.time()-tic,1),flush=True)
 win={x:sum(r['winner']==x for r in records) for x in ('R04','R07','draw')}
 latency={}
 for m in mod:
  vals=[x for r in records for x in r['move_times_ms'][m]]
  vals.sort();latency[m]={'decisions':len(vals),'p50_ms':round(float(np.quantile(vals,.50)),3),'p95_ms':round(float(np.quantile(vals,.95)),3),'p99_ms':round(float(np.quantile(vals,.99)),3)}
 recap={'schema':'eclipse.r07.34d-mirrored-ranker-arena.v1','not_native_v9_engine':True,'not_elo':True,
        'model_versions':{m:mod[m].num_trees() for m in mod},'pairs':args.pairs,'games':len(records),'wins':win,
        'winrates':{k:round(v/len(records),4) for k,v in win.items()},'latency':latency,'seconds':round(time.time()-tic,2),
        'rules':'15x15 freestyle, alpha-beta depth zero, rule tactical immediate win and singleton must-block override, full near-stone static LightGBM ranker, paired color-swap starts; independent research surrogate not V9 C++ V2 search.','log_file':'arena_r07_games.jsonl'}
 (ROOT/'arena_r07_games.jsonl').write_text('\n'.join(json.dumps({k:v for k,v in g.items() if k not in ('move_times_ms',)},ensure_ascii=False) for g in records)+'\n')
 (ROOT/'arena_r07_summary.json').write_text(json.dumps(recap,indent=2,ensure_ascii=False)+'\n')
 print('RESULT',json.dumps(recap),flush=True)
if __name__=='__main__':main()
