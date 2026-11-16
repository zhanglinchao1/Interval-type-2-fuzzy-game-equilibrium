"""Independently audit the MATLAB R3 certificate with directed intervals.

The saved leaf depths determine the complete longest-edge bisection tree.
Geometry uses exact rational arithmetic; payoff bounds use 60-digit decimal
intervals with directed rounding. No MATLAB padding or sampled derivatives
are used. Decimal.exp is correctly rounded to nearest, so its neighboring
representable values enclose it (Python 3.12 decimal documentation).
Run from any directory: py -3.12 matlab_sim/verify_r3_certificate.py
"""

from decimal import Context, Decimal as D, ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_EVEN
from fractions import Fraction as F
from itertools import combinations
from math import comb
from pathlib import Path
import hashlib
import json
import random

from scipy.io import loadmat

PRECISION = 60
DOWN = Context(prec=PRECISION, rounding=ROUND_FLOOR)
UP = Context(prec=PRECISION, rounding=ROUND_CEILING)
NEAR = Context(prec=PRECISION, rounding=ROUND_HALF_EVEN)
PAIRS = list(combinations(range(4), 2))


class Interval:
    __slots__ = ("lo", "hi")

    def __init__(self, lo, hi=None):
        if isinstance(lo, F):
            assert hi is None
            self.lo = DOWN.divide(D(lo.numerator), D(lo.denominator))
            self.hi = UP.divide(D(lo.numerator), D(lo.denominator))
        else:
            self.lo = D(lo)
            self.hi = D(lo if hi is None else hi)
        assert self.lo <= self.hi

    def __add__(self, other):
        b = interval(other)
        return Interval(DOWN.add(self.lo, b.lo), UP.add(self.hi, b.hi))

    __radd__ = __add__

    def __neg__(self):
        return Interval(self.hi.copy_negate(), self.lo.copy_negate())

    def __sub__(self, other):
        return self + (-interval(other))

    def __rsub__(self, other):
        return interval(other) - self

    def __mul__(self, other):
        b = interval(other)
        pairs = [(a, z) for a in (self.lo, self.hi) for z in (b.lo, b.hi)]
        return Interval(min(DOWN.multiply(a, z) for a, z in pairs),
                        max(UP.multiply(a, z) for a, z in pairs))

    __rmul__ = __mul__

    def __truediv__(self, other):
        b = interval(other)
        assert b.lo > 0 or b.hi < 0
        return self * Interval(DOWN.divide(D(1), b.hi), UP.divide(D(1), b.lo))

    def __pow__(self, exponent):
        assert isinstance(exponent, int) and exponent >= 0
        # Multiplication alone avoids the non-guaranteed rounding of pow().
        out = Interval(1)
        for _ in range(exponent):
            out = out * self
        return out

    def exp(self):
        a, b = NEAR.exp(self.lo), NEAR.exp(self.hi)
        return Interval(DOWN.next_minus(a), UP.next_plus(b))

    def magnitude(self):
        return max(self.lo.copy_abs(), self.hi.copy_abs())


def interval(value):
    return value if isinstance(value, Interval) else Interval(value)


def input_hull(value):
    """Include both the MATLAB binary literal and its declared decimal value."""
    x = float(value)
    binary = D.from_float(x)
    declared = D(format(x, ".14g"))
    return Interval(min(binary, declared), max(binary, declared))


def polynomial_range(coefficients, lo, hi):
    n = len(coefficients) - 1
    a, width = Interval(lo), Interval(hi) - Interval(lo)
    ap, wp = [Interval(1)], [Interval(1)]
    for _ in range(n):
        ap.append(ap[-1]*a); wp.append(wp[-1]*width)
    power = [sum((coefficients[j] * comb(j, i) * ap[j-i] * wp[i]
                  for j in range(i, n+1)), Interval(0)) for i in range(n+1)]
    bernstein = [sum((power[i] * Interval(F(comb(k, i), comb(n, i)))
                      for i in range(k+1)), Interval(0)) for k in range(n+1)]
    return Interval(min(z.lo for z in bernstein), max(z.hi for z in bernstein))


def replay_cover(rows):
    root = [[F(i == j) for j in range(4)] for i in range(4)]
    pending = [(root, 0)]
    volume = F(0)
    for row in rows:
        target = int(row[0])
        assert row[0] == target and pending
        vertices, depth = pending.pop()
        assert depth <= target
        while depth < target:
            squared = [sum((vertices[i][k]-vertices[j][k])**2 for k in range(4))
                       for i, j in PAIRS]
            a, b = PAIRS[max(range(6), key=lambda i: squared[i])]
            midpoint = [(vertices[a][k]+vertices[b][k])/2 for k in range(4)]
            left, right = [v[:] for v in vertices], [v[:] for v in vertices]
            left[a], right[b] = midpoint, midpoint
            pending.append((left, depth+1))
            vertices, depth = right, depth+1
        leaf_volume = F(1, 2**depth)
        # MATLAB saved det() in binary floating point; the replayed volume
        # is exact and is the value used to prove complete coverage.
        assert abs(F(float(row[1]))-leaf_volume) <= leaf_volume*F(1, 10**12)
        assert all(sum(v) == 1 and min(v) >= 0 for v in vertices)
        volume += leaf_volume
        yield vertices
    assert not pending and volume == 1, "Incomplete or overlapping bisection tree"


