#!/bin/bash
# Chapter 5.2 strengthened Exp2 batch: 5 ablations x 10 seeds = 50 runs.
# Usage: nohup bash scripts/run_exp2_strong.sh > logs/exp2_strong.log 2>&1 &
# Startup test: EXP2_RUNS=1 SIM_TIME_LIMIT=5s bash scripts/run_exp2_strong.sh

set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/strong_launchd_common.sh

EXP2_START_RUN=${EXP2_START_RUN:-0}
EXP2_RUNS=${EXP2_RUNS:-50}
SIM_TIME_LIMIT=${SIM_TIME_LIMIT:-}
SIM_TIME_ARG=()
if [ -n "$SIM_TIME_LIMIT" ]; then
    SIM_TIME_ARG=(--sim-time-limit="$SIM_TIME_LIMIT")
fi

mkdir -p logs
ensure_launchd
trap cleanup_launchd EXIT

START=$(date +%s)
echo "[$(date)] Start Chapter52_Exp2_Ablation_Strong batch (${EXP2_RUNS} runs from r${EXP2_START_RUN})"

for r in $(seq "$EXP2_START_RUN" $((EXP2_START_RUN + EXP2_RUNS - 1))); do
    RUN_START=$(date +%s)
    log="logs/run_Chapter52_Exp2_Ablation_Strong_r${r}.log"
    if ! run_opp_with_retries "Chapter52_Exp2_Ablation_Strong r${r}" "$log" \
        opp_run_release -u Cmdenv -c Chapter52_Exp2_Ablation_Strong -r "$r" \
        -n .:../../src/veins -l ../../out/clang-release/src/veins \
        --cmdenv-express-mode=true \
        --debug-on-errors=false \
        "${SIM_TIME_ARG[@]}" \
        omnetpp.ini; then
        echo "ERROR: Chapter52_Exp2_Ablation_Strong r${r} failed. Log tail:" >&2
        tail -80 "$log" >&2 || true
        exit 1
    fi
    RUN_END=$(date +%s)
    ELAPSED=$((RUN_END - START))
    echo "  exp2 strong run $r done in $((RUN_END - RUN_START))s; elapsed ${ELAPSED}s"
done

TOTAL=$(($(date +%s) - START))
echo "[$(date)] Exp2 strong complete in ${TOTAL}s"
