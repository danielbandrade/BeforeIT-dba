# Plan: complete quarterly model snapshots

## Objective

Save the complete BeforeIT model state at the end of every simulated quarter so
that a small, controlled set of simulations can later support comprehensive data
analysis and machine-learning research.

The raw dataset is an archive of model states. It must not anticipate which
variables or methods will matter later. Analysts should be able to load any
quarter and inspect every field that existed in the model at that boundary.

This dataset is intended for explanation and exploration, not large parameter
sweeps. Storage efficiency is therefore secondary to completeness and clarity.

The first concrete use case is a time-flowing heatmap of firm behavior: firms on
the vertical axis, quarters on the horizontal axis, and color representing one
firm variable. This view should make coordinated changes, heterogeneous
responses, sector patterns, distress, and recovery visible as they emerge.

## Core decision

Create **one immutable JLD2 file per run and quarter**. Each file stores the full
`model` object rather than a selected-field dictionary.

For a simulation with horizon `T`, write exactly `T + 1` snapshots:

```text
quarter 0      initialized model
quarter 1..T   model after the quarter and data collection
```

The initial snapshot makes changes relative to the starting state observable.

## Implemented pipeline

Schema version 2 implements this contract in `src/explanation_traces.jl`:

- `run_experiment.jl` reads `experiment.toml` and writes one snapshot directory
  per run;
- every snapshot contains the complete concrete `Model` plus identifying
  metadata;
- every write is round-trip validated before its temporary file is renamed;
- `runs.csv` records coverage, size, runtime, provenance, and failures;
- firm panels and stable firm-by-quarter matrices are derived directly from the
  snapshots;
- `explanation-trace-eda.ipynb` produces the static and time-flowing firm heatmap
  with a synchronized aggregate trajectory.

## What “complete state” means

Each snapshot must preserve every field reachable from the model:

- `model.w_act`;
- `model.w_inact`;
- `model.firms`;
- `model.bank`;
- `model.cb`;
- `model.gov`;
- `model.rotw`;
- `model.agg`;
- `model.prop`;
- `model.data`;
- all IDs, lookup dictionaries, reference values, arrays, histories, and
  bookkeeping fields contained in those objects;
- fields added by supported model extensions through their concrete model type.

There is no field whitelist and no economic-versus-runtime classification in the
raw format. If the model owns a field at the observation boundary, the snapshot
owns it too.

“Complete” refers to the model at a quarter boundary. It does not include local
variables that exist only inside a function during the quarter. It also does not
make the file a process checkpoint: executable code and Julia's global random
number generator are outside the `Model` object. The run seed and software
versions are recorded for reproducibility. Exact mid-run continuation can add an
RNG checkpoint later if it becomes a requirement.

## Observation boundary

Use the existing serial simulation order:

```julia
model = Bit.Model(parameters, initial_conditions)
save_snapshot!(model, 0)

for quarter in 1:horizon
    Bit.step!(model; parallel = false, shock!)
    Bit.collect_data!(model)
    save_snapshot!(model, quarter)
end
```

This creates a consistent end-of-quarter view after accounting and data
collection. Snapshot capture must not mutate the model, consume randomness, or
change simulation order.

## Snapshot file contract

Each JLD2 file contains:

```text
schema_version
experiment_id
run_id
scenario_id
seed
horizon
quarter
model_time
captured_at_utc
model
```

`model` is the complete concrete BeforeIT model object at that boundary. The
other keys let an individual file be identified without consulting a separate
table.

Files are written to a temporary path, loaded once for validation, and then
atomically renamed to their final path. A completed snapshot is never silently
overwritten.

JLD2 is already a project dependency and supports the Julia-native structures
used by BeforeIT. These files are project artifacts, not a version-independent
exchange format: loading them requires compatible BeforeIT and Julia code.

## Experiment metadata

Each run also needs enough context to interpret its snapshots:

- experiment and scenario identifiers;
- research question and scenario description;
- calibration, parameters, and initial conditions;
- shock or policy configuration;
- seed and horizon;
- Git commit and dirty-worktree flag;
- Julia and BeforeIT versions;
- start time, completion status, runtime, and failure reason;
- expected and successfully written quarters.

Store experiment inputs in a versioned TOML specification and run outcomes in a
CSV manifest. The model state itself remains in the quarterly JLD2 files.

## Storage layout

```text
explanation-traces/
├── explanation-trace-plan.md
├── experiment.toml
├── run_experiment.jl
├── src/
├── test/
└── experiments/
    └── <experiment-id>/
        ├── specification.toml
        ├── runs.csv
        ├── snapshots/
        │   └── <run-id>/
        │       ├── quarter-0000.jld2
        │       ├── quarter-0001.jld2
        │       └── ...
        └── derived/
```

Generated experiments remain ignored by Git. Code, specifications, schema notes,
and notebooks remain versioned.

## Analysis architecture

Raw snapshots are immutable source data. Analysis code loads snapshots and
creates only the rectangular data needed for a specific question.

The first analysis utilities should provide:

1. snapshot discovery from `runs.csv`;
2. loading one run-quarter at a time;
3. introspection of model components and fields;
4. conversion of selected components into period, firm, and household tables;
5. joins across consecutive quarters using persistent IDs;
6. optional caching of derived tables under `derived/`.

Do not make a fixed set of derived CSV files part of the raw schema. They can be
regenerated as research questions evolve.

### Primary view: firm behavior through time

For a selected run and firm variable, construct a matrix

```text
rows       persistent firm IDs
columns    quarters 0:T
cells      value of the selected firm variable
```

