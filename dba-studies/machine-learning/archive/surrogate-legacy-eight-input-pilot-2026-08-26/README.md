# BeforeIT surrogate model

Open `surrogate-complete-analysis.ipynb` for the end-to-end parameter inventory,
screening, dataset diagnostics, training results, and validation workflow.

Run the pipeline from the repository root:

```bash
julia --project=. dba-studies/machine-learning/surrogate/inventory_parameters.jl
julia --project=. dba-studies/machine-learning/surrogate/generate_dataset.jl
julia --project=. dba-studies/machine-learning/surrogate/summarize_dataset.jl
julia --project=. dba-studies/machine-learning/surrogate/train_surrogate.jl
julia --project=. dba-studies/machine-learning/surrogate/evaluate_surrogate.jl
```

Review `parameter-inventory.csv` and define valid ranges and grouped
perturbations before dataset generation. The generator still implements the
older eight-input pipeline check; do not use it for final screening results.

Dataset generation defaults to 100 configurations, five seeds, and 12 simulated
quarters. Override those values for a smaller check or a larger experiment:

```bash
SURROGATE_CONFIGURATIONS=10 SURROGATE_SEEDS=2 julia --project=. dba-studies/machine-learning/surrogate/generate_dataset.jl
```

Generated trajectories, tables, metadata, and fitted results are ignored by
Git. The generator records the initial state plus one observation per simulated
quarter, so the default trajectories contain 13 observations.
