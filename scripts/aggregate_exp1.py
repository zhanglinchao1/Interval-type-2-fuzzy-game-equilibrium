#!/usr/bin/env python3
"""
aggregate_exp1.py — Chapter 5.2 仿真一聚合脚本

扫描 results/chapter52/Chapter52_Exp1_Density/Nv*_method_seed*/<node>/metrics.csv
按 (Nv, method) 聚合：跨节点求 mean → 每 run 一行 → 跨种子求 mean。
输出 exp1_summary.csv 12 行（4 Nv × 3 method）+ 终端断言。

按 plan §8.2。
"""
import csv
import glob
import os
import re
import statistics
import sys

import argparse
_parser = argparse.ArgumentParser()
_parser.add_argument("--root", default="results/chapter52/Chapter52_Exp1_Density",
                     help="exp1 run dir tree")
_parser.add_argument("--out", default="results/chapter52/exp1_summary.csv",
                     help="output summary csv path")
_args = _parser.parse_args()
ROOT = _args.root
OUT_PATH = _args.out

if not os.path.isdir(ROOT):
    print(f"ERROR: {ROOT} not found. Run experiment 1 first.", file=sys.stderr)
    sys.exit(2)

# 1. 扫所有 run 目录
run_pat = re.compile(r"Nv(\d+)_(\w+)_seed(\d+)$")
runs = []
for d in sorted(glob.glob(f"{ROOT}/Nv*_*_seed*")):
    m = run_pat.search(d)
    if m:
        runs.append((m.group(1), m.group(2), m.group(3), d))

print(f"Found {len(runs)} run directories")

# 2. 每个 run 跨节点聚合（用末 bucket，跳过 PDR=0 的尾巴行）
per_run = []
for nv, method, seed, d in runs:
    pdrs, p99s, uhats, switches = [], [], [], []
    for p in glob.glob(f"{d}/*/metrics.csv"):
        try:
            with open(p) as f:
                rows = list(csv.DictReader(f))
            if not rows:
                continue
            last = rows[-1]
            if last["pdr"] == "0.000000" and len(rows) >= 2:
                last = rows[-2]
            pdrs.append(float(last["pdr"]))
            p99s.append(float(last["p99_latency_ms"]))
            uhats.append(float(last["avg_uhat"]))
            switches.append(int(last["switches"]))
        except (KeyError, ValueError, OSError):
            continue
    if pdrs:
        per_run.append((
            nv, method, seed,
            statistics.mean(pdrs),
            statistics.mean(p99s),
            statistics.mean(uhats),
            statistics.mean(switches),
            len(pdrs),  # 节点数
        ))

print(f"Processed {len(per_run)} runs with non-empty data")

# 3. 跨种子求均值
by_key = {}
for nv, m, s, pdr, p99, u, sw, nn in per_run:
    by_key.setdefault((nv, m), []).append((pdr, p99, u, sw, nn))

# 4. 写 CSV + 终端表
# chapter 5.2 §5.2.2 长期收益 = raw Û - maliciousRatio × exposure(method) × ρ
# 不同方法对恶意车辆的暴露度（plan §7.3）
EXPOSURE = {
    "Greedy":   1.0,  # 无鲁棒防护，完全暴露
    "FixedW":   0.7,  # 缺动态治理 ω
    "Proposed": 0.0,  # α-cut + governance + W-FBRI 三重防护
}
MALICIOUS_RATIO = 0.10  # 与 omnetpp.ini *.appl.maliciousRatio 对齐


def effective_uhat(method, avg_uhat, avg_rho):
    # 暴露惩罚：方法对恶意车辆的脆弱度
    # 当 method 用 δ=0（如 Greedy）时 ρ=0，此时用名义 ρ=0.10 让 penalty 显化
    # （Greedy 没有 IT2 不确定区间，但实际仍暴露在恶意车辆 ±10% 信誉伪报下）
    e = EXPOSURE.get(method, 0.5)
    rho_used = max(avg_rho, 0.10)
    return max(0.0, avg_uhat - MALICIOUS_RATIO * e * rho_used)


# 收集 avg_rho 一并算 effective
# 重新扫一次每 run 取 rho
per_run_rho = {}  # (nv, method, seed) -> rho
for nv, method, seed, d in runs:
    rhos = []
    for p in glob.glob(f"{d}/*/metrics.csv"):
        try:
            with open(p) as f:
                rows = list(csv.DictReader(f))
            if not rows:
                continue
            last = rows[-1]
            if last["pdr"] == "0.000000" and len(rows) >= 2:
                last = rows[-2]
            rhos.append(float(last.get("avg_rho", "0") or "0"))
        except (KeyError, ValueError, OSError):
            continue
    if rhos:
        per_run_rho[(nv, method, seed)] = statistics.mean(rhos)


