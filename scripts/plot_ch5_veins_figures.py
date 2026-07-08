#!/usr/bin/env python3
"""Paper Veins figures from measured seed-level data ONLY.

Every plotted quantity is a direct simulation measurement aggregated by
scripts/aggregate_chapter52_strong.py (which, after the integrity fix, applies
no method-name-based adjustment of any kind):
    realized_uhat_mean / _ci95       window-mean of the REALIZED payoff: cooperative
                                     windows whose engaged partner is abnormal yield 0
                                     (threat-model realization, plan sec.3 / Table VII
                                     20% abnormal vehicles); identical mechanism for
                                     every method
    raw_uhat_mean / _ci95            window-mean of the model payoff U-hat
    avg_var_uhat_mean / _ci95        variance of the measured U-hat series
    epsilon_violation_rate_mean      measured violation ratio of the
                                     epsilon_req <= 2(1-alpha)*rho budget
    task_completion_rate_mean        measured task completion

Outputs:
    code/Latex/fig5-19-density.png   Scenario I, two aligned panels
                                     (a) mean payoff vs density
                                     (b) payoff variance vs density
    code/Latex/fig5-20-frontier.png  payoff-variance frontier at Nv=200 with a
                                     three-state certificate encoding

Certificate marker encoding (fig5-20). The three states are *structural
categories of the decision rule*, not tuned numbers:
    certified  -- an uncertainty budget 2(1-alpha)*rho > 0 is active and the
                  measured violation ratio stays at/below the nominal 5%
    vacuous    -- the method plays a hard (argmax) best response, so
                  epsilon_req == 0 identically and the certificate check
                  cannot bind (Greedy: additionally delta=0 so the budget
                  itself is undefined; w/o W-FBRI: budget exists but the
                  response is never soft) -- shown as "no certificate"
    violated   -- the budget collapses to zero (delta=0 or alpha=1) while the
                  response remains stochastic, so essentially every check
                  fails (measured ratio = 1.000)

Font: Times New Roman requested; on hosts without it matplotlib falls back to
Liberation Serif, which is metric-compatible with Times New Roman (Nimbus
Roman is Type-1 and not loadable by matplotlib). Math uses STIX (Times-like).
"""

import csv
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

plt.rcParams.update({
    "font.family": "serif",
    "font.serif": ["Times New Roman", "Liberation Serif", "DejaVu Serif"],
    "mathtext.fontset": "stix",
    "font.size": 12,
    "axes.linewidth": 0.9,
    "figure.facecolor": "white",
    "axes.facecolor": "white",
    "savefig.facecolor": "white",
})

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
EXP1_CSV = os.path.join(ROOT, "results/chapter52_strong/exp1_summary.csv")
EXP2_CSV = os.path.join(ROOT, "results/chapter52_strong/exp2_summary.csv")
OUT_DIR = os.path.join(ROOT, "code/Latex")

# Fixed categorical palette (validated, CVD-safe order); red is reserved as a
# status color for "certificate violated" and never identifies a method.
COLOR = {
    "Proposed": "#2a78d6",   # blue
    "Greedy":   "#1baf7a",   # aqua
    "FixedW":   "#eda100",   # yellow
    "NoIT2":    "#008300",   # green
    "NoGov":    "#4a3aa7",   # violet
    "NoWFBRI":  "#e87ba4",   # magenta
    "NoRobust": "#eb6834",   # orange
}
VIOLATION_RED = "#e34948"
VACUOUS_GRAY = "#6f6e6a"

LABEL = {
    "Proposed": "Proposed (Full)",
    "Greedy": "Greedy",
    "FixedW": "FixedW",
    "NoIT2": "w/o IT2",
    "NoGov": "w/o Weight Update",
    "NoWFBRI": "w/o W-FBRI",
    "NoRobust": "w/o Robust $\\alpha$-FNE",
}

# Structural decision-rule categories (see module docstring).
VACUOUS = {"Greedy", "NoWFBRI"}
VIOLATED = {"NoIT2", "NoRobust"}


def read_rows(path):
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh))


