"""Rebuild the paper's Veins figures from the original 170 measured runs.

The seed CSV was exported from FuzzyVeins/results/chapter52_strong using
scripts/aggregate_chapter52_strong.py::run_record without modifying logs.
Its realized payoff averages each node's last valid logger window; its
model-payoff variance pools positive window means across nodes and times.
The legacy epsilon_violation_rate field is retained in the raw export only.
It is not a robust-deviation or contraction certificate.

Figure routines reuse scripts/plot_ch5_veins_figures.py. Statistics use
Student-t intervals and two-sided paired t tests across seeds 0--9.
"""

import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
import numpy as np
from scipy import stats

ROOT = Path(__file__).resolve().parent
TABLE = ROOT / "table"
OUT = ROOT.parent / "Latex"
if not OUT.is_dir():
    OUT = ROOT / "image"
METRICS = ("realized_uhat", "avg_var_uhat")
METHODS = {
    "exp1": ("Greedy", "FixedW", "Proposed"),
    "exp2": ("Proposed", "NoIT2", "NoGov", "NoWFBRI", "NoRobust"),
}
COLOR = {"Proposed": "#2a78d6", "Greedy": "#1baf7a", "FixedW": "#eda100",
         "NoIT2": "#008300", "NoGov": "#4a3aa7", "NoWFBRI": "#e87ba4",
         "NoRobust": "#eb6834"}
LABEL = {"Proposed": "Full", "Greedy": "Greedy", "FixedW": "FixedW",
         "NoIT2": "w/o IT2", "NoGov": "w/o Governance Feedback",
         "NoWFBRI": "w/o W-FBRI", "NoRobust": r"Midpoint ($\alpha=1$)"}
plt.rcParams.update({"font.family": "serif",
                     "font.serif": ["Times New Roman", "Liberation Serif"],
                     "mathtext.fontset": "stix", "font.size": 10,
                     "axes.linewidth": .8, "pdf.fonttype": 42})


def read_rows(path):
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def summarize():
    raw = read_rows(TABLE / "table5_7_veins_seed_metrics.csv")
    groups = {}
    for row in raw:
        key = row["experiment"], int(row["Nv"]), row["method"]
        seed = int(row["seed"])
        assert seed not in groups.setdefault(key, {}), "Duplicate seed"
        groups[key][seed] = row
    expected = {(e, n, m) for e in METHODS
                for n in ((50, 100, 150, 200) if e == "exp1" else (200,))
                for m in METHODS[e]}
    assert set(groups) == expected and len(raw) == 170
    assert all(set(g) == set(range(10)) for g in groups.values())
    output = {"exp1": [], "exp2": []}
    for (exp, nv, method), records in sorted(groups.items()):
        reference = groups[exp, nv, "Proposed"]
        row = dict(Nv=nv, method=method, n_seeds=len(records))
        for metric in METRICS:
            values = np.array([float(records[s][metric]) for s in range(10)])
            full = np.array([float(reference[s][metric]) for s in range(10)])
            assert np.isfinite(values).all()
            difference = full - values
            half = stats.t.ppf(.975, 9) * stats.sem(difference)
            row.update({metric + "_mean": values.mean(),
                        metric + "_std": values.std(ddof=1),
                        metric + "_ci95": stats.t.ppf(.975, 9) * stats.sem(values),
                        metric + "_p_vs_proposed":
                            1.0 if method == "Proposed" else stats.ttest_rel(full, values).pvalue,
                        metric + "_full_minus_variant": difference.mean(),
                        metric + "_paired_ci95_low": difference.mean() - half,
                        metric + "_paired_ci95_high": difference.mean() + half})
        output[exp].append(row)
    for exp, filename in (("exp1", "table5_7_density_summary.csv"),
                          ("exp2", "table5_10_ablation_summary.csv")):
        with (TABLE / filename).open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(output[exp][0]))
            writer.writeheader()
            writer.writerows(output[exp])
    return output


def save_both(fig, name):
    OUT.mkdir(parents=True, exist_ok=True)
    for extension in ("pdf", "png"):
        fig.savefig(OUT / (name + "." + extension), dpi=300,
                    bbox_inches="tight", pad_inches=.025)
    plt.close(fig)


