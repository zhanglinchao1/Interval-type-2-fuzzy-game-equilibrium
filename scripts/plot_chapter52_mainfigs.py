#!/usr/bin/env python3
"""Plot compact, publication-quality main-text figures for Chapter 5.2.

Produces three merged figures referenced by code/chapter5.2.md:
  fig5_7_density_main.png       density: task completion + effective payoff + Proposed p99 (single twin-axis)
  fig5_8_ablation_main.png      ablation study, single chart: task completion + effective payoff +
                                epsilon_req violation (left axis) and payoff variance (right axis)

Data source (code-based ground truth, produced by aggregate_chapter52_strong.py):
  results/chapter52_strong/exp1_summary.csv
  results/chapter52_strong/exp2_summary.csv
"""

import argparse
import csv
import os
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.transforms import blended_transform_factory
import numpy as np


plt.rcParams["font.family"] = "serif"
plt.rcParams["font.serif"] = ["Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"]
plt.rcParams["mathtext.fontset"] = "stix"
plt.rcParams["axes.linewidth"] = 0.9
plt.rcParams["savefig.dpi"] = 300

METHODS = ["Greedy", "FixedW", "Proposed"]
COLORS = {"Greedy": "#777777", "FixedW": "#d95f02", "Proposed": "#1f77b4"}
MARKERS = {"Greedy": "o", "FixedW": "s", "Proposed": "^"}

ABL_ORDER = ["Proposed", "NoIT2", "NoGov", "NoWFBRI", "NoRobust"]
ABL_LABEL = {
    "Proposed": "Full",
    "NoIT2": "w/o IT2",
    "NoGov": "w/o Gov.",
    "NoWFBRI": "w/o W-FBRI",
    "NoRobust": "w/o Robust",
}

C_TASK = "#3c6ea5"   # task completion (left axis, fig 5-8)
C_PAY = "#e07b1a"    # effective payoff (right axis, fig 5-8)
C_VAR = "#2ca02c"    # payoff variance (left axis, fig 5-9)
C_EPS = "#d62728"    # epsilon violation (right axis, fig 5-9)


def load_exp1(path):
    data = defaultdict(dict)
    with open(path) as fobj:
        for row in csv.DictReader(fobj):
            data[row["method"]][int(row["Nv"])] = row
    return data


def load_exp2(path):
    with open(path) as fobj:
        return {row["method"]: row for row in csv.DictReader(fobj)}


def val(row, metric):
    return float(row[f"{metric}_mean"])


def err(row, metric):
    return float(row[f"{metric}_ci95"])


def save(fig, path):
    fig.savefig(path, dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"wrote {path}")


