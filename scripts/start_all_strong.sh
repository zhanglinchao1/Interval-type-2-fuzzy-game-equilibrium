#!/bin/bash
#
# Full strengthened Chapter 5.2 entrypoint:
#   1. run Exp1 strong simulations
#   2. run Exp2 strong simulations
#   3. aggregate CSV summaries
#   4. generate figures
#   5. validate publication-oriented checks

set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/run_strong_all.sh --run-sim "$@"
