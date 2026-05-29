#!/bin/bash
#
# Chapter 5.2 strengthened pipeline.
#
# Default mode is post-processing only, because the full strengthened
# simulation batch is long-running:
#   bash scripts/run_strong_all.sh
#
# Run the full sequential strengthened Exp1 + Exp2 batch, then post-process:
#   bash scripts/run_strong_all.sh --run-sim
#
# For parallel full simulation, use:
#   PARALLEL_JOBS=24 bash scripts/run_strong_parallel.sh

set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="scripts/result_strong"
EXP1_ROOT="results/chapter52_strong/Chapter52_Exp1_Density_Strong"
EXP2_ROOT="results/chapter52_strong/Chapter52_Exp2_Ablation_Strong"
RUN_SIM=0

usage() {
    cat <<EOF
Usage: bash scripts/run_strong_all.sh [--run-sim|--post-only]

  --run-sim     Run strengthened Exp1 (120 runs) and Exp2 (50 runs), then aggregate/plot/check.
  --post-only   Aggregate/plot/check existing strengthened results only. This is the default.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --run-sim)
            RUN_SIM=1
            ;;
        --post-only)
            RUN_SIM=0
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/matplotlib-${USER:-fuzzyveins}}"
mkdir -p "$MPLCONFIGDIR"

if [ "$RUN_SIM" -eq 1 ]; then
    echo "[$(date)] Running strengthened Exp1 full batch..."
    bash scripts/run_exp1_strong.sh
    echo "[$(date)] Running strengthened Exp2 full batch..."
    bash scripts/run_exp2_strong.sh
else
    echo "[$(date)] Post-processing existing strengthened results."
    if ! find "$EXP1_ROOT" -name metrics.csv -print -quit 2>/dev/null | grep -q .; then
        echo "ERROR: No Exp1 metrics found under $EXP1_ROOT" >&2
        echo "       Run: bash scripts/run_strong_all.sh --run-sim" >&2
        echo "       Or:  PARALLEL_JOBS=24 bash scripts/run_strong_parallel.sh" >&2
        exit 1
    fi
    if ! find "$EXP2_ROOT" -name metrics.csv -print -quit 2>/dev/null | grep -q .; then
        echo "ERROR: No Exp2 metrics found under $EXP2_ROOT" >&2
        echo "       Run: bash scripts/run_strong_all.sh --run-sim" >&2
        echo "       Or:  PARALLEL_JOBS=24 bash scripts/run_strong_parallel.sh" >&2
        exit 1
    fi
fi

python3 scripts/aggregate_chapter52_strong.py
python3 scripts/plot_chapter52_strong.py --out-dir "$OUT_DIR"
python3 scripts/analyze_chapter52_strong.py --fig-dir "$OUT_DIR"
python3 scripts/check_figures_strong.py

echo "Done. Strong figures: $OUT_DIR"
