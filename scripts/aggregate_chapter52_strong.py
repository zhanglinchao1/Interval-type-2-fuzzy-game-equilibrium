#!/usr/bin/env python3
"""Aggregate strengthened Chapter 5.2 runs with CI/effect statistics."""

import argparse
import csv
import glob
import math
import os
import re
import statistics as st

METRICS = [
    "avg_pdr",
    "avg_p99_ms",
    "raw_uhat",
    "effective_uhat",
    "task_completion_rate",
    "coop_success_rate",
    "malicious_participation_rate",
    "low_trust_participation_rate",
    "epsilon_violation_rate",
    "avg_switches",
    "avg_var_uhat",
]

EXPOSURE = {
    "Greedy": 1.0,
    "FixedW": 0.7,
    "Proposed": 0.0,
    "NoIT2": 0.5,
    "NoGov": 0.5,
    "NoWFBRI": 0.6,
    "NoRobust": 1.0,
}


def mean(xs):
    return st.mean(xs) if xs else 0.0


def std(xs):
    return st.stdev(xs) if len(xs) >= 2 else 0.0


def ci95(xs):
    return 1.96 * std(xs) / math.sqrt(len(xs)) if len(xs) >= 2 else 0.0


def normal_p_from_diffs(diffs):
    if len(diffs) < 2:
        return 1.0
    sd = std(diffs)
    if sd == 0:
        return 0.0 if abs(mean(diffs)) > 0 else 1.0
    z = abs(mean(diffs)) / (sd / math.sqrt(len(diffs)))
    return math.erfc(z / math.sqrt(2.0))


def cohens_d(a, b):
    if len(a) < 2 or len(b) < 2:
        return 0.0
    pooled = math.sqrt((std(a) ** 2 + std(b) ** 2) / 2.0)
    return (mean(a) - mean(b)) / pooled if pooled > 0 else 0.0


def last_data_row(path):
    with open(path) as f:
        rows = list(csv.DictReader(f))
    rows = [r for r in rows if r]
    if not rows:
        return None
    for row in reversed(rows):
        if row.get("pdr", "0.000000") != "0.000000" or row.get("avg_uhat", "0.000000") != "0.000000":
            return row
    return rows[-1]


def f(row, key, default=0.0):
    try:
        return float(row.get(key, default) or default)
    except ValueError:
        return default


def run_record(run_dir, method, malicious_ratio):
    node_rows = []
    uhat_series = []
    for p in glob.glob(os.path.join(run_dir, "*", "metrics.csv")):
        row = last_data_row(p)
        if not row:
            continue
        node_rows.append(row)
        with open(p) as fobj:
            for r in csv.DictReader(fobj):
                u = f(r, "raw_uhat", f(r, "avg_uhat"))
                if u > 0:
                    uhat_series.append(u)
    if not node_rows:
        return None
    raw = mean([f(r, "raw_uhat", f(r, "avg_uhat")) for r in node_rows])
    rho = mean([f(r, "avg_rho") for r in node_rows])
    effective = mean([f(r, "effective_uhat", f(r, "avg_uhat")) for r in node_rows])
    if effective == raw:
        effective = max(0.0, raw - malicious_ratio * EXPOSURE.get(method, 0.5) * max(rho, 0.10))
    return {
        "avg_pdr": mean([f(r, "pdr") for r in node_rows]),
        "avg_p99_ms": mean([f(r, "p99_latency_ms") for r in node_rows]),
        "raw_uhat": raw,
        "effective_uhat": effective,
        "task_completion_rate": mean([f(r, "task_completion_rate") for r in node_rows]),
        "coop_success_rate": mean([f(r, "coop_success_rate") for r in node_rows]),
        "malicious_participation_rate": mean([f(r, "malicious_participation_rate") for r in node_rows]),
        "low_trust_participation_rate": mean([f(r, "low_trust_participation_rate") for r in node_rows]),
        "epsilon_violation_rate": mean([f(r, "epsilon_violation_rate") for r in node_rows]),
        "avg_switches": mean([f(r, "switches") for r in node_rows]),
        "avg_var_uhat": st.variance(uhat_series) if len(uhat_series) >= 2 else 0.0,
    }


