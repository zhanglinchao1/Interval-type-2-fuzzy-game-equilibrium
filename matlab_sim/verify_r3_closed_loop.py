"""R3-4 full-domain certificate for the canonical W-FBRI/governance loop.

Reuses the R3-3 directed-interval arithmetic and Bernstein bounds. Each
mean-field tetrahedron covers ALL omega in the five-rule simplex: affine
dependence on theta=P omega is enclosed by the convex hull of P's columns.
The focused radius ratio is then propagated with directed intervals.
No sampled Jacobian is used to accept a cell. Run MATLAB ...('prepare') first.
"""
from fractions import Fraction as F
from functools import lru_cache
from itertools import combinations
from pathlib import Path
import csv
import hashlib
import json
import time

from scipy.io import loadmat
from verify_r3_certificate import (Interval as I, D, PAIRS, input_hull,
                                   polynomial_range, check_arithmetic)

WP = list(combinations(range(5), 2))
SUBSETS = [(0,), (1,), (2,), (3,), (0,1), (0,2), (0,3)]
ZERO = I(0)


def hull(values):
    return I(min(v.lo for v in values), max(v.hi for v in values))


def dot(a, b):
    return sum((x*y for x, y in zip(a, b)), ZERO)


def governance_bounds(M, P):
    # v_l=x'T_l x, u=(w.v)/(w.t), t_l=1'P_l, Delta_l=v_l-w_l u.
    # The normalization bounds also cover the exact binary MATLAB literals.
    T = [[[sum((P[k][l]*M[k][a][b] for k in range(3)), ZERO)
           for b in range(4)] for a in range(4)] for l in range(5)]
    totals = [sum((P[k][l] for k in range(3)), ZERO) for l in range(5)]
    smin = I(min(t.lo for t in totals))
    umax = I(max(T[l][a][b].hi for l in range(5) for a in range(4) for b in range(4)))/smin
    vrange = max((T[l][a][b]-T[m][a][b]).magnitude()
                 for l, m in WP for a in range(4) for b in range(4))
    trange = max((totals[l]-totals[m]).magnitude() for l, m in WP)
    d = umax/2+(I(vrange)+umax*I(trange))/smin/4
    c = D(0)
    for z in range(4):
        for a, b in PAIRS:
            dv = [T[l][z][a]+T[l][a][z]-T[l][z][b]-T[l][b][z] for l in range(5)]
            spread = max((dv[l]-dv[m]).magnitude() for l, m in WP)
            vabs = max(v.magnitude() for v in dv)
            c = max(c, ((I(spread)+I(vabs)/smin)/4).hi)
    return I(c), I(d.hi)


