# Unified MAE Evaluation Guide

This document explains how to run the MAE evaluation workflow using the main
`omnetpp.ini` file.

## Main points

- Use the `MAE_Performance_Test` configuration to generate the MAE results.
- The MAE pipeline writes its outputs into `results/mae_performance/`.
- The unified setup replaces the older split-INI workflow with a single entry
  point.

## Usage

Run the evaluation from the FuzzyVeins directory with the Veins launcher and
the appropriate OMNeT++ configuration.