# ----------------------------------------------------------------------------
# Figure 5-7: density performance (single chart, twin axis)
# ----------------------------------------------------------------------------
def plot_density_main(exp1, out_path):
    fig, ax = plt.subplots(figsize=(8.4, 5.4))
    ax2 = ax.twinx()

    nvs = sorted(exp1["Proposed"])

    # faint background bands separating the two left-axis metric families
    ax.axhspan(0.958, 1.012, color=C_TASK, alpha=0.06, zorder=0)
    ax.axhspan(0.552, 0.618, color=C_PAY, alpha=0.06, zorder=0)

    # effective payoff: solid line + filled marker
    for method in METHODS:
        x = sorted(exp1[method])
        ax.errorbar(
            x,
            [val(exp1[method][n], "effective_uhat") for n in x],
            yerr=[err(exp1[method][n], "effective_uhat") for n in x],
            color=COLORS[method], marker=MARKERS[method], markersize=7,
            linestyle="-", linewidth=2.2, capsize=3, zorder=4,
            markerfacecolor=COLORS[method], markeredgecolor="white", markeredgewidth=0.6,
        )

    # task completion: dashed line + open marker
    for method in METHODS:
        x = sorted(exp1[method])
        ax.errorbar(
            x,
            [val(exp1[method][n], "task_completion_rate") for n in x],
            yerr=[err(exp1[method][n], "task_completion_rate") for n in x],
            color=COLORS[method], marker=MARKERS[method], markersize=7,
            linestyle="--", linewidth=1.8, capsize=3, alpha=0.95, zorder=4,
            markerfacecolor="white", markeredgecolor=COLORS[method], markeredgewidth=1.3,
        )

    # Proposed p99 latency on the right axis
    p99 = [val(exp1["Proposed"][n], "avg_p99_ms") for n in nvs]
    p99e = [err(exp1["Proposed"][n], "avg_p99_ms") for n in nvs]
    ax2.errorbar(
        nvs, p99, yerr=p99e, color="#111111", marker="D", markersize=6,
        linestyle=":", linewidth=2.0, capsize=3, zorder=5,
        markerfacecolor="#111111", markeredgecolor="white", markeredgewidth=0.6,
    )
    # per-point label offsets so values never sit on the marker / dashed lines
    p99_offsets = {nvs[0]: (-2, 11), nvs[1]: (-2, 11), nvs[2]: (0, -17), nvs[3]: (2, 11)}
    p99_box = dict(boxstyle="round,pad=0.15", fc="white", ec="none", alpha=0.85)
    for xx, yy in zip(nvs, p99):
        off = p99_offsets.get(xx, (0, 11))
        ax2.annotate(f"{yy:.3f}", (xx, yy), textcoords="offset points",
                     xytext=off, ha="center", fontsize=8, color="#111111",
                     bbox=p99_box, zorder=7)

    # band labels (x in axes fraction, y in data coords)
    trans = blended_transform_factory(ax.transAxes, ax.transData)
    label_box = dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.75)
    ax.text(0.015, 1.005, "Task completion rate", transform=trans, fontsize=9,
            style="italic", color=C_TASK, va="center", ha="left", bbox=label_box, zorder=6)
    ax.text(0.015, 0.559, r"Effective payoff $\bar{\hat{U}}_{eff}$", transform=trans, fontsize=9,
            style="italic", color=C_PAY, va="center", ha="left", bbox=label_box, zorder=6)

    ax.set_xlabel(r"Vehicle density $N_v$", fontsize=11)
    ax.set_ylabel(r"Task completion rate / effective payoff", fontsize=11)
    ax2.set_ylabel("Proposed p99 latency (ms)", fontsize=11)
    ax.set_xticks(nvs)
    ax.set_xlim(38, 212)
    ax.set_ylim(0.55, 1.02)
    ax2.set_ylim(0.40, 0.60)
    ax.grid(True, linestyle="--", alpha=0.3)
    ax.set_title("Density Performance: Task Viability, Effective Payoff, and Tail Latency",
                 fontsize=12, pad=10)

    # compact legends below the axes: method (color/marker) + encoding (line style / axis)
    method_handles = [
        Line2D([0], [0], color=COLORS[m], marker=MARKERS[m], linestyle="-",
               markersize=7, linewidth=2.0, label=m) for m in METHODS
    ]
    encoding_handles = [
        Line2D([0], [0], color="#444444", linestyle="-", linewidth=2.0,
               marker="o", markerfacecolor="#444444", markeredgecolor="white",
               markersize=6, label="Effective payoff (left)"),
        Line2D([0], [0], color="#444444", linestyle="--", linewidth=1.8,
               marker="o", markerfacecolor="white", markeredgecolor="#444444",
               markersize=6, label="Task completion (left)"),
        Line2D([0], [0], color="#111111", linestyle=":", linewidth=2.0,
               marker="D", markerfacecolor="#111111", markeredgecolor="white",
               markersize=6, label="Proposed p99 (right)"),
    ]
    leg1 = ax.legend(handles=method_handles, loc="upper left", bbox_to_anchor=(0.0, -0.12),
                     ncol=3, frameon=True, fontsize=9, title="Method", title_fontsize=9)
    ax.add_artist(leg1)
    ax.legend(handles=encoding_handles, loc="upper right", bbox_to_anchor=(1.0, -0.12),
              ncol=1, frameon=True, fontsize=9, title="Encoding", title_fontsize=9)

    save(fig, out_path)


