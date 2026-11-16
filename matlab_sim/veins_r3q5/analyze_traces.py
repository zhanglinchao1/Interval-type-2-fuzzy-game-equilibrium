"""Audit actual OMNeT++ event traces, preserving data ages and report identity.

The numerical payoff reconstruction is checked against both original engines
by exp_5_2_r3_sparse_validation. Trace joins do not assume ideal connectivity.
"""
from pathlib import Path
import argparse
import csv
import gzip
import json
import hashlib
import sys
import numpy as np
import pandas as pd
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from verify_r3_sparse import M,MG,P

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'table/r3q5'


def payoff(x,theta):
    mu=np.einsum('kjs,ns->nkj',M,np.atleast_2d(x))
    lo=np.clip(mu-.2,0,1);hi=np.clip(mu+.2,0,1)
    lower=np.einsum('nk,nkj->nj',np.atleast_2d(theta),2*lo-lo*lo)
    upper=np.einsum('nk,nkj->nj',np.atleast_2d(theta),2*hi-hi*hi)
    return .75*lower+.25*upper,(upper-lower)/2


def response(x,theta,rsu=None):
    nu,_=payoff(x,theta)
    if rsu is not None:nu[np.asarray(rsu),2:]=-np.inf
    a=np.exp((nu-nu.max(1,keepdims=True))/.15)
    return a/a.sum(1,keepdims=True)


def governance(x,w):
    theta=w@P.T;theta/=theta.sum(1,keepdims=True)
    mu=np.einsum('na,kab,nb->nk',x,MG,x)
    delta=mu@P-w*np.sum(theta*mu,axis=1,keepdims=True)
    s=np.exp(delta-delta.max(1,keepdims=True));s/=s.sum(1,keepdims=True)
    return .996*w+.004*s


