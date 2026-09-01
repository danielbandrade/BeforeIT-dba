# Plan: surrogate model for BeforeIT

## Objective

Build a fast statistical approximation of the baseline `Bit.Model` that maps an
empirically screened set of economically meaningful parameters to simulation
outcomes over a 12-quarter horizon.

The first surrogate will estimate expected scalar outcomes, not reproduce every
agent or every point in every time series:

$$
\hat{f}(\theta)
\approx
\mathbb{E}\left[S(\theta,\varepsilon)\mid\theta\right]
$$

Here, $S$ is BeforeIT, $\theta$ is a parameter configuration, and
$\varepsilon$ represents stochastic simulation draws.

## MVP scope

### Inputs

Do not fix the surrogate inputs in advance. First inventory every calibrated
parameter, remove variables that are not valid independent experimental inputs,
and use global sensitivity screening to select the final set.

The candidate inventory should classify each parameter as:

- independently variable continuous or categorical input;
- jointly constrained input;
- calibrated initial condition;
- derived or accounting quantity;
- identifier or structural dimension;
- fixed institutional or external-series value.

The screening pool includes the first two categories. Hold structural dimensions
such as the number of firms, sectors, households, government entities, and
foreign consumers fixed so that sensitivity is not confused with model scale.

### Outputs

Record every time series already present in `model.data` for every simulation:

| Category | Recorded fields |
|---|---|
| Time | `collection_time` |
| Output | `nominal_gdp`, `real_gdp`, `nominal_gva`, `real_gva` |
| Household consumption | `nominal_household_consumption`, `real_household_consumption` |
| Government consumption | `nominal_government_consumption`, `real_government_consumption` |
| Capital formation | `nominal_capitalformation`, `real_capitalformation`, `nominal_fixed_capitalformation`, `real_fixed_capitalformation`, `nominal_fixed_capitalformation_dwellings`, `real_fixed_capitalformation_dwellings` |
| External sector | `nominal_exports`, `real_exports`, `nominal_imports`, `real_imports` |
| Income and production | `operating_surplus`, `compensation_employees`, `wages`, `taxes_production` |
| External conditions | `gdp_deflator_growth_ea`, `real_gdp_ea`, `euribor` |
| Sector output | `nominal_sector_gva`, `real_sector_gva` |

The extraction must iterate over `fieldnames(typeof(model.data))` so newly added
aggregate fields are not silently omitted. Preserve original names, period
ordering, and numeric precision.

The initial surrogate will train on a smaller derived target set:

1. Real GDP growth after 12 quarters.
2. Mean quarterly real GDP growth.
3. Maximum GDP decline from the initial level.
4. Mean implicit GDP inflation.
5. Final real household consumption.
6. Final real capital formation.
7. Final real exports and imports.
8. Final wages.

For nominal and real GDP:

$$
P_t^{GDP}=\frac{GDP_t^{nominal}}{GDP_t^{real}}
$$

$$
\pi_t^{GDP}=\log\left(\frac{P_t^{GDP}}{P_{t-1}^{GDP}}\right)
$$

All other recorded aggregate variables remain available for later target
selection without rerunning simulations. Do not add inequality, unemployment,
bankruptcy, or credit-rationing targets until the baseline surrogate works;
those are not currently present in `model.data` and require additional data
collection.

## Experimental design

### 1. Inventory and classify candidate inputs

Extract all entries from the calibrated parameter dictionary and trace where
each is used in the model. Record its economic meaning, equation or mechanism,
baseline value, type, constraints, and whether it can be varied independently.

Exclude a parameter only with a recorded reason. The inventory, rather than the
provisional eight-input list, defines the universe considered by the study.

### 2. Define valid parameter ranges

For each eligible candidate, define a lower and upper bound around its calibrated
value. Begin with a conservative interval, such as ±20%, while preserving
economic constraints:

$$
0\leq\psi,\psi_H,\theta_{UB},\theta_{DIV},\theta,\zeta,\zeta_{LTV}\leq1
$$

$$
\mu\geq0
$$

Record the exact baseline value and bounds in the dataset metadata. Do not infer
validity merely from a numerical interval when parameters have joint economic
constraints.

### 3. Global sensitivity screening

Use a Morris elementary-effects design as the first screening method. It is
suited to many inputs and separates overall influence from nonlinear or
interaction-heavy behavior without requiring a full high-dimensional surrogate.

