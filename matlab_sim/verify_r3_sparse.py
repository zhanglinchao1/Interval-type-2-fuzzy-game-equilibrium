"""R3-5: directed full-domain bounds for the actual FuzzyVeins configuration.

Reuses the R3-3 interval arithmetic and R3-4 governance bound. Clipping is
included explicitly; no sampled derivative accepts a certificate cell.
"""
from fractions import Fraction as F
from pathlib import Path
from itertools import combinations
import hashlib
import json
import time
import numpy as np
from verify_r3_certificate import Interval as I, D, PAIRS, input_hull, check_arithmetic
from verify_r3_closed_loop import governance_bounds, hull, dot, SUBSETS, WP

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'table/r3q5'
M = np.array([[[.9,.7,.3,.1],[.8,.6,.25,.1],[.5,.4,.2,.1],[.3,.2,.15,.05]],
              [[.85,.75,.5,.3],[.8,.7,.45,.25],[.6,.5,.35,.2],[.4,.3,.2,.1]],
              [[.7,.8,.6,.4],[.65,.85,.55,.35],[.75,.7,.5,.3],[.5,.6,.4,.2]]])
MG = M.copy()
MG[1] = [[.85,.75,.5,.3],[.8,.7,.45,.25],[.6,.55,.4,.2],[.4,.35,.25,.15]]
MG[2] = [[.7,.8,.6,.4],[.65,.75,.55,.35],[.55,.65,.5,.3],[.45,.55,.4,.25]]
P = np.array([[.6,.5,.4,.3,.2],[.3,.4,.35,.5,.3],[.1,.1,.25,.2,.5]])


def clipped(v):
    return I(max(D(0), min(D(1), v.lo)), max(D(0), min(D(1), v.hi)))


def g(v):
    # Monotone on [0,1]; evaluate endpoint expressions with directed rounding.
    return I((2*I(v.lo)-I(v.lo)**2).lo, (2*I(v.hi)-I(v.hi)**2).hi)