# ----------------------------------------------------------------------------
# Figure 5-8: merged ablation study -- single chart, grouped bars + twin axis
#   left axis  : task completion, effective payoff, epsilon_req violation (all in [0,1])
#   right axis : payoff variance (x10^-4)
# ----------------------------------------------------------------------------
def plot_ablation_single(exp2, out_path):
    methods = [m for m in ABL_ORDER if m in exp2]
    x = np.arange(len(methods))
    w = 0.2

    comp = [val(exp2[m], "task_completion_rate") for m in methods]
    comp_e = [err(exp2[m], "task_completion_rate") for m in methods]
    pay = [val(exp2[m], "effective_uhat") for m in methods]
    pay_e = [err(exp2[m], "effective_uhat") for m in methods]
    eps = [val(exp2[m], "epsilon_violation_rate") for m in methods]
    eps_e = [err(exp2[m], "epsilon_violation_rate") for m in methods]
    var = [val(exp2[m], "avg_var_uhat") * 1e4 for m in methods]
    var_e = [err(exp2[m], "avg_var_uhat") * 1e4 for m in methods]

    fig, ax = plt.subplots(figsize=(10.6, 6.0))
    ax2 = ax.twinx()

    ax.bar(x - 1.5 * w, comp, w, yerr=comp_e, capsize=2.5, color=C_TASK,
           edgecolor="black", linewidth=0.5, label="Task completion (L)")
    ax.bar(x - 0.5 * w, pay, w, yerr=pay_e, capsize=2.5, color=C_PAY,
           edgecolor="black", linewidth=0.5, label=r"Effective payoff $\bar{\hat{U}}_{eff}$ (L)")
    ax.bar(x + 0.5 * w, eps, w, yerr=eps_e, capsize=2.5, color=C_EPS, alpha=0.8,
           edgecolor="#8b1a1a", linewidth=0.6, hatch="//", label=r"$\epsilon_{\mathrm{req}}$ violation (L)")
    ax2.bar(x + 1.5 * w, var, w, yerr=var_e, capsize=2.5, color=C_VAR, alpha=0.75,
            edgecolor="#1b5e20", linewidth=0.5, label=r"Payoff variance (R, $\times10^{-4}$)")

    ax.set_ylim(0.0, 1.20)
    ax2.set_ylim(5.0, 9.2)

    def vlabel(axis, xpos, ytop, text, color):
        axis.text(xpos, ytop, text, ha="center", va="bottom", rotation=90,
                  fontsize=7, color=color)

    for xpos, y, e in zip(x - 1.5 * w, comp, comp_e):
        vlabel(ax, xpos, y + e + 0.012, f"{y:.3f}", C_TASK)
    for xpos, y, e in zip(x - 0.5 * w, pay, pay_e):
        vlabel(ax, xpos, y + e + 0.012, f"{y:.3f}", "#b35900")
    for xpos, y in zip(x + 0.5 * w, eps):
        vlabel(ax, xpos, max(y, 0.0) + 0.012, ("0" if y <= 1e-9 else f"{y:.1f}"), "#8b1a1a")
    for xpos, y, e in zip(x + 1.5 * w, var, var_e):
        vlabel(ax2, xpos, y + e + 0.05, f"{y:.2f}", "#1b5e20")

    ax.set_xticks(x)
    ax.set_xticklabels([ABL_LABEL[m] for m in methods], rotation=12, ha="right", fontsize=10)
    ax.set_xlabel("Ablation variant", fontsize=11)
    ax.set_ylabel("Rate / effective payoff  (dimensionless, [0,1])", fontsize=10.5)
    ax2.set_ylabel(r"Payoff variance Var$_\xi(\hat{U})$ ($\times 10^{-4}$)", color="#1b5e20", fontsize=10.5)
    ax2.tick_params(axis="y", labelcolor="#1b5e20")
    ax.grid(True, linestyle="--", alpha=0.3, axis="y")
    ax.set_axisbelow(True)
    ax.set_title(r"Ablation Study at $N_v = 200$: Performance and Robustness", fontsize=12.5, pad=10)

    h1, l1 = ax.get_legend_handles_labels()
    h2, l2 = ax2.get_legend_handles_labels()
    ax.legend(h1 + h2, l1 + l2, loc="upper center", bbox_to_anchor=(0.5, -0.13),
              ncol=4, frameon=True, fontsize=8.5)

    save(fig, out_path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exp1-csv", default="results/chapter52_strong/exp1_summary.csv")
    ap.add_argument("--exp2-csv", default="results/chapter52_strong/exp2_summary.csv")
    ap.add_argument("--out-dir", default="scripts/hebing_result_strong")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    exp1 = load_exp1(args.exp1_csv)
    exp2 = load_exp2(args.exp2_csv)

    plot_density_main(exp1, os.path.join(args.out_dir, "fig5_7_density_main.png"))
    plot_ablation_single(exp2, os.path.join(args.out_dir, "fig5_8_ablation_main.png"))


if __name__ == "__main__":
    main()
