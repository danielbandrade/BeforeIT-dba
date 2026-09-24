# Plan: BeforeIT explanation traces

## Objective

Create a comprehensive record of a small, fixed set of BeforeIT simulations so
that aggregate outcomes can be explained from the agent states, decisions,
constraints, and market events that produced them.

This is an explanatory dataset, not the input dataset for the large surrogate
experiment. Storage efficiency is secondary to retaining economically meaningful
information and unambiguous time and agent identities.

The first version should answer questions such as:

- Which agents and sectors initiated a recession or recovery?
- How did credit rationing propagate into employment and production?
- Which firm constraints became binding before an aggregate regime changed?
- How did income, deposits, wealth, and unemployment distributions evolve?
- Why did a policy or shock produce a different result from its paired baseline?

The resulting explanations remain conditional on BeforeIT's mechanisms. They do
not establish that the same causal relationships hold in the real economy.

## Implemented first experiment

The version-1 implementation records a paired Austrian 2010Q1 experiment:

- baseline calibration;
- firm loan-to-value limit `zeta_LTV` multiplied by 0.5;
- 12 quarters and three common seeds;
- credit allocation, employment transitions, production constraints, household
  distributions, and aggregate outcomes.

Run it from the repository root:

```bash
julia --project=. dba-studies/machine-learning/explanation-traces/run_experiment.jl
```

Run the focused regression check with:

```bash
julia --project=. dba-studies/machine-learning/explanation-traces/test/runtests.jl
```

The implementation lives in `src/explanation_traces.jl`. Generated experiments
are written under `experiments/` and are ignored by Git through the repository's
existing CSV and JLD2 rules.

Version 1 records innovations, firm refinancing, credit allocations, worker job
transitions, and binding production limits. Individual buyer/seller goods-market
matches remain deferred because the first research question does not require
them; the existing household-group purchase totals remain present in snapshots.

## Scope

### Included

- A complete initial observation and one observation after every simulated
  quarter.
- Every economically meaningful field stored in the model at those observation
  boundaries.
- Persistent identities for firms and households.
- Events whose information is created and discarded within a quarter.
- Metadata sufficient to reproduce and interpret each run.
- Derived macroeconomic, distributional, agent-panel, and event datasets.
- Paired baseline/intervention comparisons using common random seeds.

### Excluded from the first version

- Large parameter sweeps or surrogate training data.
- Full model snapshots after every function inside `step!`.
- A generic serialization framework for arbitrary Julia objects.
- Neural networks or another model chosen before the trace is inspected.
- Mid-run checkpoint restoration. Re-running from the recorded seed is enough
  initially.

Intermediate snapshots should only be added if a specific explanation cannot be
reconstructed from quarter-boundary states and events.

## Experimental design

Use a small, declared collection of scenarios. Each intervention must have a
paired baseline with the same calibration, initial conditions, horizon, and
seed. Run with `parallel = false` so event ordering and seeded reproduction are
unambiguous.

Every experiment specification must declare:

- research question;
- baseline and intervention scenarios;
- parameter, policy, or shock difference between each pair;
- simulation horizon;
- seed panel;
- outcomes and mechanisms to explain;
- expected observation and event coverage.

A single run may be used as a documented case study, but claims about a mechanism
across stochastic simulations require a small predeclared seed panel. Agent-period
rows within one run are dependent observations and must not be treated as
independent simulation replications.

## Observation boundary

The canonical state observation occurs after both calls in the standard run
loop:

```julia
Bit.step!(model; parallel = false)
Bit.collect_data!(model)
record_snapshot!(trace, model)
```

The initial observation is recorded immediately after `Bit.Model(...)` returns.
The constructor already collects the initial macroeconomic data, so a horizon of
`T` quarters produces exactly `T + 1` observations:

```text
t = 0       initialized model
t = 1..T    post-accounting, post-collection quarter states
```

Each observation must record both the trace period and `model.agg.t`. Events
created while advancing from `t - 1` to `t` are assigned to period `t`.

This boundary makes consecutive snapshots suitable for state-transition
analysis. Models of a decision made inside a quarter must use only information
available before that decision; later state fields cannot be included as
features.

