"""Run in FuzzyVeins after the 20 completed runs; archive evidence, not credentials."""
from pathlib import Path
import gzip
import hashlib
import json
import re
import tarfile
import csv

root=Path.cwd();out=root/'results/r3q5';export=out/'export';export.mkdir(exist_ok=True)
expected=list(range(20,30))+list(range(110,120))
done=list(map(int,re.findall(r'full run=(\d+) duration=600s .* PASS',(out/'full_status.log').read_text())))
assert done==expected,done
on=root/'results/chapter52_strong/Chapter52_R3Q5_trace_on_Strong/Nv50_Proposed_seed0'
off=root/'results/chapter52_strong/Chapter52_R3Q5_trace_off_Strong/Nv50_Proposed_seed0'
files=sorted(on.glob('*/metrics.csv'));assert len(files)>0
assert {str(p.relative_to(on)) for p in files}=={str(p.relative_to(off)) for p in off.glob('*/metrics.csv')}
observed={'avg_uhat','avg_rho','avg_epsilon_budget','raw_uhat','effective_uhat','hw_res',
          'u_sc_mean','u_sc_std','realized_uhat','u_sp_mean','u_sp_std'}
differences={};matched=set();rows=0
for p in files:
    a=list(csv.DictReader(p.open()));b=list(csv.DictReader((off/p.relative_to(on)).open()))
    assert len(a)==len(b)
    for x,y in zip(a,b):
        rows+=1
        for k in x:
            if x[k]!=y[k]:
                assert k in observed,('Dynamics or network mismatch',p,k,x[k],y[k])
                differences[k]=max(differences.get(k,0),abs(float(x[k])-float(y[k])))
            else:matched.add(k)
neutral=dict(status='PASS_DYNAMICS_ONLY',paired_node_csv_files=len(files),rows=rows,
    identical_columns=sorted(matched-set(differences)),different_columns_max_abs=differences,
    scope='Strategy, exploitability and communication columns are identical. Observation-based resource/payoff summaries differ and are not evidence for the R3-5 certificate.')
(out/'trace_neutrality.json').write_text(json.dumps(neutral,indent=2)+'\n')
manifest=dict(runs=[],trace_neutrality=neutral,source_sha256={})
for r in expected:
    src=out/f'traces/full_{r}.csv';dst=export/f'full_{r}.csv.gz'
    raw=src.read_bytes()
    with gzip.open(dst,'wb') as f:f.write(raw)
    log=(out/f'logs/full_{r}.log').read_text()
    Nv=50 if r<30 else 200
    assert f'Scenario: $Nv={Nv}, $method="Proposed", $repetition={r%10}' in log
    manifest['runs'].append(dict(run=r,Nv=50 if r<30 else 200,seed=r%10,
        csv_bytes=len(raw),csv_sha256=hashlib.sha256(raw).hexdigest(),
        gzip_sha256=hashlib.sha256(dst.read_bytes()).hexdigest()))
source=root/'../../src/veins/modules/application/fuzzytrust'
sources=[source/'Chapter52/ITGameEngine.cc',source/'Chapter52/ITGameEngine.h',
    source/'Chapter52/RSUGovernanceAggregator.cc',source/'Chapter52/RSUGovernanceAggregator.h',
    source/'Chapter52/StrategyReportMessage.msg',source/'Chapter52/GovernanceWeightMessage.msg',
    source/'FuzzyTrustApp.cc',source/'FuzzyTrustApp.h',source/'FuzzyTrustApp.ned',
    root/'omnetpp.ini',root/'r3q5.ini',root/'scripts/r3q5/trace.patch',root/'scripts/r3q5/source_hashes.json']
with tarfile.open(out/'source_snapshot.tar.gz','w:gz') as tar:
    for p in sources:
        manifest['source_sha256'][p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
        tar.add(p,arcname=p.name)
manifest['library_sha256']=hashlib.sha256((root/'../../out/clang-release/src/libveins.so').read_bytes()).hexdigest()
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
with tarfile.open(out/'r3q5_bundle.tar','w') as tar:
    for r in expected:tar.add(export/f'full_{r}.csv.gz',arcname=f'full_{r}.csv.gz')
    for name in ['cpp_consistency.csv','cpp_closed_loop.csv','cpp_closed_loop_trace.csv','reference.csv',
                 'trace_neutrality.json','manifest.json','source_snapshot.tar.gz','full_status.log','build.log']:
        tar.add(out/name,arcname=name)
print(json.dumps(dict(status='PASS',runs=len(expected),neutrality=neutral,bundle_bytes=(out/'r3q5_bundle.tar').stat().st_size)))
