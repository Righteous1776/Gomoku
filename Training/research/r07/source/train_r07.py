#!/usr/bin/env python3
"""R07: authenticated R04 26D -> 34D single-forest extension, isolated research only.

No new independent private data; original winning-line frequency preserved in R04.
Native V9 is NOT loaded. Production ABI incompatible until a 34D integration is built.

This is the public source snapshot. Its ORIGINAL R04/R05/R06 dependencies,
private inputs, and checkpoints are not bundled with the GitHub report.
"""
import os,sys,time,hashlib,json,re,random,collections
from pathlib import Path
import numpy as np
import lightgbm as lgb
ROOT=Path(__file__).resolve().parent
R04=ROOT.parent/'ECLIPSE_Training_R04';R05=ROOT.parent/'ECLIPSE_Training_R05';R06=ROOT.parent/'ECLIPSE_Training_R06'
for x in [R04,R04/'base',R05,R06]:sys.path.insert(0,str(x))
import train_r04 as t4,train_r05 as t5,train_r03 as t3
from train_r06 import source_files,joining
from audit_r04 import scan
from features34 import features34
# Extend real legacy feature extractor without changing the first 26 feature definitions.
t4.features=features34;t5.features=features34;t3.features=features34;t5.ROOT=R06
SEED=20261121307

def extend_r04():
 src=R04/'eclipse_r04_research_lightgbm.txt'; raw=src.read_text()
 expected='b462dfda45c4c4a357680a95c2cf641d99ce68e5f430113eb5f779592cf6f18a'
 assert hashlib.sha256(src.read_bytes()).hexdigest()==expected
 assert raw.count('max_feature_idx=25')==1
 raw=raw.replace('max_feature_idx=25','max_feature_idx=33',1)
 raw=re.sub(r'^feature_names=(.*)$',lambda m:'feature_names='+m[1]+' '+' '.join(f'Column_{i}' for i in range(26,34)),raw,count=1,flags=re.M)
 raw=re.sub(r'^feature_infos=(.*)$',lambda m:'feature_infos='+m[1]+' '+' '.join(['none']*8),raw,count=1,flags=re.M)
 dst=ROOT/'r04_239tree_34d_compatible_base.txt';dst.write_text(raw)
 orig=lgb.Booster(model_file=str(src));extended=lgb.Booster(model_file=str(dst))
 assert orig.num_trees()==extended.num_trees()==239 and extended.num_feature()==34
 test=np.random.default_rng(20261121).uniform(0,3,(256,34)).astype('float32');old=orig.predict(test[:,:26],num_threads=2);new=extended.predict(test,num_threads=2)
 maxdelta=float(np.max(np.abs(old-new)))
 assert maxdelta<1e-10, maxdelta
 return dst,extended,maxdelta

def eval_mod(mod,owner,pub,cases1800,cases900):
 return {'private':t4.rank(mod,owner),'public':t4.rank(mod,pub),
 'known60':t4.puzzles({'m':mod},R04/'base/v9_casepack_hex.txt')['m']['all'],
 'real40':t5.eval40({'m':mod})['m'],
 'unique_block':t5.eval_block({'m':mod})['m'],
 'synthetic1800':t3.eval_suite({'m':mod},cases1800,True)['m'],
 'synthetic_new900':t3.eval_suite({'m':mod},cases900,True)['m']}

def summarize(r):
 return {'private_top1':r['private']['top1_count'],'private_top3':r['private']['top3_count'],
 'public_top1':r['public']['top1_count'],'public_top3':r['public']['top3_count'],
 'known60_top1':r['known60']['top1_count'],'known60_top3':r['known60']['top3_count'],
 'real40_top1':r['real40']['top1'],'real40_top3':r['real40']['top3'],
 'block_rank':r['unique_block']['rank'],
 'novel1800_top1':r['synthetic1800']['correct_top1'],
 'new900_top1':r['synthetic_new900']['correct_top1']}

