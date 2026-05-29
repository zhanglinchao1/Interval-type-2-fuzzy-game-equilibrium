#!/bin/bash
# Compatibility wrapper for the misspelled entrypoint name.

set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/start_all_strong.sh "$@"
