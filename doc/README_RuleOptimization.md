# Rule Weight Optimization Notes

This document summarizes the rule-weight optimization logic used by the fuzzy
inference engine.

## Highlights

- Tracks decision quality over time.
- Adjusts rule weights periodically based on recent performance.
- Supports logging and analysis of the optimization process.

## Reproducibility

The implementation is included for reference and can be exercised through the
existing simulation and test scripts in this repository.
