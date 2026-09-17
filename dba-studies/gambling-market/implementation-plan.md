# Gambling-market implementation plan

## 1. Objective

Introduce a stylized gambling mechanism in which a fixed subset of approximately
10% of active and inactive workers spends a percentage of disposable income and
the resulting money is transferred directly to a selected subset of existing
firm-owner households.

The first implementation should answer this narrow research question:

> How does a recurring transfer from workers to selected firm owners affect
> household spending, deposits, debt, and wealth distribution?

This plan is written for manual implementation. It identifies the model seams,
equations, files, tests, and stopping condition, but does not implement them.

## 2. Recommended scope

### Version 1: direct household transfer

Implement gambling as a transfer between household groups:

- Approximately 10% of the combined active- and inactive-worker population is
  selected once before model initialization.
- The same selected workers gamble throughout the simulation.
- Active participants may be employed or unemployed.
- Each selected participant transfers the same fraction of their non-negative
  disposable income; nonparticipants transfer zero.
- A fixed, explicitly configured subset of firm-owner households receives all
  gambling spending in equal shares.
- The transfer affects both expected household budgets and realized end-of-period
  income.
- The transfer itself is untaxed and is not counted as production or GDP.
- Setting `gambling_income_share` to zero reproduces the original model exactly.

This is the smallest version that matches the requested money flow and preserves
the model's balance sheet.

### What version 1 is not

Version 1 is a redistribution mechanism, not a complete gambling industry. It
does not introduce:

- new firms or a new product sector;
- bets, odds, prizes, or stochastic wins;
- operating costs, employment, capital, or intermediate inputs;
- gambling, corporate, income, or value-added taxes on the transfer;
- operator bankruptcy or market competition;
- heterogeneous gambling behavior;
- entry into or exit from gambling during the simulation;
- addiction dynamics or feedback from past losses.

Add these only if the research question requires them. In national accounts, a
real gambling service is normally represented through operator output and gross
gaming revenue. Directly crediting owners bypasses that production channel, so
version 1 must not be described as a full produced-and-taxed gambling sector.

## 3. Existing model flow

The relevant implementation is already concentrated in the household and final
accounting code:

1. Active-worker income is calculated in
   [`households_income_act`](../../src/agent_actions/households.jl#L13).
2. Inactive-worker income is calculated in
   [`households_income_inact`](../../src/agent_actions/households.jl#L35).
3. Firm-owner income is calculated in
   [`households_income_firms`](../../src/agent_actions/households.jl#L53).
4. Expected consumption and housing budgets are calculated separately for each
   household group in
   [`households.jl`](../../src/agent_actions/households.jl#L87).
5. Realized income is written after goods-market matching in
   [`one_step.jl`](../../src/one_step.jl#L121).
6. Household deposits absorb income not spent on consumption or housing in
   [`households_deposits`](../../src/agent_actions/households.jl#L179).
7. The commercial-bank balance sheet already includes worker and firm-owner
   deposits, so a conserved household-to-household transfer needs no new bank
   liability in [`bank.jl`](../../src/agent_actions/bank.jl#L148).

Firm owners are already represented as household fields inside `Firms`, with one
owner household per firm. The relevant `Y_h`, `D_h`, `C_d_h`, `I_d_h`, `C_h`, and
`I_h` vectors are defined in
[`agents.jl`](../../src/model_init/agents.jl#L88). Do not create another owner
agent type for version 1.

## 4. Economic specification

### 4.1 Inputs

Use one behavioral parameter and three initial conditions:

| Input | Kind | Meaning | Recommended baseline |
|---|---|---|---:|
| `gambling_income_share` | parameter | Fraction of each selected gambler's non-negative disposable income transferred each period | `0.0` |
| `gambling_active_worker_ids` | initial condition | Stable IDs of selected active-worker gamblers | `Int[]` |
| `gambling_inactive_worker_ids` | initial condition | Stable IDs of selected inactive-worker gamblers | `Int[]` |
| `gambling_owner_ids` | initial condition | Stable IDs of firm-owner households receiving gambling proceeds | `Int[]` |

Why they are different:

- `gambling_income_share` is a behavioral rule that remains fixed during a
  simulation.
- The two worker-ID lists describe who gambles when the simulation begins.
- `gambling_owner_ids` describes which owners occupy the recipient role when the
  simulation begins.

Use stable agent IDs, not array positions. Active and inactive workers have
separate ID spaces, which is why they need separate lists. The repository already
exposes stable IDs and agent lookup behavior in
[`modify.jl`](../../src/utils/modify.jl#L26).

The participation rate is derived from the configured ID lists:

$$
p_G=\frac{|G_A|+|G_N|}{H_W+H_{inact}}.
$$

Target \(p_G\approx0.10\) when constructing an experiment. Do not also store a
`gambling_participation_share` parameter: it would duplicate the realized share
encoded by the ID lists and create disagreement when rounding or IDs change.

Do not add separate active/inactive income shares initially. Add them only if
different gambling intensity between those populations is part of the hypothesis.

### 4.2 Period equations

Let:

- \(g \in [0,1]\) be `gambling_income_share`;
- \(Y^{A,0}_{h,t}\) be active-worker disposable income before gambling;
- \(Y^{N,0}_{h,t}\) be inactive-worker disposable income before gambling;
- \(Y^{O,0}_{i,t}\) be firm-owner income before gambling;
- \(G_A\) be the fixed set of active-worker gambler IDs;
- \(G_N\) be the fixed set of inactive-worker gambler IDs;
- \(R\) be the set of recipient firm-owner IDs;
- \(|R|\) be the number of recipients.

Worker stakes are:

$$
B^A_{h,t}=\mathbf{1}(h\in G_A)g\max(0,Y^{A,0}_{h,t})
$$

$$
B^N_{h,t}=\mathbf{1}(h\in G_N)g\max(0,Y^{N,0}_{h,t})
$$

Total gambling volume is:

$$
B_t=\sum_h B^A_{h,t}+\sum_h B^N_{h,t}.
$$

Each selected owner receives:

$$
R_{i,t}=\begin{cases}
B_t/|R|, & i \in R,\\
0, & i \notin R.
\end{cases}
$$

Post-gambling disposable incomes are:

$$
Y^A_{h,t}=Y^{A,0}_{h,t}-B^A_{h,t},
$$

$$
Y^N_{h,t}=Y^{N,0}_{h,t}-B^N_{h,t},
$$

$$
Y^O_{i,t}=Y^{O,0}_{i,t}+R_{i,t}.
$$

The transfer must conserve household income:

$$
\sum_h B^A_{h,t}+\sum_h B^N_{h,t}=\sum_i R_{i,t}.
$$

Therefore:

$$
\sum_h Y^A_{h,t}+\sum_h Y^N_{h,t}+\sum_i Y^O_{i,t}
=
\sum_h Y^{A,0}_{h,t}+\sum_h Y^{N,0}_{h,t}+\sum_i Y^{O,0}_{i,t}.
$$

The bank-owner household is not a recipient in version 1.

### 4.3 Budget behavior

Use post-gambling expected income in the existing budget equations:

$$
C^d_{h,t}=\frac{\psi Y^e_{h,t}}{1+\tau_{VAT}},
\qquad
I^d_{h,t}=\frac{\psi_H Y^e_{h,t}}{1+\tau_{CF}}.
$$

This makes gambling compete with consumption, housing investment, and saving in
the same period. Applying the transfer only after budgets would redistribute
deposits but would not reduce gamblers' desired spending, which is probably not
the intended mechanism.

All household types currently use the same `psi`, `psi_H`, and product weights.
Consequently, a conserved transfer may have little immediate effect on aggregate
desired demand. Its main first-order effect is distributional. Larger macroeconomic
effects require heterogeneous spending propensities or a produced gambling sector;
those are outside version 1.

## 5. Input validation and compatibility

Validate inputs once in the `Properties` constructor, which is the model's input
boundary:

- `0 <= gambling_income_share <= 1`;
- `gambling_active_worker_ids` contains unique integer IDs in the initial
  `1:H_W` active-worker range, where `H_W = H_act - I - 1`;
- `gambling_inactive_worker_ids` contains unique integer IDs in the initial
  `1:H_inact` range;
- `gambling_owner_ids` contains unique integer IDs;
- every configured ID exists in `firms.ID`/the initial `1:I` range;
- when `gambling_income_share > 0`, at least one worker gambler and at least one
  owner recipient are configured;
- empty gambler and owner lists are allowed when `gambling_income_share == 0`.

Use backward-compatible dictionary reads:

```julia
gambling_income_share = typeFloat(get(parameters, "gambling_income_share", 0.0))
gambling_active_worker_ids =
    Vector{typeInt}(get(initial_conditions, "gambling_active_worker_ids", Int[]))
gambling_inactive_worker_ids =
    Vector{typeInt}(get(initial_conditions, "gambling_inactive_worker_ids", Int[]))
gambling_owner_ids = Vector{typeInt}(get(initial_conditions, "gambling_owner_ids", Int[]))
```

This keeps the bundled Austria, Italy, steady-state, and deterministic JLD2 files
usable without rewriting them. Their missing key means the feature is disabled.

Do not silently choose gamblers or recipient owners inside the model. Random
selection there would consume the simulation RNG and could change existing
deterministic results. Select all IDs once in the experiment setup with a separate
seed and pass them as initial conditions.

Example experiment setup:

```julia
using Random
import BeforeIT as Bit

parameters = copy(Bit.AUSTRIA2010Q1.parameters)
initial_conditions = copy(Bit.AUSTRIA2010Q1.initial_conditions)

parameters["gambling_income_share"] = 0.02

rng = MersenneTwister(1234)
number_of_firms = sum(parameters["I_s"])
number_of_active_workers = parameters["H_act"] - number_of_firms - 1
number_of_inactive_workers = parameters["H_inact"]

eligible_workers = vcat(
    [(group = :active, id = i) for i in 1:number_of_active_workers],
    [(group = :inactive, id = i) for i in 1:number_of_inactive_workers],
)
number_of_gamblers = max(1, round(Int, 0.10 * length(eligible_workers)))
selected_workers =
    eligible_workers[randperm(rng, length(eligible_workers))[1:number_of_gamblers]]

initial_conditions["gambling_active_worker_ids"] =
    sort([worker.id for worker in selected_workers if worker.group == :active])
initial_conditions["gambling_inactive_worker_ids"] =
    sort([worker.id for worker in selected_workers if worker.group == :inactive])

number_of_owners = max(1, round(Int, 0.10 * sum(parameters["I_s"])))
initial_conditions["gambling_owner_ids"] =
    sort(randperm(rng, sum(parameters["I_s"]))[1:number_of_owners])

model = Bit.Model(parameters, initial_conditions)
```

Always copy the standard dictionaries before changing them; the package constants
can otherwise be mutated for the rest of the Julia session.

## 6. Recommended code design

### 6.1 Keep the transfer calculation pure

Add one pure function in
[`src/agent_actions/households.jl`](../../src/agent_actions/households.jl):

```julia
gambling_transfers(model, income_act, income_inact)
    -> stakes_act, stakes_inact, receipts_firms
```

Responsibilities:

1. Multiply non-negative income by `gambling_income_share` only at the configured
   active- and inactive-worker IDs.
2. Sum the stakes.
3. Allocate the total equally to the configured stable firm-owner IDs.
4. Return vectors aligned with `w_act`, `w_inact`, and `firms`.
5. Perform no mutation and draw no random numbers.

The function should return correctly sized zero vectors immediately when
`gambling_income_share == 0`. Nonselected workers must also have zero entries.
Use existing arrays and Base/stdlib operations; no new dependency is necessary.

### 6.2 Apply expected transfers to budgets

Modify only the three affected budget functions:

- `households_budget_act` uses expected active income minus expected active
  stakes;
- `households_budget_inact` uses expected inactive income minus expected inactive
  stakes;
- `households_budget_firms` uses expected owner income plus expected receipts;
- `households_budget_bank` remains unchanged.

Use the same pure transfer function for expected and realized calculations. Do
not create a second set of gambling equations for the budget phase.

### 6.3 Apply realized transfers before deposits

Add one mutating function:

```julia
set_gambling_transfers!(model)
```

It should:

1. Read the already-calculated realized `Y_h` arrays.
2. Call `gambling_transfers`.
3. Subtract stakes from `w_act.Y_h` and `w_inact.Y_h`.
4. Add receipts to `firms.Y_h`.
5. Store total realized gambling volume for observation.

Call it in [`one_step.jl`](../../src/one_step.jl#L121) after all four base income
setters and before all four deposit setters:

```text
set base realized household incomes
    -> apply gambling transfer
    -> update all household deposits
    -> continue final accounting
```

Do not put gambling logic inside the generic `households_deposits` function. That
function correctly handles every household group with one accounting equation;
type-specific gambling branches there would duplicate behavior and risk debiting
owners or the bank owner incorrectly.

### 6.4 Minimal observability

Track one aggregate series, `gambling_volume`, equal to total realized stakes.

Recommended locations:

- current-period scalar in `Aggregates` in
  [`agents.jl`](../../src/model_init/agents.jl#L298);
- initialization to zero in
  [`init_aggregates.jl`](../../src/model_init/init_aggregates.jl#L13);
- time series in `Data` in
  [`data.jl`](../../src/utils/data.jl#L4);
- initialization value `0.0` in `update_data_init!`;
- realized value from `model.agg.gambling_volume` in `update_data_step!`.

`allocate_new_data!` currently allocates the first 26 scalar-vector fields by
position. If `gambling_volume` is appended after the existing sector vectors,
allocate it explicitly rather than changing unrelated field ordering. Test that
all data vectors retain equal length.

Do not add per-household gambling fields to `Workers` or `Firms` in version 1.
The pure function exposes those vectors during testing, and one aggregate series
is enough to analyze the mechanism initially.

## 7. File-by-file implementation sequence

### Phase 1: parameter and initial-condition wiring

1. Edit [`src/model_init/init_properties.jl`](../../src/model_init/init_properties.jl):
   - add `gambling_income_share::Bit.typeFloat`;
   - add `gambling_active_worker_ids::Vector{Bit.typeInt}`;
   - add `gambling_inactive_worker_ids::Vector{Bit.typeInt}`;
   - add `gambling_owner_ids::Vector{Bit.typeInt}`;
   - load all four inputs with backward-compatible defaults;
   - validate the income-share range and all three ID lists;
   - pass them through the `Properties` constructor in field order.
2. Edit [`src/utils/calibration.jl`](../../src/utils/calibration.jl#L642):
   - add `"gambling_income_share" => 0.0` to newly generated parameter
     dictionaries;
   - add empty active-worker, inactive-worker, and owner ID lists to newly
     generated initial conditions.
3. Make the same zero-default additions in
   [`src/utils/_calibration_steady_state.jl`](../../src/utils/_calibration_steady_state.jl#L300).
4. Do not edit bundled `.jld2` files; constructor defaults preserve them.

Checkpoint: all existing models must initialize with gambling disabled.

### Phase 2: transfer mechanism

1. Add the pure `gambling_transfers` calculation to
   [`src/agent_actions/households.jl`](../../src/agent_actions/households.jl).
2. Add focused tests before integrating it into the model loop.
3. Modify active, inactive, and firm-owner budget calculations to use
   post-transfer expected income.
4. Add `set_gambling_transfers!` for realized incomes.
5. Insert the realized transfer between income and deposit updates in
   [`src/one_step.jl`](../../src/one_step.jl#L121).

Checkpoint: positive gambling reduces worker income by exactly the amount added
to recipient-owner income.

### Phase 3: observability

1. Add and initialize `Aggregates.gambling_volume`.
2. Add `Data.gambling_volume`.
3. Extend allocation and collection for initial and simulated periods.
4. Confirm `length(model.data.gambling_volume) == length(model.data.collection_time)`.

Checkpoint: recorded volume equals the sum of realized active and inactive
stakes for every collected period.

### Phase 4: integration and regression checks

1. Add the new household-action tests to
   [`test/runtests.jl`](../../test/runtests.jl#L17).
2. Run the focused gambling tests.
3. Run [`test/accounting_identities.jl`](../../test/accounting_identities.jl).
4. Run deterministic tests with `gambling_income_share == 0`.
5. Run the complete package test suite and formatter.

Stop when the acceptance criteria below pass. Do not add a new market engine,
agent hierarchy, dependency, or tax system during version 1.

## 8. Test plan

Create `test/agent_actions/households.jl` and include it from `test/runtests.jl`.

### 8.1 Pure calculation tests

Use small explicit income vectors and two recipient owners.

Test:

- zero share returns all-zero stakes and receipts;
- a selected worker stakes exactly `gambling_income_share` of non-negative income;
- a nonselected worker stakes zero;
- selecting approximately 10% of the combined eligible population produces the
  expected participant count after rounding;
- negative income produces a zero stake;
- only configured owners receive money;
- selected owners receive equal amounts;
- total stakes equal total owner receipts within floating-point tolerance;
- input income vectors are not mutated;
- recipient lookup uses stable IDs.

### 8.2 Validation tests

Test that model initialization rejects:

- `gambling_income_share < 0`;
- `gambling_income_share > 1`;
- positive income share with no selected worker IDs;
- positive income share with no recipient-owner IDs;
- duplicate IDs in any configured list;
- active-worker, inactive-worker, or owner IDs outside their initial ranges.

Also test that old parameter dictionaries with no gambling keys still initialize
and produce `gambling_income_share == 0` with empty ID lists.

### 8.3 Budget tests

With a deterministic positive share, verify:

- active desired consumption and investment use income after expected stakes;
- inactive desired consumption and investment use income after expected stakes;
- nonselected active and inactive workers retain their original budgets;
- recipient-owner budgets include expected receipts;
- nonrecipient-owner budgets do not;
- the bank-owner budget is unchanged.

### 8.4 Realized-transfer tests

After base household incomes are set:

1. Save copies of all affected income vectors.
2. Apply `set_gambling_transfers!` once.
3. Verify exact worker debits and owner credits.
4. Verify total income conservation.
5. Verify `model.agg.gambling_volume`.

Do not call the mutating transfer twice in one period; it is designed for one
specific location in `step!`.

### 8.5 Accounting and regression tests

The existing accounting test must continue to satisfy:

$$
\sum_i D_i + \sum_h D_h + E_k - \sum_i L_i - D_k = 0.
$$

Required regression checks:

- `gambling_income_share == 0` preserves existing deterministic outputs;
- positive gambling preserves the commercial-bank balance sheet identity;
- total worker deposit losses attributable to gambling equal total selected-owner
  deposit gains before interest differences;
- sequential and parallel goods-market modes both complete successfully;
- collected data vectors have consistent lengths.

Suggested commands:

```bash
julia --project=test -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

If the repository's standard test command differs in the local environment, use
the command already documented by the project rather than adding a new runner.

## 9. Acceptance criteria

Version 1 is complete when all of the following are true:

- The feature is disabled by default and old calibration files still load.
- Approximately 10% of the combined worker population can be selected once using
  stable active- and inactive-worker IDs.
- Only those selected workers transfer the configured percentage of their
  non-negative disposable income every period.
- Nonselected workers never pay a gambling transfer.
- Only explicitly selected firm-owner IDs receive the transfer.
- Expected household budgets and realized incomes use the same transfer rule.
- Total payer losses equal total recipient gains each period.
- `gambling_volume` is recorded for every collected simulated period.
- Existing GDP and balance-sheet accounting identities pass.
- Existing deterministic results are unchanged when the share is zero.
- No new dependency, agent type, product group, or search-and-matching market was
  introduced.

## 10. First experiment after implementation

Run paired simulations using the same simulation seed and recipient selection:

- baseline: `gambling_income_share = 0.0`;
- current benchmark: `gambling_income_share = 0.02`;
- higher: `gambling_income_share = 0.05`;
- high: `gambling_income_share = 0.10`;
- stress: `gambling_income_share = 0.20`.

Hold one seeded gambler set at approximately 10% of all eligible workers and the
recipient set at 10% of firm owners. Repeat with several independently chosen,
seeded gambler and recipient sets so results are not an artifact of worker status,
owner identity, or industry ordering.

Compare:

- active-worker deposits and negative-deposit incidence;
- inactive-worker deposits and negative-deposit incidence;
- gambler versus nongambler worker deposits and negative-deposit incidence;
- recipient versus nonrecipient owner deposits;
- household consumption and housing investment;
- bank profits and lending rate;
- firm sales, GDP, and government debt;
- gambling volume as a share of total household disposable income.

Report distributions or quantiles, not only population means. A direct transfer
can leave aggregate income unchanged while substantially changing who holds
deposits or debt.

## 11. Known modeling consequences

1. **The transfer is zero-sum before interest.** Aggregate household income is
   conserved by construction.
2. **Debt can still rise.** Workers may have consumption and housing commitments,
   and reduced disposable income can push deposits below zero.
3. **Interest creates later non-zero-sum distributional effects.** Negative worker
   deposits pay the loan rate while positive owner deposits receive the policy
   rate.
4. **Immediate aggregate demand may barely change.** All household groups share
   the same spending propensities and product baskets in the baseline model.
5. **GDP does not include gambling output in version 1.** Any GDP effect is
   indirect through changed household behavior and later financial conditions.
6. **Recipient identity matters.** Firm-owner households are paired with firms,
   but direct owner receipts do not improve the operating firm's cash or profit.

These are properties of the chosen mechanism, not implementation bugs.

## 12. Upgrade path to a full gambling sector

Only take this path if the research question concerns gambling production,
employment, taxes, or industry dynamics rather than direct redistribution.

A full sector would require a separate design for:

- identifying or creating gambling firms;
- household demand for gambling services;
- gross stakes, prize payouts, and gross gaming revenue;
- operator sales, profit, deposits, employment, and bankruptcy;
- gambling-specific and existing corporate/income taxes;
- inclusion in nominal and real consumption, sector GVA, GDP, and price indices;
- calibration from observed gambling expenditure and operator accounts.

At that point, money should flow first to gambling firms and reach owners through
the existing profit, corporate-tax, dividend, and owner-income pipeline. Do not
credit owners directly in that version, because doing both would double-count the
same gambling revenue.

## 13. Post-implementation analysis and parameter-grid experiment

### 13.1 Status and execution gate

Version 1, the 20-run paired benchmark, period-level tracing, and the comparative
income Gini are now implemented. The next phase has two objectives:

1. trace how the redistribution of income changes demand, market transactions,
   firm outcomes, imports, and GDP in the current 2% income-share/10%
   participation benchmark;
2. run a factorial experiment with increasing gambling-income shares and worker
   participation shares.

This section supersedes the narrower experiment proposed in Section 10. The
choices in Section 13.10 were approved and the experiment was completed on
2026-09-16.

Execution status:

- origin-of-purchase observability added and reconciled;
- 2%/10% benchmark regenerated with 20 paired runs;
- complete 17-scenario design validated in a two-run pilot;
- full grid completed with 340 simulations and 5,780 period rows;
- benchmark cell reproduced within numerical tolerance;
- Parts 4 and 5 executed without notebook errors.

### 13.2 Research questions

The benchmark analysis must answer distinct questions in sequence:

1. Did the transfer reduce participant income and increase recipient-owner income
   by the same amount?
2. Did the redistribution change desired spending, realised spending, housing
   investment, or deposits by household group?
3. Did it change market transactions, including firm sales, revenue, profit,
   inventories, and imports?
4. Did current sales changes precede changes in production, employment, and
   investment in the following period?
5. Which expenditure components reconciled the resulting GDP difference?
6. How do these effects vary with the intensive margin (income share gambled),
   the extensive margin (share of workers participating), and their interaction?

The Gini is a distributional outcome, not a sufficient explanation of the market
channel. A small aggregate Gini change can coexist with economically relevant
redistribution between the selected groups.

### 13.3 Benchmark mechanism analysis

Continue to define every treatment effect as a paired difference using the same
`run`, `simulation_seed`, and `period`:

```text
delta_X = X_gambling - X_baseline
```

Do not treat the 16 periods within a run as 16 independent simulations. For
horizon summaries, first calculate the final value or 16-period mean within each
run, then calculate means, medians, standard deviations, confidence intervals,
and sign counts across the 20 runs.

Add the following analysis to `exploracao-beforeIT-aux1_pt4.ipynb`.

#### A. Redistribution and household responses

Compare the following groups:

- participating workers;
- other workers;
- recipient firm owners;
- other firm owners.

For participants and recipients, report both group totals and values per agent.
Use the existing participant and recipient counts as denominators. Analyse:

- income before and after the transfer;
- desired and realised consumption;
- desired and realised housing investment;
- deposits;
- the household-income Gini.

The first check is the direct accounting path:

```text
participant income loss
    -> recipient-owner income gain
    -> group spending and deposit changes
```

#### B. Aggregate market response

For every period and run, compare:

- desired and realised household consumption;
- desired and realised household housing investment;
- firm sales and nominal revenue;
- firm profit;
- finished-goods and material inventories;
- firm deposits and loans;
- real imports and exports.

Nominal budgets, real quantities, and real GDP components must remain separate.
Do not subtract desired nominal expenditure directly from realised real
quantities. When a nominal and real aggregate are both available, calculate and
label any implied deflator explicitly.

#### C. Contemporaneous and lagged firm response

Analyse the contemporaneous sequence:

```text
delta realised consumption(t)
    -> delta firm sales(t)
    -> delta firm profit(t)
```

Then analyse the one-period-ahead sequence:

```text
delta firm sales(t)
    -> delta production(t+1)
    -> delta employment(t+1)
    -> delta investment(t+1)
```

Plot paired mean trajectories with 95% confidence bands. Correlations and simple
lagged regressions are descriptive channel evidence; they are not separate
causal identification. If regressions use all run-period observations, cluster
uncertainty by `run`. The primary inference remains the distribution of
run-level paired summaries.

#### D. GDP reconciliation

Retain the exact decomposition:

```text
delta GDP = delta C + delta G + delta I + delta X - delta M
```

Connect the household and firm results to this identity, but do not compare
variables expressed in different units. Report the reconciliation residual and
keep it within the existing numerical tolerance.

#### E. Minimum benchmark outputs

The notebook should contain:

1. group-level income and spending trajectories, with per-agent values for the
   treated groups;
2. a paired market-response table for final and 16-period-average effects;
3. plots for sales/profit in period `t` and production/employment/investment in
   period `t+1`;
4. the GDP-component decomposition;
5. a short evidence table that labels each proposed link as supported,
   unsupported, or not observable with the current trace.

### 13.4 Additional observability required before the grid

The current trace is sufficient for aggregate market outcomes but cannot explain
why imports change or which household group purchases from domestic versus
foreign suppliers. Add the minimum missing aggregates before running the grid so
the expensive experiment does not need to be repeated.

Instrument the retail matching code to record, by period and household group:

- realised purchases from domestic firms;
- realised purchases from import suppliers;
- unfilled consumption demand after matching;
- nominal expenditure and purchased quantity by supplier origin;
- the associated domestic and imported average transaction prices when the
  denominator is non-zero.

Use the same household groups as Section 13.3.A, plus the bank-owner household so
totals reconcile. Store only group-by-origin aggregates, not agent-level or
transaction-level rows. This keeps the CSV small and is sufficient to test the
import channel.

Implementation locations:

- accumulate origin-specific quantities and expenditure inside
  `src/markets/search_and_matching.jl`, where the selected supplier is already
  known;
- expose the aggregates on the model or return them through the existing market
  update path;
- export them from `period_trace` in `run-paired-experiment.jl`;
- add reconciliation assertions showing that domestic plus imported household
  purchases equal total recorded household purchases within tolerance.

Run matching sequentially (`parallel = false`) as in the current experiment
until the new counters have been verified. Do not add a transaction log or a new
dependency.

### 13.5 Factorial grid design

Use one baseline plus a 4-by-4 treatment grid:

| Dimension | Proposed values |
|---|---|
| Gambling income share | `0.02`, `0.05`, `0.10`, `0.20` |
| Worker participation share | `0.10`, `0.20`, `0.40`, `0.60` |
| Recipient-owner share | fixed at `0.10` |
| Runs per cell | `20` |
| Simulated periods | `16`, plus period zero |

The baseline has `gambling_income_share = 0.0` and is run once per simulation
seed only as the control required for paired differences. There are no treatment
cells below the current 2% income share and 10% worker participation benchmark.
Do not repeat an identical baseline for every grid cell. The full design is
therefore:

```text
1 baseline + 16 treatment cells = 17 scenarios per run
20 runs x 17 scenarios = 340 simulations
340 simulations x 17 recorded periods = 5,780 trace rows
```

The current benchmark `(income share = 0.02, participation = 0.10)` is included
as one grid cell and must reproduce the current paired experiment within
numerical tolerance.

#### Separate participants from recipients

The current `PARTICIPATION_SHARE` controls both the number of gambling workers
and the number of recipient owners. That coupling would confound two mechanisms:

- how broadly gambling losses are distributed among workers;
- how concentrated the receipts are among owners.

Before the grid, replace it at the experiment layer with:

```text
GAMBLER_PARTICIPATION_SHARES
RECIPIENT_OWNER_SHARE = 0.10
```

Keep the recipient-owner share fixed in the main grid. Vary recipient
concentration only in a later robustness experiment if the main results make it
necessary.

#### Nested participant samples

For each `run`, generate one independently seeded random permutation of eligible
workers. Construct each participation treatment from prefixes of that same
permutation. The 10% participant group is therefore contained in the 20% group,
which is contained in the 40% and 60% groups.

Use one fixed 10% recipient-owner sample per run for every treatment cell. Reuse
the same participant set across all income-share values at a given participation
level. Selection randomness must continue to use `SELECTION_SEED`; model
randomness must continue to use `SIMULATION_SEED`.

This design makes adjacent grid cells differ only in the intended treatment
margin.

### 13.6 Script and output structure

Preserve `run-paired-experiment.jl` and its current CSVs as the benchmark. Add a
separate `run-gambling-grid.jl` for the factorial experiment.

To reuse the existing `gini_coefficient`, `period_trace`, and `run_scenario`
functions without executing the benchmark on include, guard its entry point:

```julia
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
```

The grid script may then include the benchmark script and call the existing
functions. Pass treatment values explicitly where the current functions rely on
experiment constants. Do not duplicate the complete experiment implementation.

Write new files and never overwrite the benchmark outputs:

- `data/gambling-grid-results.csv`: one row per run and scenario;
- `data/gambling-grid-period-trace.csv`: one row per run, scenario, and period;
- `data/gambling-grid-cell-summary.csv`: derived cell-level statistics;
- `exploracao-beforeIT-aux2_pt4.ipynb`: grid and dose-response analysis.

Every grid row must identify:

- `run` and `simulation_seed`;
- a stable `scenario_id`;
- `gambling_income_share`;
- target and realised worker participation shares;
- target and realised recipient-owner shares;
- participant and recipient counts.

### 13.7 Grid analysis

Join every treatment cell to the single baseline using `run`,
`simulation_seed`, and `period`. For each primary outcome, calculate the paired
final effect and paired 16-period mean within each run.

Primary outcomes:

- real GDP and its expenditure components;
- household-income Gini;
- group income, consumption, housing investment, and deposits;
- domestic and imported household purchases;
- firm sales, profit, output, employment, and investment;
- real imports;
- gambling volume as a share of total household income.

Minimum visualisations:

1. dose-response lines over the gambling-income share, one line per worker
   participation share;
2. heatmaps for average `delta GDP`, average `delta Gini`, and average
   `-delta imports`;
3. interaction plots for sales, output, employment, and investment;
4. selected time paths for the baseline, current benchmark, and highest
   treatment cell;
5. confidence intervals across runs for every grid cell.

Also report effects against realised gambling intensity, defined as cumulative
gambling volume divided by cumulative pre-transfer household income. This avoids
treating nominal parameter values as identical exposure when selected workers
have different incomes.

The grid is exploratory. Report cell estimates and uncertainty without selecting
only favourable cells. A simple response model with income share, participation
share, and their interaction may be added as a compact summary, but it must not
replace the non-parametric cell results.

### 13.8 Execution sequence after plan approval

After the user validates this plan:

1. add and test the origin-of-purchase observability from Section 13.4;
2. rerun the current 2%/10% benchmark and update the mechanism analysis in Part
   4;
3. verify that all existing accounting, transfer, Gini, and period-zero checks
   pass;
4. implement the separate grid script and outputs;
5. run a two-run pilot over the complete 17-scenario design;
6. verify row counts, nested selections, baseline reuse, output schemas, and all
   reconciliation assertions;
7. run the full 20-run grid only after the pilot passes;
8. create and execute the Part 5 notebook;
9. report the results and limitations without changing the economic mechanism.

The pilot is a validation step, not an additional user approval gate once this
plan has been approved. Stop before the full run if any invariant fails.

### 13.9 Acceptance criteria

This phase is complete only when:

- the benchmark notebook traces redistribution, household demand, market
  transactions, lagged firm responses, and GDP reconciliation;
- domestic and imported household purchases reconcile with total purchases;
- the grid contains one baseline and all 16 treatment cells for every run;
- higher participation sets are nested supersets within each run;
- recipient-owner identities and their 10% share are fixed across cells within a
  run;
- the 2%/10% cell reproduces the existing benchmark;
- period-zero paired differences are zero;
- transfer residuals and GDP residuals remain within tolerance;
- every recorded Gini lies between zero and one;
- all output files use distinct grid names and the benchmark files are preserved;
- the Part 5 notebook executes without errors and reports uncertainty across
  runs.

### 13.10 Decisions to validate before execution

User validation is required for these proposed choices:

1. income-share grid: `2%`, `5%`, `10%`, and `20%`;
2. worker-participation grid: `10%`, `20%`, `40%`, and `60%`;
3. recipient-owner share fixed at `10%` rather than varying with worker
   participation;
4. `20` runs and `16` simulated periods per cell;
5. adding aggregate origin-of-purchase instrumentation before the grid;
6. keeping the benchmark analysis in Part 4 and creating Part 5 for the grid.

No new grid simulation should be started until these six choices are approved or
revised.