## Raw trace contract

Store one raw JLD2 file per run. Save primitive scalars and copied arrays rather
than serializing the live `Model` object. This prevents mutable aliases between
periods and reduces coupling to Julia type definitions.

### 1. Run metadata

Record once per run:

- trace schema version;
- experiment, run, scenario, pair, and calibration identifiers;
- seed and horizon;
- baseline or intervention role;
- complete parameter and initial-condition inputs;
- declared shock or policy specification;
- country/calibration source;
- Git commit and dirty-worktree flag;
- Julia and BeforeIT versions;
- serial/parallel execution setting;
- creation timestamp, runtime, completion status, and failure reason.

### 2. Static model information

Record values that do not change during a run once:

- model properties;
- initial aggregate history used by expectations;
- sector and product definitions;
- initial entity IDs and structural dimensions;
- field inventory and field classifications used by the extractor.

Do not repeat static parameters inside every period.

### 3. Quarter-boundary snapshots

For every observation, copy the economically meaningful fields of:

- `model.w_act`;
- `model.w_inact`;
- `model.firms`;
- `model.bank`;
- `model.cb`;
- `model.gov`;
- `model.rotw`;
- `model.agg`;
- the current observation in `model.data`.

Store agent arrays with their persistent `ID` vectors. Never use current vector
position as agent identity: deletion can swap the last agent into a removed
position. Store `lastid` when needed to interpret lifecycle events.

Cumulative histories such as `agg.Y`, `agg.pi_`, and the vectors in `model.data`
must not be copied in full every quarter. Store the initial prefix once and the
new observation at each period so the complete histories remain reconstructible.

Runtime bookkeeping such as `id_to_index` may be excluded when it can be rebuilt
exactly from IDs. Every exclusion must be documented in the field inventory;
unclassified fields are an error rather than a silent omission.

### 4. Within-quarter events

Quarter snapshots cannot recover information held only in local variables. Add
targeted event recording for:

- exogenous shocks and random innovations;
- firm insolvency and refinancing;
- requested, granted, and rationed credit by firm;
- hires, separations, vacancies, and occupation changes;
- desired versus realized production inputs and the binding production
  constraint;
- domestic and imported purchases, unmet demand, and buyer/seller/product
  identities where the matching information would otherwise disappear;
- other state-changing events identified by the reconstructability audit.

Each event must contain:

```text
run_id, period, stage, event_type,
actor_type, actor_id, counterparty_type, counterparty_id,
product_or_sector, quantity, value, reason
```

Only applicable fields need values. Event recording must not draw randomness or
change execution order.

## Storage layout

Use dependencies already present in the repository:

- JLD2 for raw per-run traces;
- CSV for manifests and derived rectangular tables;
- TOML for experiment specifications.

Planned generated layout:

```text
explanation-traces/
├── explanation-trace-plan.md
├── experiments/
│   └── <experiment-id>/
│       ├── specification.toml
│       ├── runs.csv
│       ├── traces/
│       │   └── <run-id>.jld2
│       └── derived/
│           ├── periods.csv
│           ├── firms.csv
│           ├── households.csv
│           └── events.csv
└── src/
```

Do not create the empty implementation directories until their phase begins.
Generated experiment data should be ignored by Git; specifications, schema
documentation, and analysis code should remain versioned.

## Derived explanation datasets

Raw traces are immutable. Build task-specific tables from them rather than
altering or replacing the raw record.

### Period table

One row per run and quarter containing the existing `model.data` fields plus
explanatory aggregates such as:

- unemployment and employment rates;
- bankrupt/refinanced firm count and exposure;
- requested, granted, and rationed credit;
- income, deposit, wealth, wage, profit, and firm-size quantiles;
- Gini or other declared distribution measures;
- sector concentration and sector growth;
- shares of firms constrained by demand, labour, capital, and materials;
- desired-realized gaps for production, employment, investment, and credit.

### Firm panel

One row per run, quarter, and persistent firm ID. It should support transition
targets such as insolvency, credit rationing, contraction, recovery, and entry or
exit without using future information as a feature.

### Household panel