class CaseBound:
    def __init__(self, cfg):
        self.cfg = cfg
        p = cfg['p']
        assert p['interaction_model'] == 'complete_leave_one_out'
        assert p['payoff_aggregation'] == 'concave_quadratic'
        assert p['num_strategies'] == 4 and p['N'] >= 2
        assert 'feasible_mask' not in p and 'lambda_path' not in p
        assert p.get('governance_noise_std', 0) == 0
        assert not p.get('tail_cvar_enable', False)
        self.M = [[[input_hull(v) for v in row] for row in p[key]]
                  for key in ['trust_matrix', 'delay_matrix', 'res_matrix']]
        self.P = [[input_hull(v) for v in row] for row in p['P_pay']]
        self.lam = input_hull(p['lambda'])
        self.beta = input_hull(p['beta'])
        assert self.lam.lo > 0 and self.beta.lo > 0 and self.beta.hi <= 1
        self.s = int(cfg['focus']); assert self.s in (0, 40) and cfg['focus'] == self.s
        self.delta = input_hull(cfg['delta'])
        self.bell = bool(p.get('fou_modulation', False))
        self.exposure = p.get('fou_strategy_scale', [1]*4)
        self.polys = []
        self.endpoint_lo, self.endpoint_hi = D(1), D(0)
        for j in range(4):
            a = self.delta*input_hull(self.exposure[j])
            if self.bell:
                cent = [I(0), I(2), -1-16*a*a, 32*a*a, -16*a*a]
                rad = [I(0), 8*a, -16*a, 8*a]
                ends = [[I(0), 1-4*a, 4*a], [I(0), 1+4*a, -4*a]]
            else:
                cent, rad = [-a*a, I(2), I(-1)], [2*a, -2*a]
                ends = [[-a, I(1)], [a, I(1)]]
            nu = [cent[i]-(rad[i]/2 if i<len(rad) else ZERO) for i in range(len(cent))]
            self.polys.append([cent, rad, [(i+1)*v for i, v in enumerate(cent[1:])],
                               [(i+1)*v for i, v in enumerate(rad[1:])], nu,
                               [(i+1)*v for i, v in enumerate(nu[1:])]])
            for k in range(3):
                lo = min(v.lo for v in self.M[k][j]); hi = max(v.hi for v in self.M[k][j])
                for ep in ends:
                    v = polynomial_range(ep,lo,hi)
                    self.endpoint_lo = min(self.endpoint_lo,v.lo)
                    self.endpoint_hi = max(self.endpoint_hi,v.hi)
        assert self.endpoint_lo>0 and self.endpoint_hi<1, 'Clipping must be enclosed separately.'
        self.c,self.d = governance_bounds(self.M,self.P)
        self.base_B = self.uniform_base_B() if not self.s else None

    @lru_cache(maxsize=100000)
    def ranges(self,j,lo,hi):
        needed=range(4) if self.s else range(4,6)
        return [polynomial_range(poly,lo,hi) if i in needed else None
                for i,poly in enumerate(self.polys[j])]

    def omega_hull(self, values):
        return hull([dot([self.P[k][l] for k in range(3)],values) for l in range(5)])

    def omega_directions(self, values):
        return [dot([self.P[k][l]-self.P[k][m] for k in range(3)],values) for l,m in WP]

    def uniform_base_B(self):
        # Multivariate quadratic Bernstein coefficients on the whole x simplex.
        # Directly bound action differences of directional omega derivatives.
        assert not self.bell
        bound = D(0)
        a = 2+self.delta
        for i in range(4):
            for j in range(i,4):
                coef = [[a*(self.M[k][u][i]+self.M[k][u][j])/2
                         -self.M[k][u][i]*self.M[k][u][j]
                         -self.delta*self.delta-self.delta for k in range(3)]
                        for u in range(4)]
                for l,m in WP:
                    directions = [dot([self.P[k][l]-self.P[k][m] for k in range(3)],co) for co in coef]
                    bound = max(bound,max((directions[u]-directions[v]).magnitude() for u,v in PAIRS))
        return (I(bound)/(4*self.lam)).hi

    def enclose(self,V):
        C=[]; R=[]; dC=[]; dR=[]; base=[]; db=[]
        for j in range(4):
            vals=[]
            for k in range(3):
                mu=[dot([I(q) for q in v],self.M[k][j]) for v in V]
                vals.append(self.ranges(j,min(v.lo for v in mu),max(v.hi for v in mu)))
            if not self.s:
                vs=[v[4] for v in vals]; xb=[]
                for a,b in PAIRS:
                    xb.append(self.omega_hull([vals[k][5]*(self.M[k][j][a]-self.M[k][j][b])
                                              for k in range(3)]))
                base.append(self.omega_hull(vs)); db.append(xb)
                continue
            cs=[v[0] for v in vals]; rs=[v[1] for v in vals]
            C.append(self.omega_hull(cs)); R.append(self.omega_hull(rs))
            xc=[]; xr=[]
            for a,b in PAIRS:
                dm=[self.M[k][j][a]-self.M[k][j][b] for k in range(3)]
                xc.append(self.omega_hull([vals[k][2]*dm[k] for k in range(3)]))
                xr.append(self.omega_hull([vals[k][3]*dm[k] for k in range(3)]))
            dC.append(xc+self.omega_directions(cs)); dR.append(xr+self.omega_directions(rs))
        if self.s:
            margin=min((R[0]-R[j]).lo for j in range(1,4))
            floor=(R[0]-I('.01')).lo
            if min(margin,floor)<=0:return None
            nu=[]; grad=[]
            for j in range(4):
                if j==0:
                    pen, dp=R[j],dR[j]
                else:
                    ratio=R[j]/R[0]
                    ratio=I(max(D(0),ratio.lo),min(D(1),ratio.hi))
                    power=ratio**self.s
                    pen=R[j]*power
                    dp=[(self.s+1)*power*dR[j][z]-self.s*power*ratio*dR[0][z] for z in range(16)]
                nu.append(C[j]-pen/2)
                grad.append([dC[j][z]-dp[z]/2 for z in range(16)])
        else:
            nu,grad=base,db; margin=D(0)
        prob=[]
        for j in range(4):
            denominator=1+sum((((nu[k]-nu[j])/self.lam).exp() for k in range(4) if k!=j),ZERO)
            prob.append(I(1)/denominator)
        products={}
        for j,k in PAIRS:
            pp=prob[j]*prob[k]
            gap=nu[j]-nu[k]
            distance=max(gap.lo,gap.hi.copy_negate(),D(0))
            u=(-I(distance)/self.lam).exp()
            logistic=u/(1+u)**2
            products[j,k]=I(pp.lo,min(pp.hi,logistic.hi,D('.25')))
        # A zero-sum output y has ||y||_1/2=max_A |sum_{j in A} y_j|.
        # Cancel within-subset pairs before interval evaluation; all seven
        # nontrivial subsets up to complement suffice for four actions.
        bounds=[]
        for z in range(16 if self.s else 6):
            cuts=[]
            for subset in SUBSETS:
                jj=ZERO
                for j in subset:
                    for k in range(4):
                        if k not in subset:
                            jj+=products[min(j,k),max(j,k)]*(grad[j][z]-grad[k][z])
                cuts.append((I(jj.magnitude())/self.lam).hi)
            bounds.append(max(cuts))
        kappa=max(bounds[:6])
        B=max(bounds[6:]) if self.s else self.base_B
        return kappa,B,margin