def check_arithmetic():
    rng = random.Random(331)
    for _ in range(200):
        a, b = sorted(F(rng.randint(-50, 50), rng.randint(1, 19)) for _ in range(2))
        c, d = sorted(F(rng.randint(1, 50), rng.randint(1, 19)) for _ in range(2))
        A, B = Interval(Interval(a).lo, Interval(b).hi), Interval(Interval(c).lo, Interval(d).hi)
        for result, exact_lo, exact_hi in [
            (A+B, a+c, b+d), (A-B, a-d, b-c),
            (A*B, min(a*c, a*d, b*c, b*d), max(a*c, a*d, b*c, b*d)),
            (A/B, min(a/c, a/d, b/c, b/d), max(a/c, a/d, b/c, b/d))]:
            assert F(result.lo) <= exact_lo <= exact_hi <= F(result.hi)
    assert Interval(0).exp().lo < 1 < Interval(0).exp().hi
    coeff = [F(2), F(-3), F(5, 7), F(1, 3), F(-2)]
    bound = polynomial_range([Interval(x) for x in coeff], D(".2"), D(".8"))
    for k in range(101):
        x = F(1, 5)+F(3*k, 500)
        y = sum(c*x**j for j, c in enumerate(coeff))
        assert F(bound.lo) <= y <= F(bound.hi)


