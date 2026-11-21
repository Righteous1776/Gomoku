import lightgbm as lgb
from pathlib import Path
import hashlib,json
out=Path(__file__).resolve().parent
root=out.parent/'models'
models={'astra_old':root/'BASE-Astra-254.txt','astra_new':root/'ECLIPSE-V5-Astra-Candidate.txt','sol_old':root/'BASE-Sol-120.txt','sol_new':root/'ECLIPSE-V5-Sol-Candidate.txt'}
meta={}
for name,p in models.items():
    booster=lgb.Booster(model_file=str(p)); nodes=[];roots=[]
    def rec(n):
        i=len(nodes);nodes.append(None)
        if 'leaf_value' in n: nodes[i]=(-1,0,-1,-1,n['leaf_value']);return i
        a=rec(n['left_child']);b=rec(n['right_child']);nodes[i]=(n['split_feature'],n['threshold'],a,b,0.);return i
    for tree in booster.dump_model()['tree_info']: roots.append(rec(tree['tree_structure']))
    lines=[f'namespace {name} {{', 'inline constexpr Node nodes[]={']
    for ft,th,l,r,v in nodes:lines.append(f'{{{ft},{th:.17g},{l},{r},{v:.17g}}},')
    lines.extend(['};','inline constexpr int roots[]={'+','.join(map(str,roots))+'};','}'])
    (out/f'{name}.inc').write_text('\n'.join(lines)+'\n')
    meta[name]={'trees':len(roots),'nodes':len(nodes),'checkpoint_sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
(out/'model_hashes.json').write_text(json.dumps(meta,indent=2))
print(meta)
