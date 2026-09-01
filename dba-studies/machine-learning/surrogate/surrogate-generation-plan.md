# Plan: BeforeIT surrogate generation, version 2

## Objective

Build and validate a fast approximation of expected 12-quarter BeforeIT
outcomes:

$$
\hat f(\theta) \approx \mathbb{E}[S(\theta,\varepsilon)\mid\theta].
$$

The surrogate will predict configuration-level expected macroeconomic outcomes,
not individual agents or a single stochastic simulation path.

## Current status

- The legacy eight-input pilot is archived and is not evidence for parameter
  importance or predictive accuracy.
- The calibrated model contains 63 entries; the previous inventory marked 53 as
  possible screening candidates.
- No final input set or experimental domain is approved.
- No new simulations should be generated until Gate 1 passes.

## Non-goals for the first validated model

- Reproducing every agent state or complete trajectory.
- Treating structural dimensions as ordinary continuous inputs.
- Training a neural network before a linear baseline is shown to be inadequate.
- Extrapolating outside the approved parameter domain.

## Phase 1 — Approve the experimental domain

Create one reviewed parameter-domain table with, for every calibrated entry:

- economic meaning and source equation;
- baseline value, type, and shape;
- independent, grouped, structural, derived, or fixed classification;
- lower and upper bounds or a structure-preserving transformation;
- sign, probability, accounting, and joint constraints;
- retain/exclude decision with rationale.

Do not use mechanical ±20% bounds as approval. They may be starting suggestions,
but every bound must preserve the parameter's economic meaning. In particular,
enforce joint restrictions such as `psi + psi_H <= 1` through the sampling
parameterization rather than repairing samples afterward.

**Gate 1:** every candidate has an approved domain or a documented exclusion;
no entry remains `REVIEW REQUIRED`.

## Phase 2 — Measure stochastic noise

Before screening parameter effects, run the baseline and a small set of feasible
sentinel configurations under repeated seeds.

- Use the same seed panel for every configuration where practical.
- Increase seeds in batches until target means and standard errors stabilize.
- Record every run, failure, runtime, target mean, standard deviation, and
  standard error.
- Define the smallest effect worth modeling for each primary target.

The seed count is determined by convergence, not by convenience. Five seeds may
be used for pipeline testing but must not automatically become the final count.

**Gate 2:** Monte Carlo uncertainty is small enough to distinguish the minimum
effect of interest, or the experiment is redesigned.

## Phase 3 — Global sensitivity screening

Run Morris elementary-effects screening over all approved scalar candidates and
approved grouped perturbations.

- Use common random numbers to separate parameter effects from simulation noise.
- Compute $\mu^*$ and $\sigma$ for every primary target.
- Compare each effect with the noise floor from Phase 2.
- Retain inputs based on influence, interaction/nonlinearity, identifiability,
  and economic or policy relevance.
- Confirm the shortlist with full-scale spot checks.

Do not impose a desired number of inputs. Record why every candidate was retained
or excluded.

**Gate 3:** the focused input set is supported by sensitivity results and
full-scale confirmation.

## Phase 4 — Generate the focused dataset

Sample a space-filling design inside the feasible transformed domain.

Initial focused pilot:

- 100 distinct parameter configurations;
- the seed count approved in Phase 2, with five as the pipeline-test minimum;
- 12 simulated quarters;
- identical target definitions and seed policy across configurations.

If diagnostics justify expansion, target approximately 500 configurations and
10–20 seeds per configuration. Do not schedule the expansion in advance.

Every experiment must use a unique immutable run directory containing:

- experiment specification and parameter domain;
- configurations and split IDs;
- raw run index, seeds, failures, and runtimes;
- complete trajectories;
- derived configuration-level targets;
- Git commit, Julia version, manifest hash, and model calibration identifier.

Generation must be restartable without deleting completed runs. Failed runs stay
in the index and are never silently replaced or discarded.

**Gate 4:** all expected runs are accounted for, trajectories pass finite-value
and horizon checks, and failure patterns are understood.

## Phase 5 — Construct targets and partitions

Preserve all aggregate series already exposed by `model.data`. For the first
surrogate, derive:

1. Real GDP growth after 12 quarters.
2. Mean quarterly real GDP growth.
3. Maximum GDP decline from the initial level.
4. Mean implicit GDP inflation.
5. Final real household consumption.
6. Final real capital formation.
7. Final real exports and imports.
8. Final wages.

For each target and configuration, store the seed-level values, mean, standard
deviation, seed count, and standard error.

Split by configuration before fitting or model selection. For the 100-point
pilot, use a recorded 70/15/15 train/validation/test split. Never place different
seeds from one configuration in different partitions.

**Gate 5:** target definitions are tested, partitions are immutable, training
has more observations than fitted coefficients, and validation/test sets are
large enough for finite metrics.

## Phase 6 — Fit the baseline surrogate

Fit a standardized linear ridge model first.

- Estimate preprocessing only from training configurations.
- Select regularization using validation data or configuration-level
  cross-validation.
- Inspect residuals by target and across the parameter domain.
- Estimate approximation error from held-out residuals, never training
  residuals.
- Combine approximation error with the appropriate simulation uncertainty:
  standard error for expected outcomes, full variance for individual-run
  predictions.

Only compare one simple nonlinear alternative if residual evidence shows that
the linear model misses relevant structure. Use the same partitions and metrics.

**Gate 6:** the selected model improves on a mean-only predictor and has no
unresolved systematic residual pattern.

## Phase 7 — Validate and accept

Evaluate once on the untouched test configurations, then run fresh BeforeIT
simulations at the baseline, interior points, boundary points, and high-impact
regions.

Report for every target:

- MAE and RMSE;
- NRMSE using a predeclared, non-degenerate scale;
- R² only when mathematically defined;
- bias by region of the parameter domain;
- nominal interval width and empirical coverage;
- BeforeIT and surrogate runtimes.

Target-specific error and coverage thresholds must be declared after the noise
study and before fitting. Undefined metrics, collapsed intervals, or fresh
validation outside the declared tolerance fail the gate.

**Gate 7:** all predeclared accuracy, coverage, domain, and reproducibility
conditions pass. Otherwise return to the earliest failed phase.

## Required implementation safeguards

- Refuse training when any partition is too small.
- Refuse evaluation when required metrics are undefined.
- Reject prediction outside the approved transformed domain.
- Validate all joint constraints before simulation and prediction.
- Keep configuration IDs and seeds unique and reproducible.
- Never calibrate uncertainty on training residuals.
- Never overwrite a completed experiment directory.
- Make the final notebook restart-and-run-all clean and fail visibly when an
  upstream artifact is missing or incompatible.

## Planned active artifacts

```text
surrogate/
├── README.md
├── surrogate-generation-plan.md
├── experiment.toml             # approved domain and run specification
├── parameter-domain.csv        # review and inclusion decisions
├── screening/                  # Morris design, runs, and rankings
├── experiments/<run-id>/       # immutable generated datasets and results
├── src/                        # pipeline scripts after their phase is approved
└── surrogate-analysis.ipynb    # report, not the source of pipeline logic
```

Only the two documentation files exist initially. Other artifacts are created
when their preceding gate passes.

## Immediate next action

Create and review `parameter-domain.csv`. Begin with the archived inventory, but
verify economic meanings, constraints, and source equations before approving any
range. The first implementation task starts only after that review.