def analyze(path,cert):
    manifest=json.loads((OUT/'manifest.json').read_text()) if (OUT/'manifest.json').exists() else None
    run=int(path.name.split('_')[1].split('.')[0])
    if manifest:
        record=next(r for r in manifest['runs'] if r['run']==run)
        assert hashlib.sha256(path.read_bytes()).hexdigest()==record['gzip_sha256']
    sent,broadcasts,cache,before={}, {}, {}, {}
    reports,last_reports,gov_before={}, {}, {}
    states,active={},set()
    decisions,govs,receptions=[],[],[]
    joins=0; aggr_error=0.;self_bound_slack=-2.
    with (gzip.open(path,'rt') if path.suffix=='.gz' else path.open()) as file:
        for row in csv.DictReader(file):
            event,node=row['event'],row['node'];t=float(row['time']);tree=int(row['tree'])
            pi=np.array([float(row[f'p{j}']) for j in range(4)])
            x=np.array([float(row[f'x{j}']) for j in range(4)])
            theta=np.array([float(row[f't{j}']) for j in range(3)])
            w=np.array([float(row[f'w{j}']) for j in range(5)])
            if event=='init':states[node]=pi;active.add(node)
            elif event=='finish':active.discard(node)
            elif event=='send_report':
                assert tree not in sent
                sent[tree]=(node,float(row['generated']),pi)
            elif event=='recv_report':
                assert tree in sent,'Missing send event'
                assert np.max(np.abs(sent[tree][2]-pi))<1e-14
                reports.setdefault(node,[]).append(sent[tree]);joins+=1
            elif event=='gov_before':gov_before[node]=(w,int(row['index']))
            elif event=='broadcast':
                items=reports.pop(node,[])
                oldw,count=gov_before.pop(node)
                assert count==len(items),'Evidence count mismatch'
                if items:last_reports[node]=items
                used=last_reports.get(node,[])
                if used:aggr_error=max(aggr_error,float(np.abs(np.mean([r[2] for r in used],axis=0)-x).max()))
                else:assert np.max(np.abs(x-.25))<1e-14
                b=dict(node=node,t=t,items=used,w=w,x=x,theta=theta)
                broadcasts[tree]=b;cache[node]=b
                govs.append([t,*x,*oldw,*w,count])
            elif event=='accept_gov':
                assert tree in broadcasts,'Missing broadcast event'
                b=broadcasts[tree];cache[node]=b
                assert np.max(np.abs(b['x']-x))<1e-14
                receptions.append([node,t, max((t-r[1] for r in b['items']),default=np.nan)])
            elif event=='decision_before':
                rsu='.rsu[' in node
                if node not in states:raise AssertionError('Missing init event')
                assert np.max(np.abs(states[node]-pi))<1e-13
                b=cache.get(node);items=b['items'] if b else []
                current=np.mean([states[r[0]] for r in items],axis=0) if items else x
                unique={r[0]:r for r in items}
                dedup=np.mean([r[2] for r in unique.values()],axis=0) if items else x
                other=[r for r in items if r[0]!=node]
                exc=np.mean([r[2] for r in other],axis=0) if other else x
                current_exc=np.mean([states[r[0]] for r in other],axis=0) if other else x
                weight=sum(r[0]==node for r in items)/len(items) if items else 0
                self_error=float(np.abs(x-exc).sum()) if other else np.nan
                if other:self_bound_slack=max(self_bound_slack,self_error-2*weight)
                allother=[states[n] for n in active if n!=node]
                global_x=np.mean(allother,axis=0) if allother else x
                ages=[t-r[1] for r in items]
                record=dict(node=node,time=t,rsu=rsu,pi=pi,x=x,theta=theta,
                    w=b['w'] if b else np.full(5,np.nan),current=current,exc=exc,current_exc=current_exc,global_x=global_x,
                    n_reports=len(items),n_unique=len(unique),self_weight=weight,
                    self_error=self_error,age_mean=np.mean(ages) if ages else np.nan,
                    age_max=max(ages) if ages else np.nan,broadcast_age=t-b['t'] if b else np.nan,
                    dedup_error=float(np.abs(x-dedup).sum()),
                    departed_share=sum(r[0] not in active for r in items)/len(items) if items else 0)
                before[node]=record
            elif event=='decision_after':
                record=before.pop(node);record['after']=pi
                decisions.append(record);states[node]=pi
    assert not before and decisions
    assert abs(t-600)<1e-10,'Run did not reach the declared horizon'
    arr=lambda key:np.array([d[key] for d in decisions])
    x,theta,pi,after,rsu=map(arr,['x','theta','pi','after','rsu'])
    br=response(x,theta,rsu)
    recomputed=.7*pi+.3*br
    step_error=float(np.max(np.abs(after-recomputed)))
    assert step_error<3e-14
    reference=pd.read_csv(OUT/'reference.csv').iloc[0].to_numpy()
    xp,wp=reference[:4],reference[4:]
    th=P@wp;th/=th.sum()
    rref=response(xp,th,[True])[0]
    refs=np.where(rsu[:,None],rref,xp)
    ep=np.abs(after-refs).sum(1)
    k,B,c,d=(float(cert[v]) for v in ['kappa_vehicle','B_vehicle','c','d'])
    w=arr('w');have_governance=np.isfinite(w).all(1)
    ki=np.where(rsu,float(cert['kappa_rsu']),k)
    Bi=np.where(rsu,float(cert['B_rsu']),B)
    omega_error=np.where(have_governance,np.abs(w-wp).sum(1),0)
    initial_force=np.where(have_governance,0,
        .3*np.abs(br-response(x,np.broadcast_to(th,theta.shape),rsu)).sum(1))
    bound=.7*np.abs(pi-refs).sum(1)+.3*ki*np.abs(x-xp).sum(1)+.3*Bi*omega_error+initial_force
    assert np.max(ep-bound)<1e-12
    current,exc,glob=map(arr,['current','exc','global_x'])
    age_cost=.3*np.abs(br-response(current,theta,rsu)).sum(1)
    self_cost=.3*np.abs(br-response(exc,theta,rsu)).sum(1)
    self_cost[arr('self_weight')>=1-1e-14]=np.nan
    glob_cost=.3*np.abs(br-response(glob,theta,rsu)).sum(1)
    topology_cost=.3*np.abs(response(arr('current_exc'),theta,rsu)-response(glob,theta,rsu)).sum(1)
    topology_cost[(arr('n_reports')==0)|(arr('self_weight')>=1-1e-14)|(arr('departed_share')>0)]=np.nan
    age_dist=np.abs(x-current).sum(1)
    assert np.max(age_cost[~rsu]-.3*k*age_dist[~rsu])<1e-12
    nu,rho=payoff(x,theta)
    # The transfer target uses one common nominal governance weight vector.
    nu_global,rho_global=payoff(glob,np.broadcast_to(th,theta.shape))
    eps_cached=nu.max(1)-(after*nu).sum(1)
    eps_global=nu_global.max(1)-(after*nu_global).sum(1)
    difference=nu_global-nu
    uniform_pay_error=np.abs(difference).max(1)
    # Regret is invariant to a common action-payoff offset.
    pay_error=.5*(difference.max(1)-difference.min(1))
    robust_global=(nu_global+rho_global).max(1)-(after*nu_global).sum(1)
    robust_bound=eps_cached+2*pay_error+rho_global.max(1)
    assert np.max(robust_global[~rsu]-robust_bound[~rsu])<1e-12
    assert np.max(eps_global[~rsu]-eps_cached[~rsu]-2*pay_error[~rsu])<1e-12
    fields=['node','time','rsu','n_reports','n_unique','self_weight','self_error',
            'age_mean','age_max','broadcast_age','dedup_error','departed_share']
    df=pd.DataFrame([{k:r[k] for k in fields} for r in decisions])
    df['tracking_error']=ep
    df['increment']=np.abs(after-pi).sum(1)
    df['fixed_input_residual']=.3*np.abs(br-after).sum(1)
    df['age_field_error']=age_dist
    df['age_step_cost']=age_cost;df['self_step_cost']=self_cost
    df['global_step_cost']=glob_cost
    df['topology_step_cost']=topology_cost
    df['payoff_transfer_error']=pay_error
    df['payoff_uniform_error']=uniform_pay_error
    df['global_exploitability']=eps_global
    df['robust_global']=robust_global;df['robust_budget']=robust_bound
    df['fast_bound']=bound
    gs=np.array(govs);oldw=gs[:,5:10];neww=gs[:,10:15]
    deterministic=governance(gs[:,1:5],oldw)
    noise=np.abs(neww-deterministic).sum(1)
    ge=np.abs(neww-wp).sum(1)
    gb=(1-.004+.004*d)*np.abs(oldw-wp).sum(1)+.004*c*np.abs(gs[:,1:5]-xp).sum(1)+noise
    assert np.max(ge-gb)<1e-12
    assert oldw.min()>=.15-1e-14 and oldw.max()<=.25+1e-14
    assert x[~rsu,0].min()>=.25-1e-14
    # Actual return of fresh evidence, after >=10 s without a fresh reception.
    episodes=[];lastfresh={}
    for node,t,age in receptions:
        if '.rsu[' in node or not np.isfinite(age) or age>4:continue
        previous=lastfresh.get(node)
        lastfresh[node]=t
        if previous is None or t-previous<10:continue
        v=df[(df.node==node)&(~df.rsu)]
        pre=v[v.time<=t].tail(1);post=v[v.time>t].head(5)
        if len(pre) and len(post)==5:
            episodes.append([node,t,t-previous,float(pre.tracking_error.iloc[0]),float(post.tracking_error.iloc[-1])])
    stem=path.name.replace('.csv.gz','').replace('.csv','')
    df.to_csv(OUT/(stem+'_diagnostics.csv.gz'),index=False,compression='gzip')
    pd.DataFrame(episodes,columns=['node','time','fresh_gap','before','after_5_decisions']).to_csv(OUT/(stem+'_recovery.csv'),index=False)
    v=df[~df.rsu];tail=v[v.time>=480]
    assert v.node.nunique()==(50 if run<30 else 200)
    summary=dict(run=stem,vehicles=v.node.nunique(),decisions=len(v),all_policy_updates=len(df),
        governance_updates=len(gs),report_receipts=joins,
        step_max_error=step_error,aggregate_max_error=aggr_error,
        fast_bound_max_slack=float(np.max(ep-bound)),
        governance_bound_max_slack=float(np.max(ge-gb)),self_bound_max_slack=self_bound_slack,
        no_evidence_fraction=float((v.n_reports==0).mean()),
        age_p95=float(v.age_max.quantile(.95)),age_max=float(v.age_max.max()),
        age_over_10s_fraction=float((v.age_max>10).mean()),
        self_included_fraction=float((v.self_weight>0).mean()),
        only_self_fraction=float((v.self_weight>=1-1e-14).mean()),
        duplicate_fraction=float((v.n_reports>v.n_unique).mean()),
        self_weight_max=float(v.self_weight.max()),self_step_cost_max=float(v.self_step_cost.max()),
        age_step_cost_p95=float(v.age_step_cost.quantile(.95)),age_step_cost_max=float(v.age_step_cost.max()),
        global_step_cost_p95=float(v.global_step_cost.quantile(.95)),
        topology_step_cost_p95=float(v.topology_step_cost.quantile(.95)),
        payoff_transfer_p95=float(v.payoff_transfer_error.quantile(.95)),
        robust_budget_mean=float(v.robust_budget.mean()),
        robust_global_mean=float(v.robust_global.mean()),
        tracking_mean=float(v.tracking_error.mean()),tracking_p95=float(v.tracking_error.quantile(.95)),
        tail_tracking_mean=float(tail.tracking_error.mean()),
        zero_increment_wrong_fraction=float(((v.increment<1e-6)&(v.tracking_error>1e-3)).mean()),
        noise_step_max=float(noise.max()),governance_error_max=float(ge.max()),
        omega_min=float(neww.min()),omega_max=float(neww.max()),
        empty_governance_window_fraction=float((gs[:,15]==0).mean()),
        rsus_with_no_evidence=10-len(last_reports),
        min_used_x_SC=float(x[~rsu,0].min()),
        recovery_episodes=len(episodes),
        recovery_before_mean=float(np.mean([a[3] for a in episodes])) if episodes else None,
        recovery_after_mean=float(np.mean([a[4] for a in episodes])) if episodes else None)
    (OUT/(stem+'_summary.json')).write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary),flush=True)
    return summary


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('paths',nargs='+');args=parser.parse_args()
    cert=json.loads((OUT/'certificate.json').read_text())
    summaries=[analyze(Path(p),cert) for p in args.paths]
    pd.DataFrame(summaries).to_csv(OUT/'veins_summary.csv',index=False)
