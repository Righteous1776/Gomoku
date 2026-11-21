#!/usr/bin/env python3
"""Research handoff archive audit: checks source-byte hashes and 24 legal games."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
errors=[]
for line in (ROOT/'SHA256SUMS.txt').read_text(encoding='utf8').splitlines():
 if not line.strip():continue
 expected,relative=line.split('  ',1)
 p=ROOT/relative
 if not p.exists() or sha(p)!=expected:errors.append('SHA MISMATCH '+relative)
meta=json.loads((ROOT/'manifest/REVIEW-MANIFEST.json').read_text())
for k,m in meta['model_files'].items():
 p=ROOT/m['checkpoint_path']
 if sha(p)!=m['sha256']:errors.append('MODEL HASH FAIL '+k)
 if p.stat().st_size!=m['bytes']:errors.append('MODEL SIZE FAIL '+k)

def five(b,k,s):
 r,c=divmod(k,15)
 for dr,dc in [(1,0),(0,1),(1,1),(1,-1)]:
  n=1
  for direction in (-1,1):
   rr=r+dr*direction;cc=c+dc*direction
   while 0<=rr<15 and 0<=cc<15 and b[rr*15+cc]==s:
    n+=1;rr+=dr*direction;cc+=dc*direction
  if n>=5:return True
 return False

key2file={'astra_v9_vs_v8':'astra_120ms_8games_complete.jsonl',
          'sol_v9_vs_v8':'sol_120ms_8games_complete.jsonl',
          'astra_v9_vs_sol_v9':'v9_astra_vs_v9_sol_120ms_8games_complete.jsonl'}
report=json.loads((ROOT/'evidence/benchmark-audit.json').read_text())
games_total=0
for key,filename in key2file.items():
 p=ROOT/'evidence/results'/filename
 logs=[json.loads(s) for s in p.read_text().splitlines()]
 games=[x for x in logs if x.get('type')=='game']
 counts={'A':0,'B':0,'draw':0};pairs={}
 if len(games)!=8:errors.append('GAME COUNT FAIL '+key)
 for g in games:
  b=[0]*225;terminal=False;winning_side=0
  seq=g['moves'];pairs.setdefault(g['pair'],[]).append(g)
  if seq[:2]!=g['opening']:errors.append('OPENING MISMATCH '+key)
  if len(seq)!=len(set(seq)) or g['plies']!=len(seq):errors.append('REPLAY WRONG LENGTH '+key)
  for ply,k in enumerate(seq):
   if type(k)!=int or not 0<=k<225 or b[k] or terminal:
    errors.append('ILLEGAL MOVE '+key);break
   who=1+(ply%2);b[k]=who
   if five(b,k,who):terminal=True;winning_side=who
  outcome='draw' if not terminal else ('A' if (winning_side==1)==g['A_black'] else 'B')
  if outcome!=g['winner'] or (not terminal and len(seq)!=225):errors.append('OUTCOME MISMATCH '+key)
  counts[outcome]+=1
 for i,gg in pairs.items():
  if len(gg)!=2 or gg[0]['A_black']==gg[1]['A_black'] or gg[0]['opening']!=gg[1]['opening']:
   errors.append('SWAPPED PAIR FAIL '+key)
 expected=report['groups'][key]
 if [counts['A'],counts['B'],counts['draw']]!=[expected['A_wins'],expected['B_wins'],expected['draws']]:errors.append('SCORE MISMATCH '+key)
 if sha(p)!=expected['raw_jsonl_sha256']:errors.append('MATCH LOG HASH MISMATCH '+key)
 games_total+=len(games)
if games_total!=24:errors.append('TOTAL MATCH COUNT FAIL')
if errors:
 print(json.dumps({'status':'FAIL','errors':errors},ensure_ascii=False,indent=2));sys.exit(1)
print(json.dumps({'status':'PASS','files_checked':len((ROOT/'SHA256SUMS.txt').read_text().splitlines()),
 'checkpoints_checked':4,'games_replayed':games_total,'score_verified':True,
 'actual_swift_zenith_6x_games':0,'production_ready':False},ensure_ascii=False,indent=2))
