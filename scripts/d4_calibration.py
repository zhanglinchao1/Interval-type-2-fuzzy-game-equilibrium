#!/usr/bin/env python3
"""D4 external calibration (plan §五 D4 / §七 P7).

Reads seed-level metrics.csv trees produced by Chapter52MetricsLogger and:
  1. Compares the measured per-dimension membership half-width distribution
     (hw_trust / hw_delay / hw_res, sliding-window (max-min)/2) against the
     declared FOU half-width delta=0.20 — PASS if the Proposed median is the
     same order of magnitude (within [delta/3, 3*delta]).
  2. Checks the "high nominal payoff <=> high exposure" coupling direction:
     across the four strategies, per-strategy payoff dispersion (u_*_std)
     should increase with per-strategy mean payoff (Spearman-like sign check
     on aggregated per-node final snapshots, cooperative SC/DC vs selfish).

Outputs scripts/result_strong/d4_calibration_summary.csv and prints
[PASS]/[WARN] lines in the project's usual style.
"""

import csv
import glob
import os
import sys
from statistics import median

DELTA_DECLARED = 0.20
WARMUP_T = 120.0  # skip transient
EXP1_ROOT = "results/chapter52_strong/Chapter52_Exp1_Density_Strong"
EXP2_ROOT = "results/chapter52_strong/Chapter52_Exp2_Ablation_Strong"
OUT_CSV = "scripts/result_strong/d4_calibration_summary.csv"

STRATS = ["sc", "sp", "dc", "dp"]


def load_rows(run_dir):
    for path in glob.glob(os.path.join(run_dir, "*", "metrics.csv")):
        node = os.path.basename(os.path.dirname(path))
        with open(path) as fh:
            for r in csv.DictReader(fh):
                yield node, r


def collect(root):
    """per method: hw samples per dim + final per-strategy (n, mean, std) per node"""
    out = {}
    for run_dir in sorted(glob.glob(os.path.join(root, "Nv*_*_seed*"))):
        base = os.path.basename(run_dir)          # Nv150_Proposed_seed3
        try:
            method = base.split("_")[1]
        except IndexError:
            continue
        m = out.setdefault(method, {"hw": {"trust": [], "delay": [], "res": []},
                                    "strat_final": []})
        finals = {}
        for node, r in load_rows(run_dir):
            try:
                t = float(r["t_s"])
            except (KeyError, ValueError):
                continue
            if "hw_trust" not in r or r["hw_trust"] is None:
                continue
            if t >= WARMUP_T:
                for dim in ("trust", "delay", "res"):
                    v = float(r[f"hw_{dim}"])
                    if v > 0.0:
                        m["hw"][dim].append(v)
            # keep the last (largest t) row per node for cumulative strategy stats
            key = (run_dir, node)
            if key not in finals or t >= finals[key][0]:
                finals[key] = (t, r)
        for (_, node), (_, r) in finals.items():
            rec = {}
            for s in STRATS:
                try:
                    rec[s] = (int(float(r[f"u_{s}_n"])),
                              float(r[f"u_{s}_mean"]), float(r[f"u_{s}_std"]))
                except (KeyError, ValueError):
                    rec[s] = (0, 0.0, 0.0)
            m["strat_final"].append(rec)
    return out


def pooled_strategy_stats(strat_final):
    """aggregate per-strategy (weighted mean of means / stds) over nodes"""
    agg = {}
    for s in STRATS:
        n_tot, wm, ws = 0, 0.0, 0.0
        for rec in strat_final:
            n, mu, sd = rec[s]
            if n >= 2:
                n_tot += n
                wm += n * mu
                ws += n * sd
        agg[s] = (n_tot, wm / n_tot if n_tot else 0.0, ws / n_tot if n_tot else 0.0)
    return agg


def main():
    checks = []
    rows_out = []
    for label, root in (("exp1", EXP1_ROOT), ("exp2", EXP2_ROOT)):
        if not glob.glob(os.path.join(root, "Nv*_*_seed*")):
            print(f"WARN: no runs under {root}; skipping {label}")
            continue
        data = collect(root)
        for method, m in sorted(data.items()):
            med = {}
            for dim in ("trust", "delay", "res"):
                samples = m["hw"][dim]
                med[dim] = median(samples) if samples else 0.0
                rows_out.append({
                    "exp": label, "method": method, "kind": f"hw_{dim}",
                    "n": len(samples), "median": f"{med[dim]:.6f}",
                    "declared_delta": DELTA_DECLARED,
                })
            agg = pooled_strategy_stats(m["strat_final"])
            for s in STRATS:
                n, mu, sd = agg[s]
                rows_out.append({
                    "exp": label, "method": method, "kind": f"u_{s}",
                    "n": n, "median": f"{mu:.6f}", "declared_delta": f"{sd:.6f}",
                })
            if method == "Proposed":
                # check 1: half-width same order of magnitude as declared delta
                lo, hi = DELTA_DECLARED / 3.0, DELTA_DECLARED * 3.0
                ok = all(lo <= med[dim] <= hi for dim in ("trust", "delay", "res"))
                detail = ", ".join(f"{dim}={med[dim]:.3f}" for dim in ("trust", "delay", "res"))
                checks.append((f"D4.1[{label}] Proposed hw median in [{lo:.3f},{hi:.3f}] ({detail})", ok))
                # check 2: exposure coupling — sign of covariance between
                # per-strategy mean payoff and payoff std across strategies
                pts = [(agg[s][1], agg[s][2]) for s in STRATS if agg[s][0] > 0]
                if len(pts) >= 3:
                    mx = sum(p[0] for p in pts) / len(pts)
                    my = sum(p[1] for p in pts) / len(pts)
                    cov = sum((p[0] - mx) * (p[1] - my) for p in pts)
                    checks.append((f"D4.2[{label}] payoff-mean/std coupling cov={cov:+.2e} (>0 => high payoff = high exposure)", cov > 0))
                else:
                    checks.append((f"D4.2[{label}] insufficient strategy coverage ({len(pts)} strategies)", False))

    os.makedirs(os.path.dirname(OUT_CSV), exist_ok=True)
    with open(OUT_CSV, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["exp", "method", "kind", "n", "median", "declared_delta"])
        w.writeheader()
        w.writerows(rows_out)
    print(f"wrote {OUT_CSV}")

    print("\nD4 external calibration (delta declared = %.2f)" % DELTA_DECLARED)
    n_fail = 0
    for msg, ok in checks:
        print(f"[{'PASS' if ok else 'WARN'}] {msg}")
        if not ok:
            n_fail += 1
    sys.exit(0)   # D4 是标定观察，WARN 不阻断管线


if __name__ == "__main__":
    main()
