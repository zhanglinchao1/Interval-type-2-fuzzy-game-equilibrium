#!/bin/bash
# Chapter 5.2 strengthened Exp1 batch: 4 densities x 3 methods x 10 seeds = 120 runs.
# Usage: nohup bash scripts/run_exp1_strong.sh > logs/exp1_strong.log 2>&1 &
# Startup test: EXP1_RUNS=1 SIM_TIME_LIMIT=5s bash scripts/run_exp1_strong.sh

set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/strong_launchd_common.sh

EXP1_START_RUN=${EXP1_START_RUN:-0}
EXP1_RUNS=${EXP1_RUNS:-120}
SIM_TIME_LIMIT=${SIM_TIME_LIMIT:-}
SIM_TIME_ARG=()
if [ -n "$SIM_TIME_LIMIT" ]; then
    SIM_TIME_ARG=(--sim-time-limit="$SIM_TIME_LIMIT")
fi

mkdir -p logs
ensure_launchd
trap cleanup_launchd EXIT

START=$(date +%s)
echo "[$(date)] Start Chapter52_Exp1_Density_Strong batch (${EXP1_RUNS} runs from r${EXP1_START_RUN})"

for r in $(seq "$EXP1_START_RUN" $((EXP1_START_RUN + EXP1_RUNS - 1))); do
    RUN_START=$(date +%s)
    log="logs/run_Chapter52_Exp1_Density_Strong_r${r}.log"
    if ! run_opp_with_retries "Chapter52_Exp1_Density_Strong r${r}" "$log" \
        opp_run_release -u Cmdenv -c Chapter52_Exp1_Density_Strong -r "$r" \
        -n .:../../src/veins -l ../../out/clang-release/src/veins \
        --cmdenv-express-mode=true \
        --debug-on-errors=false \
        "${SIM_TIME_ARG[@]}" \
        omnetpp.ini; then
        echo "ERROR: Chapter52_Exp1_Density_Strong r${r} failed. Log tail:" >&2
        tail -80 "$log" >&2 || true
        exit 1
    fi
    RUN_END=$(date +%s)
    ELAPSED=$((RUN_END - START))
    echo "  exp1 strong run $r done in $((RUN_END - RUN_START))s; elapsed ${ELAPSED}s"
done

TOTAL=$(($(date +%s) - START))
echo "[$(date)] Exp1 strong complete in ${TOTAL}s"
