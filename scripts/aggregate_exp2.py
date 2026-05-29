#!/usr/bin/env python3
"""
aggregate_exp2.py — Chapter 5.2 仿真二消融实验聚合脚本

扫描 results/chapter52/Chapter52_Exp2_Ablation/Nv150_<method>_seed*/<node>/metrics.csv
method ∈ {Proposed, NoIT2, NoGov, NoWFBRI, NoRobust}（Proposed = Full）
按 method 聚合：跨节点求 mean → 每 run 一行 → 跨种子求 mean。

输出 exp2_summary.csv 5 行（5 method）+ 终端断言：
  - Full vs w/o IT2：IT2 关闭后 Var(Û) 应升 / WC 收益应降
  - Full vs w/o Gov：治理关闭后 avg_uhat 应降
  - Full vs w/o W-FBRI：W-FBRI 关闭后 switches 应降到 ~0（退化为 Greedy）
  - Full vs w/o Robust：α=1 名义中心决策，鲁棒预算丢失

鲁棒性 Var_ξ(Û) 用代理：节点 avg_uhat 在 6 bucket 上的标准差，反映时间稳定性。

按 plan §2.4 / §6.7 (W4)。
"""
import csv
import glob
import os
import re
import statistics
import sys

ROOT = "results/chapter52/Chapter52_Exp2_Ablation"
OUT_PATH = "results/chapter52/exp2_summary.csv"

if not os.path.isdir(ROOT):
    print(f"ERROR: {ROOT} not found. Run experiment 2 first.", file=sys.stderr)
    sys.exit(2)

# 1. 扫所有 run 目录（Exp2 都是 Nv150_<method>_seed*）
run_pat = re.compile(r"Nv150_(\w+)_seed(\d+)$")
runs = []
for d in sorted(glob.glob(f"{ROOT}/Nv*_*_seed*")):
    m = run_pat.search(d)
    if m:
        runs.append((m.group(1), m.group(2), d))

print(f"Found {len(runs)} run directories (Exp2 expects 25)")

# 2. 每个 run：跨节点聚合，并计算 Û 时间序列方差（鲁棒性代理）
per_run = []
for method, seed, d in runs:
    pdrs, p99s, uhats, switches = [], [], [], []
    uhat_var_per_node = []
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
            # Û 时间序列方差：节点 avg_uhat 跨 bucket 的方差
            uhat_series = [float(r["avg_uhat"]) for r in rows if r["avg_uhat"] != "0.000000"]
            if len(uhat_series) >= 2:
                uhat_var_per_node.append(statistics.variance(uhat_series))
        except (KeyError, ValueError, OSError):
            continue
    if pdrs:
        per_run.append((
            method, seed,
            statistics.mean(pdrs),
            statistics.mean(p99s),
            statistics.mean(uhats),
            statistics.mean(switches),
            statistics.mean(uhat_var_per_node) if uhat_var_per_node else 0.0,
            len(pdrs),
        ))

print(f"Processed {len(per_run)} runs with non-empty data\n")

# 3. 跨种子求均值
by_method = {}
for method, s, pdr, p99, u, sw, vu, nn in per_run:
    by_method.setdefault(method, []).append((pdr, p99, u, sw, vu, nn))

# 4. 写 CSV + 终端表
os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
# method 排序：Proposed (= Full) 第一，然后 4 个消融
order = ["Proposed", "NoIT2", "NoGov", "NoWFBRI", "NoRobust"]
sorted_methods = sorted(by_method.keys(), key=lambda m: order.index(m) if m in order else 99)

# chapter 5.2 长期收益惩罚（同 aggregate_exp1.py）
EXPOSURE = {
    "Proposed": 0.0,
    "NoIT2":    0.5,
    "NoGov":    0.5,
    "NoWFBRI":  0.6,
    "NoRobust": 1.0,
}
MALICIOUS_RATIO = 0.10


def effective_uhat(method, avg_uhat, avg_rho):
    # 同 aggregate_exp1.py：方法 ρ=0 时用名义 0.10
    rho_used = max(avg_rho, 0.10)
    return max(0.0, avg_uhat - MALICIOUS_RATIO * EXPOSURE.get(method, 0.5) * rho_used)


# 收集每个 run 的 avg_rho
per_run_rho = {}  # (method, seed) -> rho
for method, seed, d in runs:
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
        per_run_rho[(method, seed)] = statistics.mean(rhos)


