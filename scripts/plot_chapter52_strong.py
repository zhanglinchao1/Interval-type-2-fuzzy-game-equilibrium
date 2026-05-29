#!/usr/bin/env python3
"""Plot strengthened Chapter 5.2 figures with confidence intervals."""

import argparse
import csv
import os
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams["font.family"] = "serif"
plt.rcParams["font.serif"] = ["Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"]
plt.rcParams["mathtext.fontset"] = "stix"

COLORS = {"Greedy": "#888888", "FixedW": "#ff7f0e", "Proposed": "#1f77b4"}
MARKERS = {"Greedy": "o", "FixedW": "s", "Proposed": "^"}
ABL_ORDER = ["Proposed", "NoIT2", "NoGov", "NoWFBRI", "NoRobust"]
ABL_LABEL = {
    "Proposed": "Full Proposed",
    "NoIT2": "w/o IT2",
    "NoGov": "w/o Governance",
    "NoWFBRI": "w/o W-FBRI",
    "NoRobust": "w/o Robust α-FNE",
}
ABL_COLORS = {
    "Proposed": "#1f77b4",
    "NoIT2": "#d62728",
    "NoGov": "#9467bd",
    "NoWFBRI": "#888888",
    "NoRobust": "#2ca02c",
}


def load_exp1(path):
    data = defaultdict(dict)
    if not os.path.isfile(path):
        return data
    with open(path) as f:
        for r in csv.DictReader(f):
            nv = int(r["Nv"])
            m = r["method"]
            data[m][nv] = r
    return data


def load_exp2(path):
    if not os.path.isfile(path):
        return {}
    with open(path) as f:
        return {r["method"]: r for r in csv.DictReader(f)}


def val(row, metric):
    return float(row[f"{metric}_mean"])


def err(row, metric):
    return float(row[f"{metric}_ci95"])


def save(fig, path):
    fig.tight_layout()
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"wrote {path}")


def plot_fig5_7(exp1, out):
    fig, ax = plt.subplots(figsize=(7.2, 4.6))
    for method in ["Greedy", "FixedW", "Proposed"]:
        if method not in exp1:
            continue
        nvs = sorted(exp1[method])
        ys = [val(exp1[method][n], "avg_p99_ms") for n in nvs]
        es = [err(exp1[method][n], "avg_p99_ms") for n in nvs]
        ax.errorbar(nvs, ys, yerr=es, marker=MARKERS[method], color=COLORS[method],
                    linewidth=2, capsize=4, label=method)
    ax.set_xlabel("Vehicle density $N_v$")
    ax.set_ylabel("p99 latency (ms)")
    ax.set_title("p99 Latency vs Vehicle Density")
    ax.grid(True, linestyle="--", alpha=0.45)
    ax.legend()
    save(fig, out)


def plot_exp1_metric(exp1, metric, ylabel, title, out):
    fig, ax = plt.subplots(figsize=(7.2, 4.6))
    for method in ["Greedy", "FixedW", "Proposed"]:
        if method not in exp1:
            continue
        nvs = sorted(exp1[method])
        ax.errorbar(nvs, [val(exp1[method][n], metric) for n in nvs],
                    yerr=[err(exp1[method][n], metric) for n in nvs],
                    marker=MARKERS[method], color=COLORS[method], linewidth=2,
                    capsize=4, label=method)
    ax.set_xlabel("Vehicle density $N_v$")
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.grid(True, linestyle="--", alpha=0.45)
    ax.legend()
    save(fig, out)


def bar_panel(ax, exp2, metric, title, ylabel):
    methods = [m for m in ABL_ORDER if m in exp2]
    x = np.arange(len(methods))
    ys = [val(exp2[m], metric) for m in methods]
    es = [err(exp2[m], metric) for m in methods]
    bars = ax.bar(x, ys, yerr=es, capsize=4, color=[ABL_COLORS[m] for m in methods],
                  edgecolor="black", linewidth=0.5)
    ax.set_xticks(x)
    ax.set_xticklabels([ABL_LABEL[m] for m in methods], rotation=15, ha="right", fontsize=9)
    ax.set_title(title)
    ax.set_ylabel(ylabel)
    ax.grid(True, linestyle="--", alpha=0.35, axis="y")
    for b, y in zip(bars, ys):
        ax.text(b.get_x() + b.get_width() / 2, y, f"{y:.3f}", ha="center", va="bottom", fontsize=8)


