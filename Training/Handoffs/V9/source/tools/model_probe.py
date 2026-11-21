#!/usr/bin/env python3
"""Load real LightGBM checkpoint for V9 identity and static 26D ranking checks.
Not a Gomoku engine. Do NOT expose a fake R15 --best runner.
"""
import argparse,hashlib,json,sys
from pathlib import Path
import numpy as np
try:
 import lightgbm as lgb
except ImportError:
 sys.exit('Install lightgbm and numpy to run this model loader, e.g. pip install lightgbm numpy')
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=json.loads((ROOT/'manifest/REVIEW-MANIFEST.json').read_text())

def inside(r,c):return 0<=r<15 and 0<=c<15

def features(board,index,side):
 x=np.zeros(26,dtype=np.float64)
 if not 0<=index<225 or board[index]!=0 or side not in (1,2):return x
 axes=((1,0),(0,1),(1,1),(1,-1))
 enemy=3-side;r,c=divmod(index,15)
 for dr,dc in axes:
  for offset in range(5):
   rr=r-offset*dr; cc=c-offset*dc
   if not inside(rr,cc) or not inside(rr+4*dr,cc+4*dc):continue
   own=other=0
   for k in range(5):
    v=board[(rr+k*dr)*15+cc+k*dc]
    own+=(v==side);other+=(v==enemy)
   if not other and 1<=own<=4:x[own-1]+=1
   if not own and 1<=other<=4:x[4+other-1]+=1
 own_axes=enemy_axes=0
 for dr,dc in axes:
  own=other=1;own_open=other_open=0
  for sign in (-1,1):
   rr=r+sign*dr;cc=c+sign*dc
   while inside(rr,cc) and board[rr*15+cc]==side:
    own+=1;rr+=sign*dr;cc+=sign*dc
   if inside(rr,cc) and board[rr*15+cc]==0:own_open+=1
   rr=r+sign*dr;cc=c+sign*dc
   while inside(rr,cc) and board[rr*15+cc]==enemy:
    other+=1;rr+=sign*dr;cc+=sign*dc
   if inside(rr,cc) and board[rr*15+cc]==0:other_open+=1
  x[8]=max(x[8],own);x[9]=max(x[9],other)
  if own>=3 and own_open==2:x[10]+=1
  if other>=3 and other_open==2:x[11]+=1
  if own>=4 and own_open>=1:x[12]+=1
  if other>=4 and other_open>=1:x[13]+=1
  if own>=3 and own_open>=1:own_axes+=1
  if other>=3 and other_open>=1:enemy_axes+=1
  for sign in (-1,1):
   for dist in (1,2):
    rr=r+sign*dist*dr;cc=c+sign*dist*dc
    if not inside(rr,cc):continue
    v=board[rr*15+cc]
    if v==side:x[14 if dist==1 else 16]+=1
    if v==enemy:x[15 if dist==1 else 17]+=1
 x[18]=15-abs(r-7)-abs(c-7)
 x[19]=min(r,c,14-r,14-c)
 x[20]=sum(v!=0 for v in board)
 x[21]=own_axes;x[22]=enemy_axes
 x[23]=x[2]*(x[2]-1)/2;x[24]=x[6]*(x[6]-1)/2;x[25]=1
 return x

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--model',choices=list(MANIFEST['model_files']),required=True)
 action=ap.add_mutually_exclusive_group(required=True)
 action.add_argument('--identity',action='store_true')
 action.add_argument('--tactical-smoke',action='store_true')
 args=ap.parse_args()
 m=MANIFEST['model_files'][args.model]
 path=ROOT/m['checkpoint_path']
 digest=hashlib.sha256(path.read_bytes()).hexdigest()
 assert digest==m['sha256'], 'checkpoint SHA mismatch'
 booster=lgb.Booster(model_file=str(path)) # genuinely loads the bytes at runtime
 assert hashlib.sha256(path.read_bytes()).hexdigest()==digest
 assert booster.num_trees()==m['trees'], (booster.num_trees(),m['trees'])
 assert booster.num_feature()==m['n_features']
 if args.identity:
  print(json.dumps({'schema':'eclipse.v9.research-loaded-checkpoint-identity.v1',
   'family':m['family'],'internal_training_version':'V9',
   'checkpoint_sha256':digest,'checkpoint_loaded':True,'trees':booster.num_trees(),
   'features':booster.num_feature(),'research_only':True,'r15_handoff_complete':False},ensure_ascii=False,sort_keys=True));return
 board=np.zeros(225,dtype=np.uint8)
 board[[10,79,95,111]]=1;board[[4,19,34,49]]=2
 legal=np.flatnonzero(board==0).astype(np.int32)
 batch=np.array([features(board,int(i),1) for i in legal],dtype=np.float64)
 scores=booster.predict(batch,num_threads=2)
 order=np.lexsort((legal,-scores))
 top3=[int(legal[i]) for i in order[:3]]
 expected_rank=int(np.flatnonzero(legal[order]==64)[0]+1)
 output={'model':args.model,'type':'synthetic_static_ranker_only','top3':top3,
  'unique_mandatory_block_move':64,'correct_block_rank':expected_rank,
  'note':'This is ranking only; a real search engine must apply mandatory block gate separately.'}
 print(json.dumps(output,ensure_ascii=False,sort_keys=True))
 expected={'astra-v8-safe':(64,1),'astra-v9':(63,3),'sol-v8':(63,3),'sol-v9':(63,3)}
 if (top3[0],expected_rank)!=expected[args.model]:
  sys.exit('REPRODUCTION MISMATCH: expected '+repr(expected[args.model]))
if __name__=='__main__':main()