class VeinsBound:
    def __init__(self):
        self.M = [[[input_hull(v) for v in row] for row in a] for a in M]
        self.P = [[input_hull(v) for v in row] for row in P]
        self.lam, self.delta = input_hull(.15), input_hull(.2)
        self.t = [sum((self.P[k][l] for k in range(3)), I(0)) for l in range(5)]
        self.tmin = I(min(t.lo for t in self.t))
        self.totalrange = I(min(t.lo for t in self.t),max(t.hi for t in self.t))
        self.c, self.d = governance_bounds(
            [[[input_hull(v) for v in row] for row in a] for a in MG], self.P)
        # Reachable governance polytope: uniform initialization, including
        # the bounded Box-Muller observation noise in the actual C++ source.
        self.W = []
        for mid in range(5):
            rest = [j for j in range(5) if j != mid]
            for high in combinations(rest,2):
                self.W.append([I('.2') if j==mid else I('.25') if j in high else I('.15')
                               for j in range(5)])
        self.theta_vertices = []
        for w in self.W:
            theta = [dot(row,w) for row in self.P]
            total = sum(theta,I(0))
            self.theta_vertices.append([v/total for v in theta])
        G = [[[input_hull(v) for v in row] for row in a] for a in MG]
        T = [[[sum((self.P[k][l]*G[k][a][b] for k in range(3)),I(0))
               for b in range(4)] for a in range(4)] for l in range(5)]
        vmax = I(max(((T[l][a][b]+T[l][b][a]-T[m][a][b]-T[m][b][a])/2).magnitude()
                    for l,m in WP for a in range(4) for b in range(4)))
        umax = I(max(v.hi for mat in T for row in mat for v in row))/self.tmin
        # exp(28)>1/min(u1), and .005*sqrt(56)<.0375.
        assert I(28).exp().lo > (I(1)/input_hull(1e-12)).hi
        assert (input_hull(.005)**2*56).hi < (I('.0375')**2).lo
        R = vmax+I('.1')*umax+I('.075')
        sigma_lo = (I(1)/(1+4*R.exp())).lo
        sigma_hi = (I(1)/(1+4*(-R).exp())).hi
        assert sigma_lo > D('.15') and sigma_hi < D('.25')
        self.invariance = dict(noise_abs_bound='.0375',sigma_lower=str(sigma_lo),sigma_upper=str(sigma_hi))
        c = D(0)
        for z in range(4):
            for a,b in PAIRS:
                dv = [T[l][z][a]+T[l][a][z]-T[l][z][b]-T[l][b][z] for l in range(5)]
                spread = max((dv[l]-dv[m]).magnitude() for l,m in WP)
                vabs = max(v.magnitude() for v in dv)
                c = max(c,((I(spread)+I('.1')*I(vabs)/self.tmin)/4).hi)
        self.c = I(c)

    def whull(self, v):
        return hull([dot(theta,v) for theta in self.theta_vertices])

    def scalar(self, mu):
        lo, up = clipped(mu-self.delta), clipped(mu+self.delta)
        val = I('.75')*g(lo)+I('.25')*g(up)
        # Generalized derivative at clipping boundaries includes both sides.
        dl = 2*(1-lo) if (mu-self.delta).lo > 0 else I(0, (2*(1-lo)).hi)
        if (mu-self.delta).hi < 0:
            dl = I(0)
        du = 2*(1-up) if (mu+self.delta).hi < 1 else I(0, (2*(1-up)).hi)
        if (mu+self.delta).lo > 1:
            du = I(0)
        return val, I('.75')*dl+I('.25')*du

    def action_margin(self,V):
        vals = []
        for j in range(4):
            vals.append([self.scalar(hull([dot([I(q) for q in v],self.M[k][j]) for v in V]))[0]
                         for k in range(3)])
        return min(self.whull([vals[0][k]-vals[j][k] for k in range(3)]).lo for j in range(1,4))

    def enclose(self, V):
        vals, deriv, nu = [], [], []
        for j in range(4):
            row = []
            for k in range(3):
                mus = [dot([I(q) for q in v], self.M[k][j]) for v in V]
                row.append(self.scalar(hull(mus)))
            vals.append([v[0] for v in row])
            nu.append(self.whull(vals[-1]))
            deriv.append([[row[k][1]*(self.M[k][j][a]-self.M[k][j][b])
                           for k in range(3)] for a,b in PAIRS])
        gaps, gapgrad = {}, {}
        for j in range(4):
            for k in range(4):
                gv = [vals[j][z]-vals[k][z] for z in range(3)]
                gaps[j,k] = self.whull(gv)
                gapgrad[j,k] = [self.whull([deriv[j][a][z]-deriv[k][a][z] for z in range(3)])
                               for a in range(6)]
                gapgrad[j,k] += [dot([self.P[z][l]-self.P[z][m] for z in range(3)],gv)/self.totalrange
                                -gaps[j,k]*(self.t[l]-self.t[m])/self.totalrange for l,m in WP]
        kappas, Bs = [], []
        for actions, subsets in [(range(4), SUBSETS), (range(2), [(0,)])]:
            prob = [I(1)/(1+sum(((gaps[k,j]/self.lam).exp()
                                for k in actions if k != j), I(0))) for j in actions]
            products = {}
            for j,k in combinations(actions,2):
                gap = gaps[j,k]
                distance = max(gap.lo, gap.hi.copy_negate(), D(0))
                u = (-I(distance)/self.lam).exp()
                products[j,k] = I((prob[j]*prob[k]).lo, min((prob[j]*prob[k]).hi, (u/(1+u)**2).hi, D('.25')))
            bounds = []
            for z in range(16):
                cuts = []
                for subset in subsets:
                    val = sum((products[min(j,k),max(j,k)]*gapgrad[j,k][z]
                               for j in subset for k in actions if k not in subset), I(0))
                    cuts.append((I(val.magnitude())/self.lam).hi)
                bounds.append(max(cuts))
            kappas.append(max(bounds[:6]))
            b = D(0)
            for j,k in combinations(actions,2):
                gapvals = [vals[j][z]-vals[k][z] for z in range(3)]
                for l,m in WP:
                    direction = dot([self.P[z][l]-self.P[z][m] for z in range(3)], gapvals)/self.totalrange
                    direction -= gaps[j,k]*(self.t[l]-self.t[m])/self.totalrange
                    b = max(b, (I(direction.magnitude())/(4*self.lam)).hi)
            Bs.append(min(b,max(bounds[6:])))
        return kappas+Bs


def split(V):
    ds = [sum((V[a][k]-V[b][k])**2 for k in range(4)) for a,b in PAIRS]
    a,b = PAIRS[max(range(6), key=ds.__getitem__)]
    mid = [(V[a][k]+V[b][k])/2 for k in range(4)]
    left,right = [v[:] for v in V],[v[:] for v in V]
    left[a],right[b] = mid,mid
    return left,right


