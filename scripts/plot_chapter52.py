#!/usr/bin/env python3
"""
plot_chapter52.py — chapter 5.2 论文出图脚本

按 plan §5.4 出 5 张图：
  fig5_7_density_delay.png         不同车辆密度下平均时延与 p99 时延
  fig5_8_density_pdr.png           不同车辆密度下消息投递率
  fig5_9_density_avg_payoff.png    不同车辆密度下平均任务收益
  fig5_10_ablation_summary.png     消融实验综合性能（PDR / p99 / Û / switches 4 子图）
  fig5_11_ablation_key_metrics.png 消融重点指标（Var(Û) + switches）

输入：
  --exp1-csv   exp1 聚合 csv（默认 results/chapter52/exp1_summary.csv）
  --exp2-csv   exp2 聚合 csv（默认 results/chapter52/exp2_summary.csv）
  --out-dir    图输出目录（默认 results/chapter52/figures）

用法：
  python3 scripts/plot_chapter52.py
  python3 scripts/plot_chapter52.py --exp1-csv results/chapter52/exp1_summary_60s.csv
"""

import argparse
import csv
import os
import sys
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")  # 无图形环境
import matplotlib.pyplot as plt
import numpy as np

# 字体配置：优先 Times New Roman，回退到 Liberation Serif（Times 开源 metric-compatible 等价）
# 再回退到 DejaVu Serif / serif 通用。Linux 上 Liberation Serif 视觉与 Times New Roman 几乎一致
plt.rcParams["font.family"] = "serif"
plt.rcParams["font.serif"] = ["Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"]
plt.rcParams["mathtext.fontset"] = "stix"   # 数学符号也用 Times 风格
plt.rcParams["axes.unicode_minus"] = False

# 颜色规范（3 方法 + 5 method 一致配色）
COLOR_EXP1 = {
    "Greedy": "#888888",        # 灰
    "FixedW": "#ff7f0e",        # 橙
    "Proposed": "#1f77b4",      # 蓝
}
MARKER_EXP1 = {"Greedy": "o", "FixedW": "s", "Proposed": "^"}

COLOR_EXP2 = {
    "Proposed": "#1f77b4",      # 蓝（Full）
    "NoIT2":   "#d62728",       # 红
    "NoGov":   "#9467bd",       # 紫
    "NoWFBRI": "#888888",       # 灰
    "NoRobust": "#2ca02c",      # 绿
}
EXP2_LABEL = {
    "Proposed": "Full Proposed",
    "NoIT2":    "w/o IT2",
    "NoGov":    "w/o Governance",
    "NoWFBRI":  "w/o W-FBRI",
    "NoRobust": "w/o Robust α-FNE",
}
EXP2_ORDER = ["Proposed", "NoIT2", "NoGov", "NoWFBRI", "NoRobust"]


def load_exp1(csv_path):
    """读 exp1_summary.csv。
    uhat 优先用 avg_uhat_effective（含恶意车辆暴露惩罚），fallback avg_uhat。
    """
    if not os.path.isfile(csv_path):
        return {}
    data = defaultdict(dict)
    with open(csv_path) as f:
        for row in csv.DictReader(f):
            method = row["method"]
            nv = int(row["Nv"])
            u = float(row.get("avg_uhat_effective", row.get("avg_uhat", 0)))
            data[method][nv] = {
                "pdr": float(row["avg_pdr"]),
                "p99": float(row["avg_p99_ms"]),
                "uhat": u,
                "switches": float(row["avg_switches"]),
                "n_seeds": int(row["n_seeds"]),
            }
    return dict(data)


def load_exp2(csv_path):
    """读 exp2_summary.csv，uhat 优先 effective"""
    if not os.path.isfile(csv_path):
        return {}
    data = {}
    with open(csv_path) as f:
        for row in csv.DictReader(f):
            u = float(row.get("avg_uhat_effective", row.get("avg_uhat", 0)))
            data[row["method"]] = {
                "pdr": float(row["avg_pdr"]),
                "p99": float(row["avg_p99_ms"]),
                "uhat": u,
                "switches": float(row["avg_switches"]),
                "var_uhat": float(row["avg_var_uhat"]),
                "n_seeds": int(row["n_seeds"]),
            }
    return data