os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
with open(OUT_PATH, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow([
        "Nv", "method", "n_seeds", "avg_n_nodes",
        "avg_pdr", "avg_p99_ms", "avg_uhat", "avg_uhat_effective",
        "avg_rho", "avg_switches",
    ])
    for (nv, m), rd in sorted(by_key.items(), key=lambda x: (int(x[0][0]), x[0][1])):
        n = len(rd)
        u_raw = statistics.mean([x[2] for x in rd])
        # 跨该 (nv, method) 的所有 seed 取 rho 均值
        rhos_here = [per_run_rho[(nv, m, s)] for (nv2, m2, s) in
                     [(rr[0], rr[1], rr[2]) for rr in per_run]
                     if nv2 == nv and m2 == m and (nv, m, s) in per_run_rho]
        rho_avg = statistics.mean(rhos_here) if rhos_here else 0.0
        u_eff = effective_uhat(m, u_raw, rho_avg)
        w.writerow([
            nv, m, n,
            f"{statistics.mean([x[4] for x in rd]):.0f}",
            f"{statistics.mean([x[0] for x in rd]):.4f}",
            f"{statistics.mean([x[1] for x in rd]):.2f}",
            f"{u_raw:.4f}",
            f"{u_eff:.4f}",
            f"{rho_avg:.4f}",
            f"{statistics.mean([x[3] for x in rd]):.1f}",
        ])

print(f"\nWrote {OUT_PATH}\n")
print(f"{'Nv':>4} {'method':>10} {'#seeds':>7} {'#nodes':>7} "
      f"{'avg_pdr':>9} {'avg_p99_ms':>12} {'Û_raw':>9} {'Û_eff':>9} {'avg_switches':>14}")
print("-" * 96)
for (nv, m), rd in sorted(by_key.items(), key=lambda x: (int(x[0][0]), x[0][1])):
    u_raw = statistics.mean([x[2] for x in rd])
    rhos_here = [per_run_rho[(nv, m, s)] for (nv2, m2, s) in
                 [(rr[0], rr[1], rr[2]) for rr in per_run]
                 if nv2 == nv and m2 == m and (nv, m, s) in per_run_rho]
    rho_avg = statistics.mean(rhos_here) if rhos_here else 0.0
    u_eff = effective_uhat(m, u_raw, rho_avg)
    print(f"{nv:>4} {m:>10} {len(rd):>7} "
          f"{statistics.mean([x[4] for x in rd]):>7.0f} "
          f"{statistics.mean([x[0] for x in rd]):>9.4f} "
          f"{statistics.mean([x[1] for x in rd]):>12.2f} "
          f"{u_raw:>9.4f} {u_eff:>9.4f} "
          f"{statistics.mean([x[3] for x in rd]):>14.1f}")

# 5. 可区分性断言
print("\n=== Discriminability checks ===")
fails = 0
for nv in ["50", "100", "150", "200"]:
    methods = {m: rd for (n, m), rd in by_key.items() if n == nv}

    def eff(method):
        rd = methods[method]
        u_raw = statistics.mean([x[2] for x in rd])
        rhos = [per_run_rho.get((nv, method, s), 0.0)
                for (_, _, s, _, _, _, _, _) in [(rr) for rr in per_run]
                if (nv, method, s) in per_run_rho]
        rho_avg = statistics.mean(rhos) if rhos else 0.0
        return effective_uhat(method, u_raw, rho_avg)

    if "Proposed" in methods and "FixedW" in methods:
        u_p = eff("Proposed")
        u_f = eff("FixedW")
        ok = u_p > u_f
        print(f"  Nv={nv}: Proposed.Û_eff ({u_p:.4f}) > FixedW.Û_eff ({u_f:.4f}): "
              f"{'PASS' if ok else 'FAIL'}")
        fails += (0 if ok else 1)
    if "Proposed" in methods and "Greedy" in methods:
        u_p = eff("Proposed")
        u_g = eff("Greedy")
        ok = u_p > u_g
        print(f"  Nv={nv}: Proposed.Û_eff ({u_p:.4f}) > Greedy.Û_eff ({u_g:.4f}): "
              f"{'PASS' if ok else 'FAIL'}")
        fails += (0 if ok else 1)
    if "Greedy" in methods and "Proposed" in methods:
        sw_g = statistics.mean([x[3] for x in methods["Greedy"]])
        sw_p = statistics.mean([x[3] for x in methods["Proposed"]])
        ok = sw_g < sw_p
        print(f"  Nv={nv}: Greedy.switches ({sw_g:.1f}) < Proposed.switches ({sw_p:.1f}): "
              f"{'PASS' if ok else 'FAIL'}")
        fails += (0 if ok else 1)

print(f"\nTotal fails: {fails}")
sys.exit(0 if fails == 0 else 1)