Firm rows must use `firms.ID`, not array position. Build the row index from the
union of IDs across all quarters so entry, exit, or replacement cannot shift one
firm's history onto another row. Missing firm-quarter combinations remain
missing and use a distinct neutral color.

Keep row order fixed for the entire plot. The default order is sector
(`firms.G_i`) followed by firm ID; optional ordering by an initial characteristic
or clustering may be added for a specific analysis. Never sort rows separately
in each quarter because that destroys temporal identity.

The first useful measures are:

- production `Y_i`;
- sales and demand `Q_i`, `Q_d_i`;
- employment and vacancies `N_i`, `V_i`;
- price `P_i`;
- profit and equity `Pi_i`, `E_i`;
- loans and deposits `L_i`, `D_i`;
- requested and granted new credit `DL_d_i`, `DL_i`;
- derived credit gap `max(DL_d_i - DL_i, 0)`.

Each heatmap represents one measure. Use raw or log-scaled values to compare
firms and within-firm changes or standardized values to compare behavioral
responses. The scale and transformation must be shown in the title or legend.

Start with a static heatmap containing the entire simulation. The time-flowing
version reuses the same matrix and progressively reveals quarters or displays a
moving window. Pair it with a synchronized aggregate trajectory above it and a
shared quarter marker so firm-level changes can be compared with emergent GDP,
unemployment, inflation, or credit behavior. Animation is a presentation layer,
not a different data pipeline.

The snapshot collection can support analyses such as:

- aggregate trajectories and regime changes;
- firm entry, exit, bankruptcy, production, employment, and credit dynamics;
- household income, wealth, deposits, consumption, and employment distributions;
- sector composition and concentration;
- balance-sheet and accounting relationships;
- transitions between consecutive quarters;
- baseline/intervention comparisons with common seeds;
- dimensionality reduction, clustering, transition prediction, and other ML
  methods chosen after exploratory analysis.

Quarterly snapshots cannot recover counterparties or transient values that are
created and discarded within a quarter. Event hooks should be added only if a
specific later analysis proves that boundary states are insufficient.

## Implementation phases

### Phase 1 — Serialization proof

1. Construct a real BeforeIT model.
2. Save the whole model at quarter 0 with JLD2.
3. Load it and verify its concrete type and every nested field recursively.
4. Advance one quarter, repeat the round trip, and measure file size and write
   time.

**Exit condition:** complete models from quarters 0 and 1 round-trip without an
excluded or changed field.

### Phase 2 — Quarterly writer

1. Implement one small snapshot writer and loader.
2. Wrap the existing serial run loop with saves at initialization and after each
   `collect_data!` call.
3. Use deterministic run and file names.
4. Write through temporary files so interrupted saves are not mistaken for
   completed snapshots.

**Exit condition:** a seeded `T`-quarter run creates exactly `T + 1` loadable
files with contiguous quarter metadata.

### Phase 3 — Experiment runner

1. Read scenarios, seeds, and horizon from `experiment.toml`.
2. Create one snapshot directory per run.
3. Record success, failure, runtime, and snapshot coverage in `runs.csv`.
4. Refuse accidental overwrites unless an explicit clean rerun is requested.

**Exit condition:** every declared run is complete or has a recorded failure and
partial files cannot appear as completed snapshots.

### Phase 4 — Analysis foundation

1. Replace the current derived-data reader with a snapshot discovery and loading
   layer.
2. Build the firm-by-quarter matrix from persistent firm IDs.
3. Produce the static firm heatmap and synchronized aggregate plot.
4. Add progressive reveal or moving-window animation using the same matrix.
5. Refactor the remaining EDA notebook to derive inputs from complete snapshots.
6. Document observation timing, missing values, units, and transformations.

**Exit condition:** the notebook can rebuild the firm matrix and visualization
from raw quarterly files alone, with no dependence on the old curated trace.

### Phase 5 — Research simulations and ML

1. Define a small set of hypotheses and paired scenarios.
2. Run a fixed seed panel with complete quarterly snapshots.
3. Perform exploratory, distributional, transition, and accounting analysis.
4. Choose ML methods based on the observed structure and research question.
5. Split validation data by simulation run, never by random agent-quarter rows.

**Exit condition:** reported findings can be traced back to named runs, quarters,
model components, and fields in the raw snapshots.

## Required checks

- A completed run contains exactly quarters `0:horizon`.
- Every snapshot loads as the same concrete model type that was saved.
- Recursive comparison finds no missing or changed model field after round-trip.
- Earlier snapshot files do not change when the live model advances.
- Snapshot metadata agrees with `model.agg.t` and the run manifest.
- Agent IDs remain present and unique within their model component.
- Every heatmap cell maps to the same persistent firm ID and recorded quarter as
  its source snapshot.
- Missing firms remain missing rather than inheriting another firm's array
  position.
- Saving snapshots does not alter seeded simulation results.
- Interrupted writes leave no valid-looking final file.
- Unsupported schema or software versions fail with a clear message.
- One full pilot run stays within an explicitly reported storage and runtime
  budget; no optimization is required unless that budget is unacceptable.

## Change from the previous implementation

The previous implementation is a curated explanation trace: it omits selected
runtime fields, stores reduced observations, adds within-quarter event hooks, and
places all quarters in one file per run. That is not the new raw-data contract.

The refactor replaces it with complete per-quarter model files. Event capture and
derived CSVs are optional downstream additions. The EDA notebook now reads the
new snapshots directly.

## Completion criteria

The refactor is complete when a declared simulation can be run from scratch and
produces one validated, full-model JLD2 file for initialization and every quarter,
plus a manifest that lets analysis code discover and interpret those files.

Stop there. Add event-level capture, compression, alternative formats, or ML
pipelines only when the quarterly dataset demonstrates a concrete need.