def main():
    check_arithmetic()
    calc = VeinsBound()
    fullroot = [[F(i==j) for j in range(4)] for i in range(4)]
    # Prove SC is a highest-payoff action on the entire input simplex,
    # also for the initial cached theta before the first governance packet.
    original_theta = calc.theta_vertices[:]
    calc.theta_vertices.append([input_hull(.4),input_hull(.35),input_hull(.25)])
    pending,dominance,margin = [(fullroot,0)],[],D(1)
    while pending:
        V,depth = pending.pop()
        m = calc.action_margin(V)
        if m > 0:
            dominance.append(depth);margin=min(margin,m)
        else:
            assert depth < 24,(depth,m)
            left,right = split(V)
            pending.extend([(left,depth+1),(right,depth+1)])
    assert sum((F(1,2**d) for d in dominance),F(0)) == 1
    calc.theta_vertices = original_theta
    print(f'SC dominance PASS: {len(dominance)} cells, margin>{margin}',flush=True)
    # SC probability >=1/4 is preserved by softmax, damping, aggregation,
    # cached reports and the implemented uniform vehicle initialization.
    root = [[F(1,4)*(j==0)+F(3,4)*(i==j) for j in range(4)] for i in range(4)]
    maximum = [D(0)]*4
    started, nodes = time.monotonic(), 0
    # Fixed sufficient caps; failed caps trigger subdivision, never sampling.
    caps = list(map(D, ['.85','.90','.30','.20']))
    # Cover P*Omega by a rectangle in (theta_1,theta_2). Its four exact
    # subrectangles have theta_3=1-theta_1-theta_2, retaining normalization.
    limits = [(min(t[j].lo for t in calc.theta_vertices),max(t[j].hi for t in calc.theta_vertices))
              for j in range(2)]
    mid = [F(a+b)/2 for a,b in limits]
    bins = [[(F(a),m),(m,F(b))] for (a,b),m in zip(limits,mid)]
    covers = []
    for bx in bins[0]:
        for by in bins[1]:
            calc.theta_vertices = [[I(a),I(b),1-I(a)-I(b)] for a in bx for b in by]
            pending = [(root,0)]
            leaves,local,volume = [],[D(0)]*4,F(0)
            while pending:
                V,depth = pending.pop()
                bounds = calc.enclose(V)
                nodes += 1
                if all(b < cap for b,cap in zip(bounds,caps)):
                    leaves.append(depth)
                    local = list(map(max,local,bounds))
                    volume += F(1,2**depth)
                else:
                    if depth >= 28 or nodes >= 200000:
                        (OUT/'failed_cell.json').write_text(json.dumps(dict(
                            vertices=[[str(z) for z in v] for v in V],
                            theta=[[str(z.lo) for z in t] for t in calc.theta_vertices],
                            bounds=list(map(str,bounds))),indent=2))
                        raise AssertionError((depth,bounds))
                    left,right = split(V)
                    pending.extend([(left,depth+1),(right,depth+1)])
                if nodes % 250 == 0:
                    print(f'box={len(covers)} nodes={nodes} cover={float(volume):.4f} '
                          f'bounds={list(map(float,local))} seconds={time.monotonic()-started:.1f}',flush=True)
            assert volume == 1
            pending,replay = [(root,0)],[D(0)]*4
            for target in leaves:
                V,depth = pending.pop()
                while depth < target:
                    left,right = split(V)
                    pending.append((left,depth+1))
                    V,depth = right,depth+1
                assert depth == target
                replay = list(map(max,replay,calc.enclose(V)))
            assert not pending and replay == local
            maximum = list(map(max,maximum,local))
            covers.append(dict(theta_box=[[str(v) for v in bx],[str(v) for v in by]],leaf_depths=leaves))
    k,kr,B,Br = map(I,maximum)
    feedback = calc.d+calc.c*B/(1-k)
    # Numerical stability of the vehicle-governance feedback; RSUs are followers.
    assert k.hi < 1 and feedback.hi < 1
    q = 1-input_hull(.3)+input_hull(.3)*k
    result = dict(status='PASS',kappa_vehicle=str(k.hi),kappa_rsu=str(kr.hi),
                  B_vehicle=str(B.hi),B_rsu=str(Br.hi),c=str(calc.c.hi),d=str(calc.d.hi),
                  feedback=str(feedback.hi),q_vehicle=str(q.hi),covers=covers,
                  exact_cover_volume='1',precision=60,rounding='directed',
                  governance_domain='sum(omega)=1; .15 <= omega_l <= .25',
                  strategy_domain='x in simplex; x_SC >= 1/4',
                  dominance_cover=dominance,SC_payoff_margin=str(margin),
                  invariant_domain=calc.invariance,
                  M=M.tolist(),M_governance=MG.tolist(),P=P.tolist(),
                  alpha=.5,delta=.2,lam=.15,beta=.3,h=.004,
                  source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  seconds=time.monotonic()-started)
    OUT.mkdir(exist_ok=True)
    (OUT/'certificate.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('covers','M','M_governance','P')},indent=2))


if __name__ == '__main__':
    main()