def main():
 t=time.time();base,baseline,maxd=extend_r04(); print('CHECK_ORIGINAL_26D_EXACT_REPLAY',maxd,flush=True)
 audit=scan(source_files());owner,_=t4.produce(audit['train_event_records'])
 pubraw=t5.load_public();pub,_=t5.public_examples(pubraw)
 print('LOADED',len(owner['train']['groups']),len(pub['train']['groups']),flush=True)
 novel1800=t3.generate_suite(1800,2026112106+999883,False)['cases']
 novel900=t3.generate_suite(900,SEED+200000,False)['cases']
 print('GEN_TACTICS_START',flush=True)
 synthetic=t3.generate_suite(24000,SEED+1131,True)['dataset']
 synthetic['weights'][:]=0.7
 pubtr=pub['train'];pubtr['weights']*=1.15
 train=joining((owner['train'],pubtr,synthetic))
 print('TRAIN_DATA',len(train['groups']),len(train['y']),'seconds',round(time.time()-t,1),flush=True)
 tr=lgb.Dataset(train['x'],label=train['y'],group=train['groups'],weight=train['weights'],free_raw_data=False)
 params={'objective':'lambdarank','metric':'ndcg','ndcg_eval_at':[1,3],
 'learning_rate':0.014,'num_leaves':11,'min_data_in_leaf':110,'feature_fraction':1.0,'verbosity':-1,'num_threads':4,
 'seed':SEED,'deterministic':True,'force_col_wise':True,'lambdarank_truncation_level':15}
 checkpoints={};models={'R04 compatible base':baseline}
 # One fixed fit with 50 iterations; scan 5,10,20,35,50 to spot overtraining, not blind certification.
 print('FIT_START',flush=True)
 mod=lgb.train(params,tr,num_boost_round=50,init_model=str(base))
 print('FIT_COMPLETE',round(time.time()-t,1),'seconds',mod.num_trees(),flush=True)
 for trees in [244,249,259,274,289]:
  dest=ROOT/f'eclipse_r07_34d_{trees}_trees.txt';mod.save_model(str(dest),num_iteration=trees)
  m=lgb.Booster(model_file=str(dest));models[f'R07-{trees}']=m
 print('EVAL_START',flush=True)
 results={}
 for name,m in models.items():
  ev=eval_mod(m,owner['validation'],pub['validation'],novel1800,novel900)
  results[name]=ev
  print('EVAL',name,json.dumps(summarize(ev)),round(time.time()-t,1),'sec',flush=True)
 ref=results['R04 compatible base'];b=summarize(ref)
 gates={}
 for k,ev in results.items():
  if k=='R04 compatible base':continue
  n=summarize(ev)
  gates[k]={
 'private_Top1':n['private_top1']>=b['private_top1'],'private_Top3':n['private_top3']>=b['private_top3'],
 'public_Top1':n['public_top1']>=b['public_top1'],'fixed60_Top1':n['known60_top1']>=b['known60_top1'],
 'fixed60_Top3':n['known60_top3']>=b['known60_top3'],'real40_Top1':n['real40_top1']>=b['real40_top1'],
 'block_exact':n['block_rank']==1,'unseen1800_Top1':n['novel1800_top1']>=b['novel1800_top1'],
 'new900_Top1':n['new900_top1']>=b['new900_top1']}
 # Only a model passing all gates gets recommendation for further blind testing.
 winners=[k for k,v in gates.items() if all(v.values())]
 path=ROOT/'manifest.json'
 report={'schema':'eclipse.r07.34d-extended-research.v1','status':'RESEARCH_NOT_PROMOTED','research_only':True,
 'source':'R04 26D LightGBM original 239-tree forest; deterministic header expansion to 34 features, exact base prediction preserved',
 'base_sha256':hashlib.sha256((R04/'eclipse_r04_research_lightgbm.txt').read_bytes()).hexdigest(),
 'extended_base_sha256':hashlib.sha256(base.read_bytes()).hexdigest(),'base_max_abs_prediction_delta':maxd,
 'additional_features':'8 exact deterministic local tactical features from R06; not usable in 26D engine without integration',
 'private_unique_sources':7,'private_event_accepted':5356,'public_source_files':len(pubraw),'public_unique_full_games':len({tuple(x['seq']) for x in pubraw}),
 'train_private_groups':len(owner['train']['groups']),'train_public_groups':len(pubtr['groups']),
 'train_synthetic_groups':len(synthetic['groups']),'train_groups':len(train['groups']),'train_candidate_rows':len(train['y']),
 'private_holdout':len(owner['validation']['groups']),'public_holdout':len(pub['validation']['groups']),
 'reference_60':60,'unseen_prior_1800':1800,'fresh_generated_900':900,'R07_models':{n:{'trees':m.num_trees(),'sha256':hashlib.sha256((ROOT/f'eclipse_r07_34d_{m.num_trees()}_trees.txt').read_bytes()).hexdigest()} for n,m in models.items() if n.startswith('R07')},
 'results':results,'summary':{k:summarize(v) for k,v in results.items()},
 'gates':gates,'passed_all':winners,'elapsed_seconds':round(time.time()-t,2),
 'V9_games':0,'native_engine_games':0,'claims':'Results from 26D R04 and 34D candidates on same static candidate groups; not V9 C++ matches, not Elo or a deployed model.',
 'evaluation_caveats':['Private records can share opening prefixes despite full-line D4 train/validation split.','Research models before R07 were already evaluated on same holdouts; checkpoint scan is exploratory model selection, not untouched blind testing.','Synthetic tactical boards may not correspond to reachable complete games.','Open source WinePy is engine selfplay, many duplicate games, not a certified expert strategy oracle.']}
 path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 print('GATES',json.dumps({k:[sum(v.values()),len(v)] for k,v in gates.items()}),flush=True)
 print('ANY_PASS',winners,round(time.time()-t,1),'s',flush=True)

if __name__=='__main__':main()
