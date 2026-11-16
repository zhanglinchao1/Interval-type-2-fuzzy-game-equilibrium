#!/bin/bash
# Run from the existing FuzzyVeins project. Original PHY, traffic and RNGs.
set -eo pipefail
cd "$(dirname "$0")/../.."
tool_root=$(realpath ../../..)
. "$tool_root/omnetpp-5.7/setenv" >/dev/null
export PATH="$tool_root/sumo/bin:$PATH"
. scripts/strong_launchd_common.sh
mkdir -p results/r3q5/traces results/r3q5/logs
ensure_launchd
trap cleanup_launchd EXIT
mode=${1:-smoke}
config=Chapter52_R3Q5_Strong
case "$mode" in
    smoke) runs="20"; duration=60s;;
    trace_on|trace_off) runs="20"; duration=60s; config="Chapter52_R3Q5_${mode}_Strong";;
    full) runs="$(seq 20 29) $(seq 110 119)"; duration=600s;;
    *) exit 2;;
esac
for r in $runs; do
    export R3Q5_TRACE="$PWD/results/r3q5/traces/${mode}_${r}.csv"
    if [ "$mode" = trace_off ]; then unset R3Q5_TRACE; fi
    started=$SECONDS
    opp_run_release -u Cmdenv -c "$config" -r "$r" \
        -n .:../../src/veins -l ../../out/clang-release/src/veins \
        --sim-time-limit="$duration" --cmdenv-express-mode=true --debug-on-errors=false \
        r3q5.ini > "results/r3q5/logs/${mode}_${r}.log" 2>&1
    echo "$mode run=$r duration=$duration wall_seconds=$((SECONDS-started)) PASS"
done