def f(row, key):
    return float(row[key])


def pick(rows, nv, method):
    return next(r for r in rows if r["Nv"] and int(r["Nv"]) == nv and r["method"] == method)


def save_both(fig, basename):
    """Write a raster PNG (screen/preview) and a vector PDF (paper) of the same
    figure. LaTeX references the file extensionlessly so pdflatex picks the PDF.
    bbox_inches='tight' crops the canvas to the tight bounding box of all drawn
    artists (axes + direct labels + leader lines), so the saved file carries no
    surrounding whitespace; pad_inches leaves a hairline margin."""
    for ext in ("png", "pdf"):
        out = os.path.join(OUT_DIR, f"{basename}.{ext}")
        fig.savefig(out, bbox_inches="tight", pad_inches=0.02)
        print(f"wrote {out}")


def fig_density(rows):
    """Scenario I: two vertically stacked panels sharing ONE x-axis
    (vehicle density). Fusing the former side-by-side panels this way is the
    correct merge for two measures on a common x: it removes the duplicated
    axis, gives each panel the full column width (the paper figure is
    single-column, where the old 1x2 layout was badly cramped), and -- unlike
    a dual-y-axis chart -- keeps each measure on its own honest scale. A
    single-axis fusion via a +/-std band was rejected: std(payoff) ~= 0.081 is
    2.4x the between-method payoff difference (~0.034), so a spread band would
    drown the real, significant payoff separation.

    Top: realized payoff (the headline -- Proposed leads at N_v>=100). Bottom:
    payoff variance (the two-band story -- Greedy alone in the high band).
    Methods are identified by direct end-of-line labels, so there is no legend
    box to obscure any data; color is consistent across both panels."""
    methods = ["Greedy", "Proposed", "FixedW"]
    densities = sorted({int(r["Nv"]) for r in rows if r["Nv"]})

    fig, (ax_u, ax_v) = plt.subplots(
        2, 1, sharex=True, figsize=(4.9, 5.0), dpi=300,
        gridspec_kw={"height_ratios": [1.0, 1.0], "hspace": 0.10})

    payoff_end = {}   # method -> (x, y) at the last density, for label placement
    var_end = {}
    for m in methods:
        xs, us, ucis, vs, vcis = [], [], [], [], []
        for nv in densities:
            r = pick(rows, nv, m)
            xs.append(nv)
            us.append(f(r, "realized_uhat_mean"))
            ucis.append(f(r, "realized_uhat_ci95"))
            vs.append(f(r, "avg_var_uhat_mean") * 1e3)
            vcis.append(f(r, "avg_var_uhat_ci95") * 1e3)
        ax_u.errorbar(xs, us, yerr=ucis, marker="o", markersize=5.5,
                      linewidth=2, color=COLOR[m], capsize=3)
        ax_v.errorbar(xs, vs, yerr=vcis, marker="o", markersize=5.5,
                      linewidth=2, color=COLOR[m], capsize=3)
        payoff_end[m] = (xs[-1], us[-1])
        var_end[m] = (xs[-1], vs[-1])

    # Direct labels at the right (identify all three methods once, in the
    # payoff panel); nudge Proposed/FixedW apart since they sit ~0.01 apart.
    pay_dy = {"Greedy": 0, "Proposed": 5, "FixedW": -6}
    for m in methods:
        x, y = payoff_end[m]
        ax_u.annotate(LABEL[m].replace(" (Full)", ""), xy=(x, y),
                      xytext=(8, pay_dy[m]), textcoords="offset points",
                      va="center", ha="left", fontsize=10.5, color=COLOR[m],
                      fontweight="bold", annotation_clip=False)
    # In the variance panel the vertical order flips (Greedy jumps to the top
    # band), so re-label Greedy there to remove any doubt; the tight low band
    # (Proposed/FixedW) is self-evident by color.
    gx, gy = var_end["Greedy"]
    ax_v.annotate("Greedy", xy=(gx, gy), xytext=(8, 0),
                  textcoords="offset points", va="center", ha="left",
                  fontsize=10.5, color=COLOR["Greedy"], fontweight="bold",
                  annotation_clip=False)
    for m in ("Proposed", "FixedW"):
        x, y = var_end[m]
        dy = 7 if m == "Proposed" else -8
        ax_v.annotate(m, xy=(x, y), xytext=(8, dy), textcoords="offset points",
                      va="center", ha="left", fontsize=10.5, color=COLOR[m],
                      fontweight="bold", annotation_clip=False)

    ax_u.set_ylabel(r"Realized payoff $\bar{U}^{\mathrm{real}}$", fontweight="bold")
    ax_v.set_ylabel(r"Payoff variance ($\times 10^{-3}$)", fontweight="bold")
    ax_v.set_xlabel(r"Vehicle density $N_v$", fontweight="bold")
    tag_bbox = dict(boxstyle="square,pad=0.15", facecolor="white",
                    edgecolor="none")
    ax_u.text(0.02, 0.08, "(a)", transform=ax_u.transAxes, fontsize=11,
              va="bottom", ha="left", bbox=tag_bbox)   # lower-left: clear of data
    ax_v.text(0.02, 0.55, "(b)", transform=ax_v.transAxes, fontsize=11,
              va="center", ha="left", bbox=tag_bbox)   # mid-left: the empty band gap
    ax_u.set_ylim(0.598, 0.668)
    ax_v.set_ylim(6.15, 8.80)
    for ax in (ax_u, ax_v):
        ax.set_xticks(densities)
        ax.set_xlim(38, 232)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.grid(axis="y", linestyle="--", linewidth=0.6, alpha=0.4)

    fig.tight_layout()
    save_both(fig, "fig5-19-density")
    save_both(fig, "fig5-16")   # legacy filename slot (superseded original), kept in sync
    plt.close(fig)