def main():
    check_arithmetic()
    directory = Path(__file__).resolve().parent
    artifact = directory / "table/table5_6o_r3_certificate.mat"
    data = loadmat(artifact, variable_names=["c0", "c40", "p", "env"], simplify_cells=True)
    p, cfg, old = data["p"], data["env"], data["c40"]
    assert p["interaction_model"] == "complete_leave_one_out"
    assert p["payoff_aggregation"] == "concave_quadratic" and p["fou_modulation"]
    assert p["num_strategies"] == 4 and "feasible_mask" not in p
    assert not p.get("tail_cvar_enable", False)
    assert old["alpha"] == .5 and old["focus_s"] == 40
    kernels = [[[input_hull(v) for v in row] for row in p[name]]
               for name in ["trust_matrix", "delay_matrix", "res_matrix"]]
    theta = [input_hull(v) for v in p["theta"]]
    alpha, beta = input_hull(old["alpha"]), input_hull(p["beta"])
    lambdas = [input_hull(v) for v in old["lambda"]]
    polys, ends = [], []
    for exposure in p["fou_strategy_scale"]:
        d = input_hull(cfg["delta"]) * input_hull(exposure)
        center = [Interval(0), Interval(2), -1-16*d*d, 32*d*d, -16*d*d]
        radius = [Interval(0), 8*d, -16*d, 8*d]
        polys.append([center, radius, [(i+1)*c for i, c in enumerate(center[1:])],
                      [(i+1)*c for i, c in enumerate(radius[1:])]])
        ends.append([[Interval(0), 1-4*d, 4*d], [Interval(0), 1+4*d, -4*d]])

    endpoint_lo, endpoint_hi = D(1), D(0)
    action_L = []
    for j in range(4):
        L = Interval(0)
        for k in range(3):
            lo = min(x.lo for x in kernels[k][j]); hi = max(x.hi for x in kernels[k][j])
            slope = D(0)
            for ep in ends[j]:
                values = polynomial_range(ep, lo, hi)
                endpoint_lo, endpoint_hi = min(endpoint_lo, values.lo), max(endpoint_hi, values.hi)
                gp = [2*ep[i] if i < 3 else Interval(0) for i in range(5)]
                for a in range(3):
                    for b in range(3):
                        gp[a+b] = gp[a+b]-ep[a]*ep[b]
                dp = [(i+1)*c for i, c in enumerate(gp[1:])]
                slope = max(slope, polynomial_range(dp, lo, hi).magnitude())
            L += theta[k]*(Interval(hi)-Interval(lo))*Interval(slope)/2
        action_L.append(L.hi)
    scalar_D = UP.add(*sorted(action_L, reverse=True)[:2])
    assert endpoint_lo > 0 and endpoint_hi < 1

    maxima, weighted_maxima = [D(0)]*2, [D(0)]*2
    gap_min, radius_margin, floor_margin = D(1), D(1), D(1)
    for index, vertices in enumerate(replay_cover(old["leaf_bounds"]), 1):
        center = [Interval(0) for _ in range(4)]
        radius = [Interval(0) for _ in range(4)]
        dC = [[Interval(0) for _ in PAIRS] for _ in range(4)]
        dR = [[Interval(0) for _ in PAIRS] for _ in range(4)]
        for j in range(4):
            for k in range(3):
                mu = [sum((Interval(v[l])*kernels[k][j][l] for l in range(4)), Interval(0))
                      for v in vertices]
                lo, hi = min(x.lo for x in mu), max(x.hi for x in mu)
                c, r, cp, rp = [polynomial_range(co, lo, hi) for co in polys[j]]
                center[j] += theta[k]*c; radius[j] += theta[k]*r
                for z, (a, b) in enumerate(PAIRS):
                    direction = kernels[k][j][a]-kernels[k][j][b]
                    dC[j][z] += theta[k]*cp*direction
                    dR[j][z] += theta[k]*rp*direction
        margin = min((radius[0]-radius[j]).lo for j in range(1, 4))
        floor = (radius[0]-Interval(".01")).lo
        assert margin > 0 and floor > 0  # Smooth max branch certified on every cell.
        radius_margin, floor_margin = min(radius_margin, margin), min(floor_margin, floor)
        nu, grad = [], []
        for j in range(4):
            if j == 0:
                penalty, derivative = radius[j], dR[j]
            else:
                ratio = radius[j]/radius[0]
                ratio = Interval(max(D(0), ratio.lo), min(D(1), ratio.hi))
                power = ratio**40
                power_next = power*ratio
                penalty = radius[j]*power
                derivative = [41*power*dR[j][z]-40*power_next*dR[0][z] for z in range(6)]
            nu.append(center[j]-(1-alpha)*penalty)
            grad.append([dC[j][z]-(1-alpha)*derivative[z] for z in range(6)])
        gap_min = min(gap_min, min((nu[1]-nu[j]).lo for j in [0, 2, 3]))
        H = [max((grad[j][z]-grad[k][z]).magnitude() for z in range(6)) for j, k in PAIRS]
        H = [(Interval(h)/2).hi for h in H]
        for ti, lam in enumerate(lambdas):
            probability = []
            for j in range(4):
                lower_exponent = [(Interval(nu[k].lo)-Interval(nu[j].hi))/lam
                                  for k in range(4) if k != j]
                denominator = 1+sum((z.exp() for z in lower_exponent), Interval(0))
                probability.append((Interval(1)/denominator).hi)
            weighted = Interval(0)
            for z, (j, k) in enumerate(PAIRS):
                gap = nu[j]-nu[k]
                distance = max(gap.lo, gap.hi.copy_negate(), D(0))
                u = (-Interval(distance)/lam).exp()
                pair = u/((1+u)**2)
                product = min((Interval(probability[j])*Interval(probability[k])).hi, pair.hi)
                weighted += Interval(product)*Interval(H[z])
            first = (Interval(max(H))/(2*lam)).hi
            second = (2*weighted/lam).hi
            maxima[ti] = max(maxima[ti], min(first, second))
            weighted_maxima[ti] = max(weighted_maxima[ti], second)
        if index % 500 == 0:
            print(f"Verified {index}/2184 exact-cover cells", flush=True)
    assert index == int(old["num_leaves"])
    reported_kappa = [D(".1660"), D(".8245")]
    reported_q = [D(".7498"), D(".9474")]
    q = [(1-beta+beta*Interval(v)).hi for v in maxima]
    assert all(a <= b < 1 for a, b in zip(maxima, reported_kappa))
    assert all(a <= b < 1 for a, b in zip(q, reported_q))
    assert scalar_D <= D(".1441") and gap_min >= D(".00566")
    result = {
        "status": "PASS", "decimal_precision": PRECISION, "rounding": "directed endpoints",
        "input_scope": "hull of exact MATLAB binary literals and declared decimal parameters",
        "model": "fixed Scenario B; alpha=.5; s=40; complete leave-one-out; four feasible actions",
        "cover": "exact rational replay of the complete binary bisection tree",
        "cover_leaves": index, "cover_volume_exact": "1", "kappa_upper": [str(v) for v in maxima],
        "q_upper": [str(v) for v in q], "weighted_bound_only_upper": [str(v) for v in weighted_maxima],
        "SP_gap_lower": str(gap_min), "SC_radius_gap_lower": str(radius_margin),
        "radius_floor_gap_lower": str(floor_margin), "scalar_D_uniform_alpha_upper": str(scalar_D),
        "membership_endpoints": [str(endpoint_lo), str(endpoint_hi)],
        "source_artifact_sha256": hashlib.sha256(artifact.read_bytes()).hexdigest(),
        "verifier_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "arithmetic_reference": "https://docs.python.org/3.12/library/decimal.html",
    }
    out = directory / "table/table5_6o_r3_certificate_audit.json"
    out.write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