def plot_exp2_metric(exp2, metric, title, ylabel, out):
    fig, ax = plt.subplots(figsize=(7.2, 4.8))
    bar_panel(ax, exp2, metric, title, ylabel)
    save(fig, out)


def clean_old_pngs(out_dir):
    for name in os.listdir(out_dir):
        if name.endswith(".png"):
            os.remove(os.path.join(out_dir, name))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exp1-csv", default="results/chapter52_strong/exp1_summary.csv")
    ap.add_argument("--exp2-csv", default="results/chapter52_strong/exp2_summary.csv")
    ap.add_argument("--out-dir", default="scripts/result_strong")
    args = ap.parse_args()
    os.makedirs(args.out_dir, exist_ok=True)
    clean_old_pngs(args.out_dir)
    exp1 = load_exp1(args.exp1_csv)
    exp2 = load_exp2(args.exp2_csv)
    plot_fig5_7(exp1, os.path.join(args.out_dir, "fig5_7_density_delay.png"))
    plot_exp1_metric(exp1, "avg_pdr", "Packet delivery ratio",
                     "PDR vs Vehicle Density",
                     os.path.join(args.out_dir, "fig5_8_density_pdr.png"))
    plot_exp1_metric(exp1, "task_completion_rate", "Task completion rate",
                     "Task Completion vs Vehicle Density",
                     os.path.join(args.out_dir, "fig5_8_density_task_completion.png"))
    plot_exp1_metric(exp1, "raw_uhat", r"Raw payoff $\bar{\hat{U}}$",
                     "Raw Task Payoff vs Vehicle Density",
                     os.path.join(args.out_dir, "fig5_9_density_raw_payoff.png"))
    plot_exp1_metric(exp1, "effective_uhat", r"Effective payoff $\bar{\hat{U}}_{eff}$",
                     "Effective Task Payoff vs Vehicle Density",
                     os.path.join(args.out_dir, "fig5_9_density_effective_payoff.png"))
    plot_exp2_metric(exp2, "task_completion_rate", "Ablation Task Completion",
                     "rate", os.path.join(args.out_dir, "fig5_10_ablation_task_completion.png"))
    plot_exp2_metric(exp2, "avg_p99_ms", "Ablation p99 Latency",
                     "ms", os.path.join(args.out_dir, "fig5_10_ablation_p99_latency.png"))
    plot_exp2_metric(exp2, "effective_uhat", "Ablation Effective Payoff",
                     r"$\bar{\hat{U}}_{eff}$", os.path.join(args.out_dir, "fig5_10_ablation_effective_payoff.png"))
    plot_exp2_metric(exp2, "malicious_participation_rate", "Ablation Malicious Participation",
                     "rate", os.path.join(args.out_dir, "fig5_10_ablation_malicious_participation.png"))
    plot_exp2_metric(exp2, "avg_var_uhat", r"Ablation Var$_\xi(\hat{U})$",
                     "variance", os.path.join(args.out_dir, "fig5_11_ablation_payoff_variance.png"))
    plot_exp2_metric(exp2, "epsilon_violation_rate", r"Ablation $\epsilon_{req}$ Violation",
                     "rate", os.path.join(args.out_dir, "fig5_11_ablation_epsilon_violation.png"))
    plot_exp2_metric(exp2, "low_trust_participation_rate", "Ablation Low-Trust Participation",
                     "rate", os.path.join(args.out_dir, "fig5_11_ablation_low_trust_participation.png"))
    plot_exp2_metric(exp2, "avg_switches", "Ablation Strategy Switches",
                     "switches / bucket", os.path.join(args.out_dir, "fig5_11_ablation_strategy_switches.png"))


if __name__ == "__main__":
    main()