def marker_style(method):
    """Edge style by structural certificate category."""
    if method in VIOLATED:
        return dict(edgecolor=VIOLATION_RED, linewidth=3.0, hatch="////")
    if method in VACUOUS:
        return dict(edgecolor=VACUOUS_GRAY, linewidth=2.2, linestyle="--")
    return dict(edgecolor="black", linewidth=1.6)


def fig_frontier(exp1_rows, exp2_rows):
    """Measured payoff (x) vs measured payoff variance (y) at Nv=200, broken
    y-axis (two stacked panels, same units -- not a dual-axis chart), with the
    three-state certificate encoding on the marker edge.

    The measured data split into two variance bands:
      high (~8.5e-3): Greedy and w/o IT2 -- the two uncertainty-blind payoff
                      rules; they also hold the highest mean payoff
      low  (~6.3-6.7e-3): every uncertainty-aware variant
    so the figure reads as: the nominal-payoff premium of uncertainty-blind
    decisions is paid in variance and in certificate status."""
    pts = {}
    for r in exp1_rows:
        if r["Nv"] and int(r["Nv"]) == 200 and r["method"] in ("Greedy", "FixedW"):
            pts[r["method"]] = r
    for r in exp2_rows:
        pts[r["method"]] = r

    order = ["NoIT2", "Greedy", "NoRobust", "NoWFBRI", "NoGov", "FixedW", "Proposed"]
    # (dx, dy, ha, use_leader): w/o W-FBRI and w/o Robust alpha-FNE sit almost
    # on the same point (0.7435/6.60 vs 0.7425/6.61), so both get long leader
    # lines pointing in opposite directions; everything else gets a short
    # collision-free offset.
    LABEL_OFFSET_TOP = {
        "NoIT2":  (12, -18, "left", True),
        "Greedy": (-16, -2, "right", False),
    }
    LABEL_OFFSET_BOT = {
        "Proposed": (16, 4, "left", False),      # 右侧空白区
        "NoRobust": (-40, -26, "right", True),   # 引线拉到左下空白
        "NoWFBRI":  (26, 16, "left", True),
        "NoGov":    (-12, -20, "right", False),
        "FixedW":   (-14, -8, "right", False),
    }

    fig, (ax_top, ax_bot) = plt.subplots(
        2, 1, sharex=True, figsize=(6.6, 5.0), dpi=300,
        gridspec_kw={"height_ratios": [1.0, 1.7], "hspace": 0.08})

    for m in order:
        r = pts[m]
        x = f(r, "realized_uhat_mean")
        xerr = f(r, "realized_uhat_ci95")
        y = f(r, "avg_var_uhat_mean") * 1e3
        yerr = f(r, "avg_var_uhat_ci95") * 1e3
        in_top = m in LABEL_OFFSET_TOP
        ax = ax_top if in_top else ax_bot
        dx, dy, ha, leader = (LABEL_OFFSET_TOP if in_top else LABEL_OFFSET_BOT)[m]

        style = marker_style(m)
        ls = style.pop("linestyle", "-")
        ax.errorbar(x, y, xerr=xerr, yerr=yerr, ecolor="0.6", elinewidth=1.0,
                    capsize=2, zorder=2)
        sc = ax.scatter([x], [y], s=240, color=COLOR[m], zorder=3, alpha=0.95,
                        **style)
        sc.set_linestyle(ls)
        arrow = dict(arrowstyle="-", color="0.5", lw=0.8,
                     shrinkA=2, shrinkB=9) if leader else None
        ax.annotate(LABEL[m], xy=(x, y), xytext=(dx, dy),
                    textcoords="offset points", ha=ha, va="center",
                    fontsize=10, color="0.1", fontweight="bold",
                    arrowprops=arrow, zorder=4)

    ax_top.set_ylim(8.30, 8.75)
    ax_bot.set_ylim(6.10, 6.90)
    ax_top.set_xlim(0.585, 0.690)
    for ax in (ax_top, ax_bot):
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.grid(linestyle="--", linewidth=0.6, alpha=0.35)
    ax_top.spines["bottom"].set_visible(False)
    ax_bot.spines["top"].set_visible(False)
    ax_top.tick_params(bottom=False)

    d = 0.010
    kwargs = dict(transform=ax_top.transAxes, color="0.3", clip_on=False, lw=1.0)
    ax_top.plot((-d, +d), (-2 * d, +2 * d), **kwargs)
    kwargs.update(transform=ax_bot.transAxes)
    ax_bot.plot((-d, +d), (1 - 2 * d, 1 + 2 * d), **kwargs)

    ax_bot.set_xlabel(r"Realized payoff $\bar{U}^{\mathrm{real}}$ (measured, higher is better)",
                       fontweight="bold")
    fig.text(0.015, 0.5,
             r"Payoff variance $\mathrm{Var}(\hat U)$ ($\times 10^{-3}$, lower is better)",
             fontweight="bold", rotation=90, va="center", ha="left", fontsize=12)

    legend_handles = [
        Line2D([0], [0], marker="o", color="none", markerfacecolor="0.78",
               markeredgecolor="black", markeredgewidth=1.6, markersize=10,
               label=r"certified: $\varepsilon_{\mathrm{req}}$ within budget"),
        Line2D([0], [0], marker="o", color="none", markerfacecolor="0.78",
               markeredgecolor=VACUOUS_GRAY, markeredgewidth=2.2, markersize=10,
               label=r"no certificate (hard best response)"),
        Line2D([0], [0], marker="o", color="none", markerfacecolor="0.78",
               markeredgecolor=VIOLATION_RED, markeredgewidth=2.8, markersize=10,
               label=r"certificate violated"),
    ]
    ax_bot.legend(handles=legend_handles, loc="upper right", fontsize=8.7,
                  framealpha=0.95, borderaxespad=0.5)

    fig.tight_layout(rect=(0.045, 0, 1, 1))
    save_both(fig, "fig5-20-frontier")
    save_both(fig, "fig5-17")   # legacy filename slot (superseded original), kept in sync
    plt.close(fig)


def main():
    exp1_rows = read_rows(EXP1_CSV)
    exp2_rows = read_rows(EXP2_CSV)
    os.makedirs(OUT_DIR, exist_ok=True)
    fig_density(exp1_rows)
    fig_frontier(exp1_rows, exp2_rows)


if __name__ == "__main__":
    main()