One row per run, quarter, household group, and persistent household ID. Firm and
bank owners must remain identifiable as household roles even though their fields
are stored inside the firm and bank components.

### Event table

One row per event. Preserve actor and counterparty IDs so networks, cascades, and
event sequences can be reconstructed.

## Candidate explanation methods

Method choice follows the recorded research question and diagnostics:

1. Paired trajectory decomposition for baseline/intervention explanations.
2. Change-point detection for the start of recessions, recoveries, or cascades.
3. Clustering of period-level states for descriptive economic regimes.
4. Interpretable trees or sparse models for early-warning indicators.
5. Firm or household transition models for bankruptcy, unemployment, and income
   loss.
6. Network or cascade analysis when counterparty events are available.
7. Dimensionality reduction for visualization of high-dimensional state paths.

Validation splits must be made by run or paired scenario, never by randomly
splitting agent-period rows from the same simulation. Results from a small fixed
trace collection are explanatory case-study evidence, not a generally validated
predictive model.

## Implementation phases

### Phase 1 — Inventory and schema

1. Enumerate every field in the current model components.
2. Classify each field as static, dynamic, cumulative history, derived runtime
   bookkeeping, or excluded with rationale.
3. Define units, entity grain, observation timing, and missing-value rules.
4. Define the first experiment and paired scenarios.

**Exit condition:** every current field is classified and every exclusion is
reviewed.

### Phase 2 — Quarter snapshots

1. Implement the smallest study-local snapshot extractor.
2. Record initialization and post-collection observations around the existing
   serial simulation loop.
3. Save one JLD2 trace per run and one CSV run manifest.
4. Convert one trace into period, firm, and household tables.

Do not modify core simulation behavior in this phase.

**Exit condition:** a short seeded run round-trips through JLD2, contains exactly
`T + 1` observations, and reproduces every included model field at each boundary.

### Phase 3 — Reconstructability audit and events

1. Select one aggregate outcome and trace its mechanism backward through the
   quarter states.
2. List causal information that snapshots cannot reconstruct.
3. Add only the event hooks required to preserve that information.
4. Reconcile event totals with state changes and accounting aggregates.

**Exit condition:** the selected mechanism can be explained from the saved trace
without inspecting a live model or rerunning it.

### Phase 4 — Curated trace generation

1. Freeze the experiment specification and trace schema.
2. Run every baseline/intervention pair with the declared seed panel.
3. Preserve failures in the manifest.
4. Generate derived tables without modifying raw traces.

**Exit condition:** every expected run is present or has a recorded failure, and
all paired runs align by seed and period.

### Phase 5 — Explanation analysis

1. Produce paired macro and distributional trajectories.
2. Identify candidate regime transitions or outcome divergences.
3. Connect each divergence to agent states, constraints, and recorded events.
4. Apply the simplest candidate method that answers the research question.
5. Report uncertainty across the seed panel and distinguish recurring mechanisms
   from single-run events.

**Exit condition:** each reported explanation links an intervention to agent
decisions or events, distributional changes, and the final aggregate outcome.

## Required checks

- Tracing enabled and disabled produce identical simulation results.
- Recording does not consume random numbers.
- Identically seeded serial runs produce identical traces.
- Every snapshot owns its arrays; later mutation cannot change earlier periods.
- All saved agent arrays have the same length as their corresponding ID vector.
- IDs are unique within entity type and run.
- Observation times are monotonic and equal the declared horizon.
- Required numeric values are finite, with documented exceptions.
- Existing accounting-identity tests still pass.
- Derived totals reconcile with raw states and recorded events.
- JLD2 save/load preserves values and types needed by the analysis.
- A schema change increments the trace schema version and fails clearly when an
  incompatible reader is used.

## Completion criteria

The first explanation-trace implementation is complete when one predeclared,
paired experiment can be regenerated from scratch and its aggregate divergence
can be followed through:

```text
intervention
  -> agent decisions and constraints
  -> market and lifecycle events
  -> distributional changes
  -> aggregate outcome
```

The implementation should stop there. Additional event types, intermediate
stages, storage formats, and ML methods are added only when a concrete explanation
cannot be produced from the existing trace.