def fig_density(rows):
    fig, axes = plt.subplots(2, 1, sharex=True, figsize=(4.2, 3.9),
                             layout="constrained")
    densities = [50, 100, 150, 200]
    for method, marker in zip(METHODS["exp1"], ("s", "^", "o")):
        series = [next(r for r in rows if r["Nv"] == n and r["method"] == method)
                  for n in densities]
        for ax, metric, scale in zip(axes, METRICS, (1, 1000)):
            values = [r[metric + "_mean"] * scale for r in series]
            errors = [r[metric + "_ci95"] * scale for r in series]
            ax.errorbar(densities, values, yerr=errors, color=COLOR[method],
                        marker=marker, markersize=4, linewidth=1.3, capsize=2)
            dy = {"Greedy": 0, "FixedW": -7, "Proposed": 7}[method]
            ax.annotate("Proposed" if method == "Proposed" else LABEL[method],
                        (200, values[-1]), xytext=(5, dy), textcoords="offset points",
                        color=COLOR[method], va="center", fontsize=9)
    axes[0].set_ylabel("Realized payoff")
    axes[1].set_ylabel("Model-payoff variance\n" + r"($\times 10^{-3}$)")
    axes[1].set_xlabel(r"Vehicle density $N_v$")
    axes[0].set_ylim(.590, .674)
    axes[1].set_ylim(6.15, 8.85)
    for i, ax in enumerate(axes):
        ax.set_xlim(40, 240)
        ax.set_xticks(densities)
        ax.spines[["top", "right"]].set_visible(False)
        ax.grid(axis="y", linestyle="--", linewidth=.5, alpha=.4)
        ax.text(.97, 1.01, "(a)" if i == 0 else "(b)", ha="right", va="bottom",
                transform=ax.transAxes, bbox=dict(facecolor="white", edgecolor="none", pad=1))
    save_both(fig, "fig5-19-density")


def fig_ablation(rows):
    fig, ax = plt.subplots(figsize=(8.0, 5.6), dpi=300)
    offsets = {"NoIT2": (12, -18, "left", True),
               "Proposed": (16, 4, "left", False),
               "NoRobust": (20, 40, "left", True),
               "NoWFBRI": (26, 16, "left", True),
               "NoGov": (-30, -28, "right", False)}
    for method in METHODS["exp2"]:
        row = next(r for r in rows if r["method"] == method)
        x, y = row["realized_uhat_mean"], row["avg_var_uhat_mean"] * 1000
        interval = ax.errorbar(x, y, xerr=row["realized_uhat_ci95"],
                              yerr=row["avg_var_uhat_ci95"] * 1000,
                              fmt="none", ecolor="0.6", elinewidth=1,
                              capsize=2, zorder=2)
        ax.scatter([x], [y], s=240, color=COLOR[method], edgecolors="0.2",
                   linewidths=1.2, alpha=.95, zorder=3)
        dx, dy, align, leader = offsets[method]
        arrow = dict(arrowstyle="-", color="0.5", lw=.8,
                     shrinkA=2, shrinkB=9) if leader else None
        label = "w/o Gov. feedback" if method == "NoGov" else LABEL[method]
        ax.annotate(label, (x, y), xytext=(dx, dy), textcoords="offset points",
                    ha=align, va="center", fontsize=14, color="0.1",
                    fontweight="bold", arrowprops=arrow, zorder=4)
    ax.set(xlim=(.585, .690), ylim=(6.00, 8.75))
    ax.set_xlabel("Realized payoff", fontsize=16, fontweight="bold")
    ax.set_ylabel("Model-payoff variance " + r"($\times 10^{-3}$)",
                  fontsize=16, fontweight="bold", labelpad=18)
    ax.tick_params(axis="both", labelsize=16)
    ax.spines[["top", "right"]].set_visible(False)
    ax.grid(linestyle="--", linewidth=.6, alpha=.35)
    mean_marker = Line2D([], [], marker="o", linestyle="none", color="0.2",
                         markerfacecolor="0.78", markersize=10)
    ax.legend([mean_marker, interval], ["10-seed mean", "95% t interval"],
              loc="center right", bbox_to_anchor=(.98, .53), fontsize=16,
              framealpha=.95, borderaxespad=.5)
    fig.tight_layout()
    save_both(fig, "fig5-20-frontier")


if __name__ == "__main__":
    results = summarize()
    fig_density(results["exp1"])
    fig_ablation(results["exp2"])
    for row in results["exp2"]:
        print(row["method"], "mean=", row["realized_uhat_mean"],
              "paired_p=", row["realized_uhat_p_vs_proposed"])