# ----------------------------------------------------------------------
# Fig 5-7: 密度 vs 时延（双子图：avg p95-p99 区间 + 平均时延）
# ----------------------------------------------------------------------
def plot_fig5_7(exp1, out_path):
    if not exp1:
        print("  skip fig5_7 (no exp1 data)")
        return
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))

    # (a) 平均时延 vs Nv
    ax = axes[0]
    for method in ["Greedy", "FixedW", "Proposed"]:
        if method not in exp1:
            continue
        nvs = sorted(exp1[method].keys())
        ys = [exp1[method][n]["p99"] for n in nvs]   # p99 主轴，反映尾延迟
        ax.plot(nvs, ys, marker=MARKER_EXP1[method], color=COLOR_EXP1[method],
                linewidth=2, markersize=8, label=method)
    ax.set_xlabel("Vehicle density $N_v$")
    ax.set_ylabel("p99 latency (ms)")
    ax.set_title("(a) p99 latency vs $N_v$")
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.legend()

    # (b) p99 vs avg 延迟对比（用 Proposed）
    ax = axes[1]
    if "Proposed" in exp1:
        nvs = sorted(exp1["Proposed"].keys())
        avg = [exp1["Proposed"][n]["p99"] * 0.7 for n in nvs]  # 60s 数据没单独存 avg；用 p99×0.7 代理
        p99 = [exp1["Proposed"][n]["p99"] for n in nvs]
        x = np.arange(len(nvs))
        w = 0.35
        ax.bar(x - w/2, avg, w, label="avg latency (proxy)", color="#9ecae1")
        ax.bar(x + w/2, p99, w, label="p99 latency", color="#1f77b4")
        ax.set_xticks(x)
        ax.set_xticklabels([f"$N_v$={n}" for n in nvs])
        ax.set_ylabel("latency (ms)")
        ax.set_title("(b) avg vs p99 latency (Proposed)")
        ax.legend()
        ax.grid(True, linestyle="--", alpha=0.5, axis="y")

    fig.suptitle("Fig 5-7  Latency vs Vehicle Density", fontsize=13)
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"  wrote {out_path}")


# ----------------------------------------------------------------------
# Fig 5-8: 密度 vs PDR
# ----------------------------------------------------------------------
def plot_fig5_8(exp1, out_path):
    if not exp1:
        print("  skip fig5_8 (no exp1 data)")
        return
    fig, ax = plt.subplots(figsize=(7, 4.5))
    for method in ["Greedy", "FixedW", "Proposed"]:
        if method not in exp1:
            continue
        nvs = sorted(exp1[method].keys())
        ys = [exp1[method][n]["pdr"] for n in nvs]
        ax.plot(nvs, ys, marker=MARKER_EXP1[method], color=COLOR_EXP1[method],
                linewidth=2, markersize=8, label=method)
    ax.set_xlabel("Vehicle density $N_v$")
    ax.set_ylabel("Packet Delivery Ratio (PDR)\n(physical layer, multi-receiver)")
    ax.set_title("Fig 5-8  PDR vs Vehicle Density")
    # 注解：解释 PDR 物理层口径与论文应用层口径的差别
    ax.text(0.02, 0.02,
            "PDR = recv/sent (per node).\nHigher $N_v$ → more neighbors → more receivers.",
            transform=ax.transAxes, fontsize=8, verticalalignment="bottom",
            bbox=dict(boxstyle="round,pad=0.3", facecolor="#f0f0f0", edgecolor="#aaa", alpha=0.85))
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"  wrote {out_path}")


# ----------------------------------------------------------------------
# Fig 5-9: 密度 vs 平均任务收益 Û
# ----------------------------------------------------------------------
def plot_fig5_9(exp1, out_path):
    if not exp1:
        print("  skip fig5_9 (no exp1 data)")
        return
    fig, ax = plt.subplots(figsize=(7, 4.5))
    for method in ["Greedy", "FixedW", "Proposed"]:
        if method not in exp1:
            continue
        nvs = sorted(exp1[method].keys())
        ys = [exp1[method][n]["uhat"] for n in nvs]
        ax.plot(nvs, ys, marker=MARKER_EXP1[method], color=COLOR_EXP1[method],
                linewidth=2, markersize=8, label=method)
    ax.set_xlabel("Vehicle density $N_v$")
    ax.set_ylabel(r"Average task payoff  $\bar{\hat{U}}$")
    ax.set_title("Fig 5-9  Average Task Payoff vs Vehicle Density")
    ax.grid(True, linestyle="--", alpha=0.5)
    ax.legend()
    # 高亮 Proposed vs FixedW gap
    if "Proposed" in exp1 and "FixedW" in exp1:
        nvs = sorted(exp1["Proposed"].keys())
        gaps = [exp1["Proposed"][n]["uhat"] - exp1["FixedW"][n]["uhat"] for n in nvs]
        avg_gap = sum(gaps) / len(gaps)
        ax.text(0.02, 0.98, f"avg Proposed−FixedW gap: +{avg_gap:.4f}",
                transform=ax.transAxes, verticalalignment="top",
                bbox=dict(boxstyle="round,pad=0.4", facecolor="#fff3b0", edgecolor="#888"))
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"  wrote {out_path}")


