"""Generate the R3-5 table and figure from completed, audited run outputs."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
from scipy.stats import t
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'table/r3q5'
rows=[json.loads(p.read_text()) for p in sorted(OUT.glob('full_*_summary.json'))]
df=pd.DataFrame(rows);assert len(df)==20 and df.run.nunique()==20
df['Nv']=df.run.map(lambda s:50 if int(s.split('_')[1])<30 else 200)
assert all(df.groupby('Nv').size()==10)
df.to_csv(OUT/'veins_summary.csv',index=False)
metrics=['tracking_mean','tracking_p95','tail_tracking_mean','no_evidence_fraction',
         'age_p95','age_max','age_over_10s_fraction','self_included_fraction','only_self_fraction',
         'duplicate_fraction','age_step_cost_p95','age_step_cost_max','self_step_cost_max',
         'global_step_cost_p95','zero_increment_wrong_fraction',
         'topology_step_cost_p95','payoff_transfer_p95','robust_budget_mean','robust_global_mean',
         'recovery_before_mean','recovery_after_mean']
summary=[]
for n,g in df.groupby('Nv'):
    for key in metrics:
        a=g[key].to_numpy(float);mean=a.mean();half=t.ppf(.975,9)*a.std(ddof=1)/np.sqrt(10)
        summary.append(dict(Nv=n,metric=key,mean=mean,ci_low=mean-half,ci_high=mean+half,
                            min=a.min(),max=a.max()))
pd.DataFrame(summary).to_csv(OUT/'seed_summary.csv',index=False)

plt.rcParams.update({'font.family':'Times New Roman','font.size':12,'axes.labelsize':12,
                     'axes.titlesize':12.5,'legend.fontsize':11.5,'pdf.fonttype':42,'ps.fonttype':42})
fig,axs=plt.subplots(2,2,figsize=(9.4,6.8),layout='constrained')
colors=['#1b6ca8','#bd5832','#26834a']
trace=pd.read_csv(OUT/'cpp_closed_loop_trace.csv')
for mode,name,col,style in zip(range(3),['Dense aggregation','Sparse aggregation','Switching, delayed updates'],colors,['-','--',':']):
    a=trace[trace['case']==mode]
    axs[0,0].semilogy(a.step,np.maximum(a.pi_error,a.w_error),label=name,color=col,linestyle=style)
axs[0,0].set(xlabel='Update index',ylabel=r'Joint error (maximum block $\ell_1$)',title='(a) Original C++ loop, zero observation noise')
axs[0,0].legend(frameon=False);axs[0,0].grid(alpha=.2)

points=[df[df.Nv==n].tracking_mean for n in [50,200]]
for pos,(n,a) in enumerate(zip([50,200],points)):
    x=np.linspace(pos-.11,pos+.11,len(a))
    axs[0,1].scatter(x,a,color=colors[pos],s=22,label=f'$N_v={n}$')
    ci=t.ppf(.975,9)*a.std(ddof=1)/np.sqrt(10)
    axs[0,1].errorbar(pos,a.mean(),yerr=ci,color='black',fmt='_',capsize=5)
axs[0,1].set(xticks=[0,1],xticklabels=['50 vehicles','200 vehicles'],ylabel='Whole-run mean tracking error',
             title='(b) Actual Veins runs, 10 seeds per density')
axs[0,1].grid(axis='y',alpha=.2)

categories=['No received evidence',r'Evidence age $\leq10$ s','Evidence age $>10$ s']
fractions=[]
for n in [50,200]:
    g=df[df.Nv==n];no=g.no_evidence_fraction.mean();old=g.age_over_10s_fraction.mean()
    fractions.append([no,1-no-old,old])
fractions=np.array(fractions);bottom=np.zeros(2)
for j,(name,col) in enumerate(zip(categories,['#b5bac1','#7bb5c8','#dfa668'])):
    axs[1,0].bar([0,1],100*fractions[:,j],bottom=bottom,label=name,color=col,width=.55)
    bottom+=100*fractions[:,j]
axs[1,0].set(xticks=[0,1],xticklabels=['50 vehicles','200 vehicles'],ylabel='Vehicle decisions (%)',ylim=(0,100),
             title='(c) Freshness of the reports used in decisions')
axs[1,0].legend(frameon=False,loc='upper center',bbox_to_anchor=(.5,-.13))

for pos,n in enumerate([50,200]):
    g=df[df.Nv==n]
    means=[];cis=[]
    for key in ['recovery_before_mean','recovery_after_mean']:
        a=g[key];means.append(a.mean());cis.append(t.ppf(.975,9)*a.std(ddof=1)/np.sqrt(10))
    xx=np.array([0,1])+(pos-.5)*.12
    axs[1,1].errorbar(xx,means,yerr=cis,color=colors[pos],marker='o',capsize=4,label=f'$N_v={n}$')
axs[1,1].set(xticks=[0,1],xticklabels=['Before fresh reception','Five decisions later'],
             ylabel='Mean tracking error',title=r'(d) Recovery after a fresh-evidence gap $\geq10$ s')
axs[1,1].legend(frameon=False);axs[1,1].grid(alpha=.2)
image=ROOT/'image/fig5_24_r3_sparse_validation'
fig.savefig(image.with_suffix('.pdf'),bbox_inches='tight')
fig.savefig(image.with_suffix('.png'),dpi=180,bbox_inches='tight');plt.close(fig)
cert=json.loads((OUT/'certificate.json').read_text())
closed=pd.read_csv(OUT/'cpp_closed_loop.csv')
result=dict(status='PASS',runs=len(df),vehicle_updates=int(df.decisions.sum()),
    all_policy_updates=int(df.all_policy_updates.sum()),governance_updates=int(df.governance_updates.sum()),
    received_reports=int(df.report_receipts.sum()),recovery_episodes=int(df.recovery_episodes.sum()),
    max_step_error=float(df.step_max_error.max()),max_aggregate_error=float(df.aggregate_max_error.max()),
    fast_bound_max_slack=float(df.fast_bound_max_slack.max()),governance_bound_max_slack=float(df.governance_bound_max_slack.max()),
    max_data_age=float(df.age_max.max()),duplicate_fraction_max=float(df.duplicate_fraction.max()),
    cpp_runs=len(closed),cpp_max_endpoint_error=float(closed[['max_pi_error','max_w_error']].max().max()),
    cpp_steps_range=[int(closed.steps.min()),int(closed.steps.max())],
    certificate_feedback=cert['feedback'],certificate_domain=[cert['strategy_domain'],cert['governance_domain']])
(OUT/'final_audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
print(pd.DataFrame(summary).pivot(index='metric',columns='Nv',values='mean').to_string())