For input $j$, summarize the elementary effects using:

$$
\mu_j^*=\frac{1}{R}\sum_{r=1}^{R}|EE_{j,r}|
$$

$$
\sigma_j=\sqrt{\frac{1}{R-1}\sum_{r=1}^{R}(EE_{j,r}-\bar{EE}_j)^2}
$$

Here, high $\mu_j^*$ indicates an influential input, while high $\sigma_j$
suggests nonlinearity or interactions. Run the screening at a reduced but tested
model scale and use multiple seeds or common random numbers to distinguish
parameter effects from simulation noise.

Select the focused input set using all of the following evidence:

- influence on at least one primary output;
- nonlinear or interaction effects;
- effect larger than stochastic variation;
- theoretical or policy relevance;
- sufficiently independent variation to be identifiable.

Do not impose a fixed number of selected inputs. Record rankings and the reason
for retaining or excluding every candidate. Confirm the shortlist with a smaller
full-scale experiment before training the final surrogate.

### 4. Sample focused configurations

Use space-filling random sampling across the selected parameter domain. The
initial focused pilot should contain:

- 100 distinct parameter configurations.
- 5 random seeds per configuration.
- 12 simulated quarters per run.
- 500 total simulations.

If the pipeline is stable, expand to approximately 500 configurations and
10–20 seeds per configuration.

### 5. Preserve stochastic variation

Each configuration must be simulated under multiple random seeds. Store every
individual run and also compute the mean and standard deviation by configuration:

$$
\bar{y}(\theta)=\frac{1}{R}\sum_{r=1}^{R}y(\theta,\varepsilon_r)
$$

$$
s_y(\theta)=
\sqrt{\frac{1}{R-1}\sum_{r=1}^{R}
\left(y(\theta,\varepsilon_r)-\bar{y}(\theta)\right)^2}
$$

The MVP predicts $\bar{y}(\theta)$. A later model may predict both the mean and
simulation variance.

## Dataset

Save the complete `model.data` object from each run as JLD2. This preserves all
time-series fields, including nested sector-GVA vectors, without flattening or
losing type information.

Maintain a separate run index with one row per parameter configuration and seed:

| Group | Columns |
|---|---|
| Identity | `configuration_id`, `seed`, `horizon` |
| Inputs | All screened parameters, with a flag identifying the final selected set |
| Raw output | Path to the complete JLD2 trajectory |
| Diagnostics | Runtime, success flag, failure reason |

Generate flat training tables from these immutable raw trajectories. Do not use
the training table as the only copy of simulation output.

Save raw trajectories separately from derived targets and aggregates:

```text
dba-studies/machine-learning/surrogate/
├── generate_dataset.jl
├── summarize_dataset.jl
├── data/
│   ├── raw_runs.csv
│   ├── configurations.csv
│   ├── trajectories/
│   │   └── <configuration_id>_<seed>.jld2
│   ├── scalar_targets.csv
│   └── metadata.toml
├── train_surrogate.jl
├── evaluate_surrogate.jl
└── results/
```

These files are planned deliverables, not part of this planning step.

## Implementation phases

### Phase 1: deterministic pipeline check

1. Copy the standard calibration dictionaries before modifying parameters.
2. Set a known random seed.
3. Construct `Bit.Model(parameters, initial_conditions)`.
4. Run `Bit.run!(model, 12)`.
5. Save every field of `model.data` to one JLD2 trajectory.
6. Derive the initial scalar targets from the saved trajectory.
7. Reload the trajectory and assert every field matches the in-memory data.
8. Repeat the identical run and assert identical outputs.

**Exit condition:** one configuration can be run reproducibly, all aggregate
series survive a save/reload round trip, and the derived targets are valid.

### Phase 2: parameter inventory and screening

1. Build the complete classified parameter inventory.
2. Define valid individual and joint ranges for eligible candidates.
3. Run the Morris design at a reduced, validated scale.
4. Rank inputs separately for every target and compare effects with seed noise.
5. Record retention and exclusion decisions.
6. Confirm the shortlist with selected full-scale runs.

**Exit condition:** an auditable shortlist supported by sensitivity results,
stochastic-noise estimates, economic reasoning, and full-scale spot checks.

### Phase 3: focused pilot dataset