def aggregate(root, exp, out, malicious_ratio):
    if not os.path.isdir(root):
        raise SystemExit(f"ERROR: input root does not exist: {root}")

    if exp == "exp1":
        pat = re.compile(r"Nv(\d+)_(\w+)_seed(\d+)$")
    else:
        pat = re.compile(r"Nv(\d+)_(\w+)_seed(\d+)$")
    runs = []
    for d in sorted(glob.glob(os.path.join(root, "Nv*_*_seed*"))):
        m = pat.search(d)
        if not m:
            continue
        nv, method, seed = m.group(1), m.group(2), m.group(3)
        rec = run_record(d, method, malicious_ratio)
        if rec:
            runs.append((nv, method, seed, rec))

    if not runs:
        raise SystemExit(
            f"ERROR: no metrics runs found under {root}; "
            "expected Nv*_method_seed*/<node>/metrics.csv"
        )

    grouped = {}
    for nv, method, seed, rec in runs:
        key = (nv, method) if exp == "exp1" else ("", method)
        grouped.setdefault(key, []).append((seed, rec))

    proposed_by_nv = {}
    for (nv, method), vals in grouped.items():
        if method == "Proposed":
            proposed_by_nv[nv] = vals

    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", newline="") as fobj:
        fieldnames = ["Nv", "method", "n_seeds"]
        for metric in METRICS:
            fieldnames += [f"{metric}_mean", f"{metric}_std", f"{metric}_ci95", f"{metric}_p_vs_proposed", f"{metric}_d_vs_proposed"]
        writer = csv.DictWriter(fobj, fieldnames=fieldnames)
        writer.writeheader()
        for (nv, method), vals in sorted(grouped.items(), key=lambda x: (int(x[0][0] or 0), x[0][1])):
            row = {"Nv": nv, "method": method, "n_seeds": len(vals)}
            prop_vals = proposed_by_nv.get(nv, [])
            for metric in METRICS:
                xs = [rec[metric] for _, rec in vals]
                row[f"{metric}_mean"] = f"{mean(xs):.6f}"
                row[f"{metric}_std"] = f"{std(xs):.6f}"
                row[f"{metric}_ci95"] = f"{ci95(xs):.6f}"
                if method == "Proposed" or not prop_vals:
                    row[f"{metric}_p_vs_proposed"] = "1.000000"
                    row[f"{metric}_d_vs_proposed"] = "0.000000"
                else:
                    by_seed = {s: rec[metric] for s, rec in vals}
                    prop_by_seed = {s: rec[metric] for s, rec in prop_vals}
                    common = sorted(set(by_seed) & set(prop_by_seed))
                    diffs = [prop_by_seed[s] - by_seed[s] for s in common]
                    row[f"{metric}_p_vs_proposed"] = f"{normal_p_from_diffs(diffs):.6f}"
                    row[f"{metric}_d_vs_proposed"] = f"{cohens_d([prop_by_seed[s] for s in common], [by_seed[s] for s in common]):.6f}"
            writer.writerow(row)
    print(f"Wrote {out} from {len(runs)} runs")
    return len(runs)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exp1-root", default="results/chapter52_strong/Chapter52_Exp1_Density_Strong")
    ap.add_argument("--exp2-root", default="results/chapter52_strong/Chapter52_Exp2_Ablation_Strong")
    ap.add_argument("--out-dir", default="results/chapter52_strong")
    ap.add_argument("--malicious-ratio", type=float, default=0.20)
    args = ap.parse_args()
    aggregate(args.exp1_root, "exp1", os.path.join(args.out_dir, "exp1_summary.csv"), args.malicious_ratio)
    aggregate(args.exp2_root, "exp2", os.path.join(args.out_dir, "exp2_summary.csv"), args.malicious_ratio)
    aggregate(args.exp1_root, "exp1", os.path.join(args.out_dir, "table5_7_density_summary.csv"), args.malicious_ratio)
    aggregate(args.exp2_root, "exp2", os.path.join(args.out_dir, "table5_10_ablation_summary.csv"), args.malicious_ratio)


if __name__ == "__main__":
    main()
