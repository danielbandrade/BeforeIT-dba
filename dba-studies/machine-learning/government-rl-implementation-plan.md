# Implementation plan: government policy agent

Implement the [research plan](government-rl-research-plan.md) as a study-local
extension of BeforeIT, starting with the Austria 2010Q1 base model. Keep the
existing simulation loop and package API.

## Code to build

```text
government-rl/
├── experiment.toml       # bounds, reward weights, scenarios, and seeds
├── government_policy.jl  # model extension, episode runner, measurements, policies
├── run_experiment.jl     # run and save experiments
├── train.jl              # add after simple policies have been evaluated
└── test/runtests.jl      # one integration check
```

### Policy model

Use multiple dispatch for the spending action, following the existing
[`ModelGR` extension](../../src/model_extensions/init_growth_rate_model.jl):

```julia
Bit.@object mutable struct PolicyModel(Bit.Model) <: Bit.AbstractModel
    spending_multiplier::Bit.typeFloat
end

function Bit.gov_expenditure(model::PolicyModel)
    C_G, C_d_j = invoke(Bit.gov_expenditure, Tuple{Any}, model)
    m = model.spending_multiplier
    return m * C_G, m .* C_d_j
end
```

Build a regular `Bit.Model` once, then construct
`PolicyModel(Bit.fields(base)..., one(Bit.typeFloat))`. This reuses
initialization and the existing
`Bit.step!` sequence. The method scales planned government consumption and
local demand together; realized spending still depends on the goods market.
The pilot uses the base spending rule. `ModelGR` needs a separate spending
method if added later.

### One episode

`run_episode(policy, scenario, seed, spec)` runs 12 quarters. Each quarter:

1. Give the policy an observation from the preceding quarter. At quarter 0,
   mark unavailable measures as missing rather than using initialized zeros.
2. Read `(tax_rate, benefit_rate, log_spending_multiplier)` from the policy.
   Check bounds, then set `model.prop.tau_INC`,
   `model.prop.theta_UB`, and
   `model.spending_multiplier = exp(log_spending_multiplier)`.
3. Call `Bit.step!(model; parallel=false)` and `Bit.collect_data!(model)`.
   Calculate and save the observation, reward components, fiscal outcomes,
   and action for that quarter.

Use a separate `MersenneTwister` for policy exploration so it does not
consume simulator random draws. Run episodes serially, with fresh model state
and a recorded simulator seed for each run.

The reward is the [research plan's welfare function](government-rl-research-plan.md#welfare-and-constraints).
In particular, unemployment contributes
`-lambda_u * count(==(0), model.w_act.O_h) / length(model.w_act.O_h)`
every quarter, with `lambda_u > 0`. Include all represented households in
consumption welfare, use realized government consumption for its public-service
proxy, and measure debt against nominal GDP. Fix weights, reference values,
and policy bounds in `experiment.toml` before tuning. Apply the same
predeclared penalty to fiscal violations when tuning every policy; the final
feasibility decision uses the research plan's guardrails.

Save the specification, run manifest, and compact quarterly results in an
immutable `government-rl/experiments/<id>/` directory, ignored by Git. Record failed runs
and fiscal guardrail violations alongside successful runs.

## Build order

1. **Environment:** implement `PolicyModel`, `run_episode`, measurements,
   and the fixed status-quo policy. One integration check compares a seeded
   no-op episode's shared model fields with ordinary `Bit.run!`; this guards
   the dispatch boundary.
2. **Simple policies:** run paired sensitivity experiments, search a small
   grid of fixed tax, benefit, and spending settings, and implement one
   feedback rule. Use the research plan's gates to decide whether RL is useful.
3. **RL:** add a small discrete action set (decrease, hold, increase for each
   lever) and a linear softmax policy trained by episodic policy gradient.
   Keep invalid actions out of the available set. Add a larger learner only
   if this one has a demonstrated limitation.
4. **Evaluation:** freeze the policies and compare status quo, fixed,
   feedback, and RL on held-out scenarios with matched simulator seeds.
   Report welfare components, unemployment, distributional outcomes, debt,
   violations, and uncertainty under the predeclared robustness cases.

The built-in `ProductivityShock` and `ConsumptionShock` methods currently
accept concrete `Bit.Model`, while `PolicyModel` is an `AbstractModel`
subtype. Extend those shocks only if a robustness scenario needs them.

**First coding task:** implement the policy model and episode loop, then run
the no-op integration check.
