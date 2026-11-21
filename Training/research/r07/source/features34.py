#!/usr/bin/env python3
"""R07 original 34D research feature adapter; PUBLIC SOURCE ONLY.

The 26D legacy dependency belongs to the separately archived R04 research
tree, not the production V9 engine. No private board input is included here.
Research archive layout:
ECLIPSE_Training_R04/base/data_pipeline.py
ECLIPSE_Training_R06/features34.py  (this file)
"""
import sys
from pathlib import Path
import numpy as np
from numba import njit
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'ECLIPSE_Training_R04/base'))
from data_pipeline import features as legacy26

@njit(cache=True)
def features34(board,index,side):
 x=np.zeros(34,np.float32)
 if index<0 or index>=225 or board[index]!=0 or (side!=1 and side!=2):return x
 x[:26]=legacy26(board,index,side)
 r=index//15;c=index%15;foe=3-side
 exact_win=0;must_block=0;own_three=0;own_four=0;enemy_three_block=0
 holes=np.empty(20,np.int32);hole_count=0
 for axis in range(4):
  if axis==0:dr,dc=0,1
  elif axis==1:dr,dc=1,0
  elif axis==2:dr,dc=1,1
  else:dr,dc=1,-1
  for offset in range(5):
   rr=r-offset*dr;cc=c-offset*dc
   if not(0<=rr<15 and 0<=cc<15 and 0<=rr+4*dr<15 and 0<=cc+4*dc<15):continue
   own=0;other=0;empty=0;last_empty=-1
   for t in range(5):
    loc=(rr+t*dr)*15+cc+t*dc
    v=side if loc==index else board[loc]
    if v==side:own+=1
    elif v==foe:other+=1
    else:empty+=1;last_empty=loc
   if other==0:
    if own==5:exact_win+=1
    if own==4 and empty==1:
     own_four+=1
     seen=False
     for j in range(hole_count):
      if holes[j]==last_empty:seen=True;break
     if not seen:
      holes[hole_count]=last_empty;hole_count+=1
    if own==3 and empty==2:own_three+=1
   if own==1 and other==4:must_block+=1
   if own==1 and other==3 and empty==1:enemy_three_block+=1
 x[26]=1.0 if exact_win>0 else 0.0
 x[27]=1.0 if must_block>0 else 0.0
 x[28]=float(hole_count)
 x[29]=float(enemy_three_block)
 x[30]=1.0 if hole_count>=2 else 0.0
 x[31]=float(own_three)
 x[32]=float(own_four)
 x[33]=float(exact_win*2+must_block)
 return x