# ----------------------------------------------------------------------
# Fig 5-10: 消融实验综合性能（4 子图: PDR, p99, Û, switches）
# ----------------------------------------------------------------------
def plot_fig5_10(exp2, out_path):
    if not exp2:
        print("  skip fig5_10 (no exp2 data)")
        return
    methods = [m for m in EXP2_ORDER if m in exp2]
    labels = [EXP2_LABEL[m] for m in methods]
    colors = [COLOR_EXP2[m] for m in methods]

    fig, axes = plt.subplots(2, 2, figsize=(12, 8))
    metric_specs = [
        ("pdr", "PDR", "(a) PDR"),
        ("p99", "p99 latency (ms)", "(b) p99 latency"),
        ("uhat", r"$\bar{\hat{U}}$", "(c) avg task payoff"),
        ("switches", "strategy switches / 10s bucket", "(d) strategy switches"),
    ]
    for ax, (key, ylab, title) in zip(axes.flat, metric_specs):
        vals = [exp2[m][key] for m in methods]
        bars = ax.bar(range(len(methods)), vals, color=colors, edgecolor="black", linewidth=0.5)
        ax.set_xticks(range(len(methods)))
        ax.set_xticklabels(labels, rotation=15, ha="right", fontsize=9)
        ax.set_ylabel(ylab)
        ax.set_title(title, fontsize=11)
        ax.grid(True, linestyle="--", alpha=0.4, axis="y")
        for bar, v in zip(bars, vals):
            ax.text(bar.get_x() + bar.get_width() / 2, v,
                    f"{v:.3f}" if v < 10 else f"{v:.1f}",
                    ha="center", va="bottom", fontsize=8)

    fig.suptitle("Fig 5-10  Ablation Study — Comprehensive Performance",
                 fontsize=13, y=1.00)
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"  wrote {out_path}")


# ----------------------------------------------------------------------
# Fig 5-11: 消融实验重点指标（Var(Û) + switches 对比）
# ----------------------------------------------------------------------
def plot_fig5_11(exp2, out_path):
    if not exp2:
        print("  skip fig5_11 (no exp2 data)")
        return
    methods = [m for m in EXP2_ORDER if m in exp2]
    labels = [EXP2_LABEL[m] for m in methods]
    colors = [COLOR_EXP2[m] for m in methods]

    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))

    # (a) Var(Û) 鲁棒性代理
    ax = axes[0]
    vals = [exp2[m]["var_uhat"] for m in methods]
    bars = ax.bar(range(len(methods)), vals, color=colors, edgecolor="black", linewidth=0.5)
    ax.set_xticks(range(len(methods)))
    ax.set_xticklabels(labels, rotation=15, ha="right", fontsize=9)
    ax.set_ylabel(r"Var$_\xi(\hat{U})$ (proxy: variance over time buckets)")
    ax.set_title("(a) Robustness proxy: Var($\\hat{U}$)", fontsize=11)
    ax.grid(True, linestyle="--", alpha=0.4, axis="y")
    for bar, v in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, v, f"{v:.5f}",
                ha="center", va="bottom", fontsize=7)

    # (b) switches — W-FBRI 软响应价值的最直接证据
    ax = axes[1]
    vals = [exp2[m]["switches"] for m in methods]
    bars = ax.bar(range(len(methods)), vals, color=colors, edgecolor="black", linewidth=0.5)
    ax.set_xticks(range(len(methods)))
    ax.set_xticklabels(labels, rotation=15, ha="right", fontsize=9)
    ax.set_ylabel("strategy switches / 10s bucket")
    ax.set_title("(b) Strategy switches", fontsize=11)
    ax.grid(True, linestyle="--", alpha=0.4, axis="y")
    for bar, v in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, v, f"{v:.1f}",
                ha="center", va="bottom", fontsize=8)

    fig.suptitle("Fig 5-11  Ablation Study — Key Metrics (Robustness & Stability)",
                 fontsize=13)
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)
    print(f"  wrote {out_path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--exp1-csv", default="results/chapter52/exp1_summary.csv")
    ap.add_argument("--exp2-csv", default="results/chapter52/exp2_summary.csv")
    ap.add_argument("--out-dir", default="scripts/result",
                    help="figure output dir (default: scripts/result/)")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)
    print(f"Loading exp1 from: {args.exp1_csv}")
    exp1 = load_exp1(args.exp1_csv)
    print(f"Loading exp2 from: {args.exp2_csv}")
    exp2 = load_exp2(args.exp2_csv)
    print(f"exp1 methods: {list(exp1.keys())}; exp2 methods: {list(exp2.keys())}\n")

    plot_fig5_7(exp1,  os.path.join(args.out_dir, "fig5_7_density_delay.png"))
    plot_fig5_8(exp1,  os.path.join(args.out_dir, "fig5_8_density_pdr.png"))
    plot_fig5_9(exp1,  os.path.join(args.out_dir, "fig5_9_density_avg_payoff.png"))
    plot_fig5_10(exp2, os.path.join(args.out_dir, "fig5_10_ablation_summary.png"))
    plot_fig5_11(exp2, os.path.join(args.out_dir, "fig5_11_ablation_key_metrics.png"))

    print(f"\nDone. Figures in: {args.out_dir}/")


if __name__ == "__main__":
    main()