1. Generate 100 valid parameter configurations.
2. Run five seeds per configuration.
3. Save each completed run immediately so an interruption loses at most one run.
4. Record failed simulations rather than silently dropping them.
5. Check every recorded `model.data` field for missing, infinite, inconsistent,
   or economically impossible values.
6. Confirm every successful run has exactly the expected number of periods in
   every non-sector and sector series.

**Exit condition:** 500 auditable complete trajectories with configuration and
seed metadata, plus a reproducible derived-target table.

### Phase 4: baseline surrogate

Fit one regularized linear regression per outcome using existing Julia standard
libraries first:

$$
\hat{y}=\beta_0+\sum_{j=1}^{p}\beta_j\theta_j
$$

Standardize inputs using statistics computed from the training set only. The
linear model is both a baseline and an interpretable sensitivity summary.

**Exit condition:** saved coefficients, predictions, and held-out metrics for
every outcome.

Here, $p$ is the number of inputs retained by screening, not a predetermined
value.

### Phase 5: nonlinear surrogate

Only if the linear baseline fails, add one tree-based model dependency and fit a
nonlinear model to the same split. Prefer a single direct dependency rather than
introducing a general ML framework.

Compare the nonlinear model against the linear baseline. Keep it only when the
held-out improvement is material.

**Exit condition:** choose the simplest model that meets the validation gate.

### Phase 6: uncertainty

Estimate stochastic uncertainty separately from mean prediction error. The
minimum version stores residual quantiles by outcome. A later version may train
models for conditional variance or quantiles.

The reported interval should combine:

```text
uncertainty from stochastic simulation
    +
surrogate approximation error
```

**Exit condition:** predictions include an empirically validated interval and
not only a point estimate.

## Validation

### Split correctly

Split by `configuration_id`, not by individual simulation row. All seeds for one
configuration must remain in the same partition; otherwise the test set leaks
near-duplicate inputs from training.

Suggested split:

- 70% configurations for training.
- 15% for validation.
- 15% for final testing.

### Metrics

Report for each output:

$$
MAE=\frac{1}{n}\sum_{i=1}^{n}|y_i-\hat{y}_i|
$$

$$
NRMSE=
\frac{\sqrt{\frac{1}{n}\sum_{i=1}^{n}(y_i-\hat{y}_i)^2}}
{Q_{0.95}(y)-Q_{0.05}(y)}
$$

Also report $R^2$, interval coverage, BeforeIT runtime, surrogate runtime, and
speedup.

### Initial acceptance gate

The MVP is useful when:

- Median test NRMSE across outputs is at most 10%.
- No primary output has test NRMSE above 20%.
- Nominal 90% prediction intervals cover 85–95% of held-out outcomes.
- Surrogate inference is at least 100 times faster than one BeforeIT ensemble.
- Errors show no obvious trend across parameter values.

These thresholds are provisional and should be revised if stochastic simulation
noise is already larger than the proposed surrogate error.

## Guardrails

1. Reject predictions outside the sampled parameter bounds.
2. Never use the surrogate as evidence outside its training domain.
3. Preserve random seeds and complete parameter dictionaries for reproducibility.
4. Compare policy conclusions against fresh BeforeIT simulations.
5. Do not interpret feature importance as causal identification.
6. Keep the original model as the source of truth.
7. Publish the full candidate inventory and sensitivity rankings, including
   excluded parameters, to prevent selection from becoming a hidden assumption.

## Later extensions

Add these only after the MVP passes validation:

1. Full quarterly trajectories instead of scalar summaries.
2. Inequality measures derived from household income, deposits, and capital.
3. Unemployment, bankruptcies, and credit-rationing targets.
4. Multiple model variants: `Model`, `ModelGR`, and `ModelCANVAS`.
5. Multiple countries and calibration dates.
6. Active learning that requests new simulations where surrogate uncertainty is
   largest.
7. Simulation-based Bayesian parameter inference using the validated surrogate.

## Definition of done

The surrogate project is complete when a fresh parameter configuration can be:

1. Checked against the supported domain.
2. Evaluated by the surrogate with uncertainty intervals.
3. Compared automatically with a fresh BeforeIT ensemble.
4. Reproduced from saved configuration, seed, data, and model metadata.

Stop there. Policy optimization and learned agent behaviour are separate
projects and should not be added to this implementation.
