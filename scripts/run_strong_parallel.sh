#!/bin/bash
# Parallel Chapter 5.2 strengthened batch.
# Defaults: jobs=24, Exp1 120 runs, Exp2 50 runs.
# Usage:
#   PARALLEL_JOBS=24 bash scripts/run_strong_parallel.sh

set -u
cd "$(dirname "$0")/.."
. scripts/strong_launchd_common.sh

PARALLEL_JOBS=${PARALLEL_JOBS:-24}
EXP1_RUNS=${EXP1_RUNS:-120}
EXP2_RUNS=${EXP2_RUNS:-50}
SKIP_POST=${SKIP_POST:-0}
SIM_TIME_LIMIT=${SIM_TIME_LIMIT:-}
SIM_TIME_ARG=()
if [ -n "$SIM_TIME_LIMIT" ]; then
    SIM_TIME_ARG=(--sim-time-limit="$SIM_TIME_LIMIT")
fi
mkdir -p logs
ensure_launchd
trap cleanup_launchd EXIT

STATUS_DIR="logs/strong_parallel_status_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$STATUS_DIR"

START=$(date +%s)
echo "[$(date)] Start strong parallel batch (jobs=$PARALLEL_JOBS, exp1=$EXP1_RUNS, exp2=$EXP2_RUNS)"

active_run_jobs() {
    local count=0
    local pid
    for pid in $(jobs -rp); do
        if [ -n "${LAUNCHD_PID:-}" ] && [ "$pid" = "$LAUNCHD_PID" ]; then
            continue
        fi
        count=$((count + 1))
    done
    echo "$count"
}

wait_for_slot() {
    while [ "$(active_run_jobs)" -ge "$PARALLEL_JOBS" ]; do
        sleep 1
    done
}

run_one() {
    local config=$1
    local run_id=$2
    local start_ts
    start_ts=$(date +%s)
    local log="logs/run_${config}_r${run_id}.log"
    run_opp_with_retries "${config} r${run_id}" "$log" \
        opp_run_release -u Cmdenv -c "$config" -r "$run_id" \
        -n .:../../src/veins -l ../../out/clang-release/src/veins \
        --cmdenv-express-mode=true \
        --debug-on-errors=false \
        "${SIM_TIME_ARG[@]}" \
        omnetpp.ini
    local rc=$?
    local duration=$(( $(date +%s) - start_ts ))
    echo "$rc" > "$STATUS_DIR/${config}_r${run_id}.rc"
    echo "[$(date +%T)] ${config} r${run_id} done in ${duration}s (exit=$rc)"
}

run_batch() {
    local config=$1
    local count=$2
    local pids=()
    local pid
    echo "[$(date +%T)] === ${config}: ${count} runs ==="
    for r in $(seq 0 $((count - 1))); do
        wait_for_slot
        run_one "$config" "$r" &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    echo "[$(date +%T)] === ${config} launched runs completed ==="
}

run_batch "Chapter52_Exp1_Density_Strong" "$EXP1_RUNS"
run_batch "Chapter52_Exp2_Ablation_Strong" "$EXP2_RUNS"

FAILS=0
for f in "$STATUS_DIR"/*.rc; do
    rc=$(cat "$f")
    if [ "$rc" != "0" ]; then
        echo "FAILED: $f exit=$rc"
        FAILS=$((FAILS + 1))
    fi
done

TOTAL=$(( $(date +%s) - START ))
echo "[$(date)] Strong parallel simulations finished in ${TOTAL}s with ${FAILS} failed runs"

if [ "$FAILS" -ne 0 ]; then
    exit 1
fi

if [ "$SKIP_POST" = "1" ]; then
    echo "[$(date +%T)] SKIP_POST=1, skipping aggregate + plot + check"
    exit 0
fi

echo "[$(date +%T)] Running strong aggregate + plot + check"
bash scripts/run_strong_all.sh --post-only > logs/run_strong_all_after_parallel.log 2>&1
RC=$?
tail -80 logs/run_strong_all_after_parallel.log
exit "$RC"
