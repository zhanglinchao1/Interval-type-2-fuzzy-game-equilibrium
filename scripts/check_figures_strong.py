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

    if "Proposed" in idx1 and "FixedW" in idx1:
        gaps = []
        for nv in sorted(set(idx1["Proposed"]) & set(idx1["FixedW"])):
            gp = v(idx1["Proposed"][nv], "effective_uhat") - v(idx1["FixedW"][nv], "effective_uhat")
            gaps.append(gp / max(v(idx1["FixedW"][nv], "effective_uhat"), 1e-9))
        avg_gap = sum(gaps) / len(gaps) if gaps else 0.0
        ok = avg_gap >= 0.02
        print(f"E1 effective payoff Proposed vs FixedW avg relative gap={avg_gap:.3%}: {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append("effective payoff gap < 2%")

    for nv in [150, 200]:
        if "Proposed" in idx1 and "Greedy" in idx1 and nv in idx1["Proposed"] and nv in idx1["Greedy"]:
            tp = v(idx1["Proposed"][nv], "task_completion_rate")
            up = v(idx1["Proposed"][nv], "effective_uhat")
            ug = v(idx1["Greedy"][nv], "effective_uhat")
            pv = p(idx1["Greedy"][nv], "effective_uhat")
            ok = tp >= 0.95 and up >= ug
            print(f"E2 Nv={nv} task completion={tp:.3f}, effective payoff Proposed={up:.3f} Greedy={ug:.3f} p={pv:.4f}: {'PASS' if ok else 'FAIL'}")
            if not ok:
                fails.append(f"Nv={nv} high-density task/payoff expectation not met")

    if "Proposed" in idx2 and "NoRobust" in idx2:
        full = v(idx2["Proposed"], "epsilon_violation_rate")
        norob = v(idx2["NoRobust"], "epsilon_violation_rate")
        drop = (norob - full) / max(norob, 1e-9)
        ok = drop >= 0.30
        print(f"E3 epsilon violation reduction vs NoRobust={drop:.3%}: {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append("epsilon violation reduction < 30%")

    if "Proposed" in idx2 and "NoGov" in idx2:
        full = v(idx2["Proposed"], "effective_uhat")
        nogov = v(idx2["NoGov"], "effective_uhat")
        pv = p(idx2["NoGov"], "effective_uhat")
        ok = full >= nogov and pv <= 0.05
        print(f"E4 governance effective payoff Proposed={full:.3f} NoGov={nogov:.3f} p={pv:.4f}: {'PASS' if ok else 'FAIL'}")
        if not ok:
            fails.append("governance effective payoff not significant")

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