def certify(cfg):
    calc=CaseBound(cfg)
    root=[[F(i==j) for j in range(4)] for i in range(4)]
    pending=[(root,0)]; leaves=[]; volume=F(0); nodes=0; kappa=D(0); B=D(0); margin=D(1)
    started=time.monotonic()
    while pending:
        V,depth=pending.pop(); bounds=calc.enclose(V); nodes+=1
        # Acceptance caps leave a positive joint small-gain margin in both
        # cases; Simulation III also has the independent B<.082 envelope.
        bcap=D('.082') if calc.base_B is not None else D('.1')
        ready=bounds is not None and bounds[0]<D('.96') and bounds[1]<bcap
        if ready:
            kappa=max(kappa,bounds[0]); B=max(B,bounds[1]); margin=min(margin,bounds[2])
            leaves.append(depth); volume+=F(1,2**depth)
        else:
            assert depth<26 and nodes<400000, f'Uncertified cell: {cfg["name"]}, {depth}, {bounds}'
            distances=[sum((V[a][i]-V[b][i])**2 for i in range(4)) for a,b in PAIRS]
            a,b=PAIRS[max(range(6),key=lambda i:distances[i])]
            mid=[(V[a][i]+V[b][i])/2 for i in range(4)]
            left=[v[:] for v in V]; right=[v[:] for v in V]
            left[a]=mid; right[b]=mid
            pending.extend([(left,depth+1),(right,depth+1)])
        if nodes%500==0:
            print(f'{cfg["name"]}: nodes={nodes}, leaves={len(leaves)}, pending={len(pending)}, '
                  f'volume={float(volume):.4f}, kappa<{float(kappa):.6f}, B<{float(B):.6f}, '
                  f'seconds={time.monotonic()-started:.1f}',flush=True)
    assert volume==1
    # Independent prefix-tree count verifies all leaves of a full partition.
    stack=[0]
    for d in leaves:
        n=stack.pop()
        while n<d: stack.append(n+1); n+=1
        assert n==d
    assert not stack
    q=1-calc.beta+calc.beta*I(kappa)
    L=I(B)/(1-I(kappa)); feedback=calc.d+calc.c*L
    assert q.hi<1 and feedback.hi<1
    result=dict(name=cfg['name'],kappa=str(kappa),B=str(B),c=str(calc.c.hi),d=str(calc.d.hi),
                q=str(q.hi),L_star=str(L.hi),feedback=str(feedback.hi),
                cover_leaves=len(leaves),cover_volume_exact='1',leaf_depths=leaves,
                membership_endpoints=[str(calc.endpoint_lo),str(calc.endpoint_hi)],
                SC_radius_margin=str(margin) if calc.s else None,
                seconds=time.monotonic()-started)
    print(json.dumps({k:v for k,v in result.items() if k!='leaf_depths'}),flush=True)
    return result


def main():
    check_arithmetic()
    root=Path(__file__).resolve().parent
    inp=root/'table/table5_3b_r3_closed_loop_inputs.mat'
    cases=loadmat(inp,simplify_cells=True)['cases']
    results=[certify(cfg) for cfg in cases]
    result=dict(status='PASS',precision=60,rounding='directed',
                scope='all local means x in Delta_4 and all rule weights omega in Delta_5; alpha=.5',
                interaction='complete leave-one-out, N>=2; profile norm is mean per-agent l1',
                governance='original deterministic membership-score feedback; 0<h<=1',
                cases=results,input_sha256=hashlib.sha256(inp.read_bytes()).hexdigest(),
                source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    out=root/'table/table5_3b_r3_closed_loop_certificate.json'
    out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    with out.with_suffix('.csv').open('w',newline='',encoding='utf-8') as f:
        cols=['name','kappa','B','c','d','q','L_star','feedback','cover_leaves']
        writer=csv.DictWriter(f,fieldnames=cols,extrasaction='ignore'); writer.writeheader(); writer.writerows(results)
    print('R3-4 full-domain certificates PASS.',flush=True)


if __name__=='__main__':
    main()
