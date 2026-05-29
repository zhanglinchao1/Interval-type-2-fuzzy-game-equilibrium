# FuzzyVeins Reproducibility Package

This repository packages the code and reproducibility assets for the FuzzyVeins
paper/thesis experiments.

## What this repo contains

- Veins scenario and simulation entry points: `run`, `omnetpp.ini`,
  `FuzzyTrustScenario.ned`, `FuzzyVeins*.sumo.cfg`, `FuzzyVeins*.rou.xml`,
  `FuzzyVeins*.launchd.xml`, `config.json`, `ablation_config.json`,
  `config.xml`, and `antenna.xml`.
- Experiment automation and plotting scripts under `scripts/`.
- MATLAB validation and theory checks under `code/matlab_sim/`.
- Minimal auxiliary test code under `results/`.
- All non-root Markdown documentation has been moved into `doc/`.

## How to run

This package is meant to sit inside a Veins checkout at:

```text
veins/examples/FuzzyVeins
```

The scripts and test harnesses rely on the Veins relative path layout, so the
external Veins source tree must still be available.

Typical commands:

```bash
./run -u Cmdenv -c Chapter52_M1_Smoke
./run -u Cmdenv -c FuzzyVeins
bash scripts/run_strong_all.sh --post-only
```

## Reproducibility notes

- Large logs, raw simulation outputs, cache directories, and intermediate
  figures are intentionally excluded.
- The `doc/` folder contains English documentation and paper drafts.
- If you want to rebuild the paper figures, run the aggregation and plotting
  scripts under `scripts/`.
