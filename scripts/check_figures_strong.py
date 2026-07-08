#!/usr/bin/env python3
"""Validate strengthened Chapter 5.2 summaries against publication-oriented criteria."""

import csv
import os
import sys


def load(path):
    if not os.path.isfile(path):
        return []
    with open(path) as f:
        return list(csv.DictReader(f))


def v(row, metric):
    return float(row[f"{metric}_mean"])


def p(row, metric):
    return float(row[f"{metric}_p_vs_proposed"])


def main():
    exp1 = load("results/chapter52_strong/exp1_summary.csv")
    exp2 = load("results/chapter52_strong/exp2_summary.csv")
    idx1 = {}
    for r in exp1:
        idx1.setdefault(r["method"], {})[int(r["Nv"])] = r
    idx2 = {r["method"]: r for r in exp2}

    fails = []
    print("Strengthened Chapter 5.2 validation\n")

    exp1_methods = {"Greedy", "FixedW", "Proposed"}
    exp1_nvs = {50, 100, 150, 200}
    exp2_methods = {"Proposed", "NoIT2", "NoGov", "NoWFBRI", "NoRobust"}

    missing_exp1 = [
        f"{method}/Nv{nv}"
        for method in sorted(exp1_methods)
        for nv in sorted(exp1_nvs)
        if method not in idx1 or nv not in idx1[method]
    ]
    missing_exp2 = sorted(exp2_methods - set(idx2))

    if missing_exp1:
        fails.append("missing Exp1 rows: " + ", ".join(missing_exp1))
    if missing_exp2:
        fails.append("missing Exp2 rows: " + ", ".join(missing_exp2))

    low_seed_rows = [
        f"{r['method']}/Nv{r['Nv'] or '200'} has n_seeds={r.get('n_seeds', '0')}"
        for r in exp1 + exp2
        if int(r.get("n_seeds", "0") or 0) < 10
    ]
    if low_seed_rows:
        fails.append("incomplete full-batch seed count: " + "; ".join(low_seed_rows))

    # ------------------------------------------------------------------
    # E-checks verify the CLAIMS ACTUALLY MADE in the paper's Section V-B
    # against the measured summaries. They were recalibrated after the
    # integrity fix that removed the method-name-based "effective payoff"
    # adjustment: the old expectations (E1 >=2% gap, E2 Proposed >= Greedy
    # on payoff, E4 governance payoff advantage) tested claims the paper
    # no longer makes because they were artifacts of the fabricated metric.
    # Each check below cites the revised prose it verifies.
    # ------------------------------------------------------------------

    # E1 -- claim: "Proposed ... exceeds Greedy at every density, by +4.3% to
    # +6.8% (paired p<=4.7e-4 at all four densities, surviving Holm)". Check:
    # realized payoff P > Greedy at every density, Holm-significant at 4/4.
    if "Proposed" in idx1 and "Greedy" in idx1:
        nvs = sorted(set(idx1["Proposed"]) & set(idx1["Greedy"]))
        gaps, pvals = [], []
        for nv in nvs:
            gp = v(idx1["Proposed"][nv], "realized_uhat") - v(idx1["Greedy"][nv], "realized_uhat")
            gaps.append(gp / max(v(idx1["Greedy"][nv], "realized_uhat"), 1e-9))
            pvals.append(p(idx1["Greedy"][nv], "realized_uhat"))
        holm = sorted(range(len(pvals)), key=lambda i: pvals[i])
        n_sig = 0
        for rank, i in enumerate(holm):
            if pvals[i] * (len(pvals) - rank) <= 0.05:
                n_sig += 1
            else:
                break
        avg_gap = sum(gaps) / len(gaps) if gaps else 0.0
        ok = all(g > 0 for g in gaps) and n_sig == len(pvals)
        print(f"E1 realized payoff Proposed vs Greedy: avg gap={avg_gap:.3%}, "
              f"positive at {sum(g > 0 for g in gaps)}/{len(gaps)} densities, "
              f"Holm-significant at {n_sig}/{len(pvals)}: {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append("Proposed vs Greedy realized payoff not uniformly positive/significant")

    # E2 -- claim: "Greedy's payoff variance is ... 29% above Proposed's
    # (paired p<1e-10)" and "violation ratio at 2.0--2.8%, within the nominal
    # 5% budget" and "task completion stays in 0.939--0.961".
    for nv in [150, 200]:
        if "Proposed" in idx1 and "Greedy" in idx1 and nv in idx1["Proposed"] and nv in idx1["Greedy"]:
            tp = v(idx1["Proposed"][nv], "task_completion_rate")
            var_p = v(idx1["Proposed"][nv], "avg_var_uhat")
            var_g = v(idx1["Greedy"][nv], "avg_var_uhat")
            pv = p(idx1["Greedy"][nv], "avg_var_uhat")
            viol = v(idx1["Proposed"][nv], "epsilon_violation_rate")
            tg = v(idx1["Greedy"][nv], "task_completion_rate")
            ptask = p(idx1["Greedy"][nv], "task_completion_rate")
            ok = var_p < var_g and pv <= 0.05 and viol <= 0.05 and tp > tg and ptask <= 0.05
            print(f"E2 Nv={nv} Proposed var={var_p:.6f} < Greedy var={var_g:.6f} (p={pv:.2e}), "
                  f"violation={viol:.3f}<=5%, task P={tp:.3f} > GR={tg:.3f} (p={ptask:.2e}): {'PASS' if ok else 'FAIL'}")
            if not ok:
                fails.append(f"Nv={nv} variance/certificate/completion claim not met")

    # E3 -- claim: robust alpha-FNE keeps the violation ratio near nominal
    # while its removal saturates it (unchanged from the original check).
    if "Proposed" in idx2 and "NoRobust" in idx2:
        full = v(idx2["Proposed"], "epsilon_violation_rate")
        norob = v(idx2["NoRobust"], "epsilon_violation_rate")
        drop = (norob - full) / max(norob, 1e-9)
        ok = drop >= 0.30
        print(f"E3 epsilon violation reduction vs NoRobust={drop:.3%}: {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append("epsilon violation reduction < 30%")

    # E4 -- claim: "removing the governance weight update leaves the
    # certificate intact" and is "payoff-neutral in this scenario" (the paper
    # explicitly does NOT claim a scenario-level payoff advantage for
    # governance). Check: |payoff difference| not significant AND NoGov
    # violation <= 5% AND Full violation <= 5%.
    if "Proposed" in idx2 and "NoGov" in idx2:
        full_u = v(idx2["Proposed"], "realized_uhat")
        nogov_u = v(idx2["NoGov"], "realized_uhat")
        pv = p(idx2["NoGov"], "realized_uhat")
        viol_full = v(idx2["Proposed"], "epsilon_violation_rate")
        viol_nogov = v(idx2["NoGov"], "epsilon_violation_rate")
        ok = pv > 0.05 and viol_full <= 0.05 and viol_nogov <= 0.05
        print(f"E4 governance payoff-neutrality Full={full_u:.4f} NoGov={nogov_u:.4f} "
              f"(p={pv:.4f}, expected n.s.), violations Full={viol_full:.3f}/NoGov={viol_nogov:.3f}<=5%: "
              f"{'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append("governance payoff-neutrality/certificate claim not met")

    # E5 -- claim: "Removing W-FBRI's damped soft response ... drops to 0.597
    # (-8.9%, p<1e-10)". Check: NoWFBRI realized payoff significantly below Full.
    if "Proposed" in idx2 and "NoWFBRI" in idx2:
        full_u = v(idx2["Proposed"], "realized_uhat")
        nowf_u = v(idx2["NoWFBRI"], "realized_uhat")
        pv = p(idx2["NoWFBRI"], "realized_uhat")
        ok = nowf_u < full_u and pv <= 0.05
        print(f"E5 W-FBRI damping effect: Full={full_u:.4f} > NoWFBRI={nowf_u:.4f} "
              f"(p={pv:.2e}): {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append("W-FBRI realized payoff effect not significant")

    print()
    if fails:
        print(f"FAILED {len(fails)} checks")
        for item in fails:
            print(f"- {item}")
    else:
        print("ALL STRENGTHENED CHECKS PASS")
    sys.exit(len(fails))


if __name__ == "__main__":
    main()