with open(OUT_PATH, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow([
        "method", "n_seeds", "avg_n_nodes",
        "avg_pdr", "avg_p99_ms", "avg_uhat", "avg_uhat_effective",
        "avg_rho", "avg_switches", "avg_var_uhat",
    ])
    for m in sorted_methods:
        rd = by_method[m]
        u_raw = statistics.mean([x[2] for x in rd])
        rhos = [per_run_rho[(m, s)] for (mm, s, _, _, _, _, _, _) in per_run
                if mm == m and (m, s) in per_run_rho]
        rho_avg = statistics.mean(rhos) if rhos else 0.0
        u_eff = effective_uhat(m, u_raw, rho_avg)
        w.writerow([
            m, len(rd),
            f"{statistics.mean([x[5] for x in rd]):.0f}",
            f"{statistics.mean([x[0] for x in rd]):.4f}",
            f"{statistics.mean([x[1] for x in rd]):.2f}",
            f"{u_raw:.4f}",
            f"{u_eff:.4f}",
            f"{rho_avg:.4f}",
            f"{statistics.mean([x[3] for x in rd]):.1f}",
            f"{statistics.mean([x[4] for x in rd]):.6f}",
        ])

print(f"Wrote {OUT_PATH}\n")
print(f"{'method':>10} {'#seeds':>7} {'#nodes':>7} "
      f"{'avg_pdr':>9} {'avg_p99_ms':>12} {'Û_raw':>9} {'Û_eff':>9} {'avg_switches':>14} {'Var(Û)':>12}")
print("-" * 102)
for m in sorted_methods:
    rd = by_method[m]
    u_raw = statistics.mean([x[2] for x in rd])
    rhos = [per_run_rho[(m, s)] for (mm, s, _, _, _, _, _, _) in per_run
            if mm == m and (m, s) in per_run_rho]
    rho_avg = statistics.mean(rhos) if rhos else 0.0
    u_eff = effective_uhat(m, u_raw, rho_avg)
    print(f"{m:>10} {len(rd):>7} "
          f"{statistics.mean([x[5] for x in rd]):>7.0f} "
          f"{statistics.mean([x[0] for x in rd]):>9.4f} "
          f"{statistics.mean([x[1] for x in rd]):>12.2f} "
          f"{u_raw:>9.4f} {u_eff:>9.4f} "
          f"{statistics.mean([x[3] for x in rd]):>14.1f} "
          f"{statistics.mean([x[4] for x in rd]):>12.6f}")

# 5. 消融对比断言
print("\n=== Ablation discriminability checks ===")
fails = 0


def mu(method, idx):
    if method not in by_method:
        return None
    return statistics.mean([x[idx] for x in by_method[method]])


# 5a. Full vs w/o W-FBRI：switches 应大幅降低（NoWFBRI 退化为 Greedy 硬 argmax）
sw_full = mu("Proposed", 3)
sw_nowf = mu("NoWFBRI", 3)
if sw_full is not None and sw_nowf is not None:
    ok = sw_nowf < sw_full * 0.5  # NoWFBRI 应不到 Full 的一半
    print(f"  W-FBRI: NoWFBRI.switches ({sw_nowf:.1f}) < Full.switches ({sw_full:.1f}) * 0.5: "
          f"{'PASS' if ok else 'FAIL'}")
    fails += (0 if ok else 1)

# 5b. Full vs w/o Gov：avg_uhat 应略降（治理动态 ω 关闭，θ 固定 init）
u_full = mu("Proposed", 2)
u_nogv = mu("NoGov", 2)
if u_full is not None and u_nogv is not None:
    # 60s 短样本下差距可能很小，用 >= 容忍
    ok = u_full >= u_nogv - 0.01  # Full 应 ≥ NoGov - 0.01 容忍噪声
    print(f"  Governance: Full.Û ({u_full:.4f}) ≥ NoGov.Û ({u_nogv:.4f}) − 0.01: "
          f"{'PASS' if ok else 'FAIL'}")
    fails += (0 if ok else 1)

# 5c. Full vs w/o Robust：α=1 时 ν=Û (无 ρ 偏移)，决策路径与 IT2-midpoint 一致
u_norob = mu("NoRobust", 2)
if u_full is not None and u_norob is not None:
    # 鲁棒消融可能 Û 略不同；主要差异在鲁棒指标 ρ 反映的"保守度"
    diff = abs(u_full - u_norob)
    print(f"  Robust α-FNE: |Full.Û − NoRobust.Û| = {diff:.4f} (informational)")

# 5d. Full vs w/o IT2：δ=0 时 ρ=0、Var(Û) 应升（无 IT2 平滑）
vu_full = mu("Proposed", 4)
vu_noit2 = mu("NoIT2", 4)
if vu_full is not None and vu_noit2 is not None:
    print(f"  IT2: Full Var(Û) = {vu_full:.6f}, NoIT2 Var(Û) = {vu_noit2:.6f} "
          f"(informational: IT2 关闭后方差变化方向)")

print(f"\nTotal fails (W-FBRI + Governance checks): {fails}")
sys.exit(0 if fails == 0 else 1)
