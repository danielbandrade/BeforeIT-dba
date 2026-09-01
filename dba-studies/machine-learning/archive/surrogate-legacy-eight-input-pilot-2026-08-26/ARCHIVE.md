# Archived surrogate pilot

Archived on 2026-08-26 before starting the second surrogate-generation design.

This directory preserves the complete legacy eight-input pilot:

- parameter inventory and original plan;
- dataset-generation, aggregation, training, and evaluation scripts;
- executed analysis notebook;
- three-configuration, one-seed dataset and trajectories;
- fitted coefficients, predictions, metrics, and fresh validation.

## Interpretation

The pilot verified that the pipeline could generate simulations, derive targets,
fit a model, and reload it for prediction. It did not identify influential
parameters or validate a usable surrogate.

Its dataset contained three configurations with one seed each. The resulting
split used two configurations for training and one for testing. NRMSE was
undefined, R² was negative infinity, and the nominal 90% intervals covered none
of the nine fresh-simulation means. These artifacts must not be used for
scientific inference.

The directory is retained as historical evidence and should remain unchanged.
The active replacement plan lives at
`../../surrogate/surrogate-generation-plan.md`.
