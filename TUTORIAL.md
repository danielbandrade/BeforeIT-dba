# BeforeIT.jl — Hands-on Tutorial

An interactive study guide to the Bank of Italy agent-based macro model.
Every block is meant to be **pasted into a live Julia REPL**, in order. Each lesson
ends with exercises (answers at the bottom).

Source references are `file:line` — open them alongside this file.

---

## Lesson 0 — Setup

Open a REPL bound to this project, with threads enabled:

```bash
cd /Users/danielbandrade/Documents/programing/studies/BeforeIT.jl
julia --project=. -t auto
```

```julia
import BeforeIT as Bit
using Plots, Statistics, Random
```

First call compiles a lot; ~30-60s is normal.

Load the shipped Austrian calibration (2010 Q1):

```julia
parameters = Bit.AUSTRIA2010Q1.parameters
initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
model = Bit.Model(parameters, initial_conditions)
```

`Bit.ITALY2010Q1` also exists. Raw calibration inputs live in `data/austria`, `data/italy`.

**Check yourself:** how many agents did you just instantiate?

```julia
p = model.prop
(firms = p.I, active = p.H_act, inactive = p.H_inact, sectors = p.G,
 govs = p.J, foreign_consumers = p.L)
```

Austria 2010Q1: 624 firms, 4743 active + 4130 inactive persons, 62 products/sectors,
156 government entities, 312 foreign consumers, and `T_prime = 54` quarters of
history used to fit expectations. Agents are *scaled-down* representatives, not
one-per-real-person.

---

## Lesson 1 — What kind of model is this?

Not a system of equations solved for equilibrium. It is a **simulation of individual
agents** that each follow simple rules; the macro aggregates (GDP, inflation,
unemployment) are *outputs* of their interactions, never imposed.

Seven agent types (`src/model_init/agents.jl`):

| Agent | Julia field | Count | Role |
|---|---|---|---|
| Active workers | `model.w_act` | ~thousands | supply labour, consume |
| Inactive persons | `model.w_inact` | ~thousands | receive benefits, consume |
| Firms | `model.firms` | one per row | produce, hire, invest, borrow, set prices |
| Bank | `model.bank` | 1 | lends to firms, capital-constrained |
| Central bank | `model.cb` | 1 | sets policy rate via Taylor rule |
| Government | `model.gov` | 1 | taxes, spends, issues debt |
| Rest of the world | `model.rotw` | 1 | exports demand, imports supply |
| Aggregates | `model.agg` | — | price indices, GDP history, expectations |

Firm owners and the bank owner are **households embedded inside the firm/bank
structs** — see the `Y_h, C_d_h, D_h, K_h` fields at the bottom of `Firms`
(`src/model_init/agents.jl:140`) and `Bank` (`:159`). That is why household totals
sum over four groups everywhere in the code.

Vectorised layout: every field is a *column* over agents, not an array of structs.

```julia
typeof(model.firms.P_i)      # Vector{Float64}, one price per firm
length(model.firms)          # number of firms
model.firms.G_i[1:10]        # sector (product) each of the first 10 firms makes
```

**Naming convention** — learn it once and the whole codebase reads easily:

| Suffix / prefix | Meaning |
|---|---|
| `_i` | per firm |
| `_h` | per household |
| `_g` | per product/sector |
| `_d_` | **desired / demanded** (e.g. `N_d_i` desired employment) |
| `_e_` | **expected** (e.g. `Pi_e_i` expected profits) |
| `_bar` | average or index (e.g. `P_bar` price index, `w_bar_i` avg wage) |
| `D` prefix | delta / flow (e.g. `DL_i` new loans, `DM_i` materials bought) |

Greek names map to the paper: `pi_` inflation, `gamma_` growth, `tau_*` tax rates,
`theta` debt installment rate, `psi` propensity to consume, `zeta` capital
requirement, `kappa/beta/alpha_bar` capital/materials/labour productivity.

---

## Lesson 2 — One quarter of simulated time

Everything happens inside `Bit.step!` (`src/one_step.jl:29`). One call = **one
quarter**. Read that function top to bottom; it is the model's table of contents.

Six phases:

1. **Estimation** — bankruptcy cleanup, expectations for growth/inflation, euro-area
   dynamics, Taylor-rule policy rate, bank lending rate.
2. **Firm planning** — target quantity, prices, desired investment/materials/labour,
   expected profits, desired loans.
3. **Markets** — credit → labour → production (Leontief).
4. **Budgets** — social benefits, household consumption/investment budgets,
   government expenditure, export demand and import supply.
5. **Goods market** — one big search-and-matching over all products.
6. **Accounting** — price indices, stocks, profits, incomes, deposits, government
   debt, GDP, `t += 1`.

Ordering is not cosmetic: firms decide **before** knowing realised demand, so plans
and outcomes differ, and the gap shows up as inventories `S_i` and unemployment.

Run one step and watch the clock:

```julia
model.agg.t                  # time index before
Bit.step!(model)
Bit.collect_data!(model)     # step! does NOT record data; run! does both
model.agg.t
```

`Bit.run!(model, T)` = loop of `step!` + `collect_data!` (`src/one_simulation.jl:25`).

---

## Lesson 3 — Expectations and the policy rate

### 3.1 Expected growth and inflation

`src/agent_actions/estimations.jl:29`. An AR(1) fit on the **past log-GDP series**,
extrapolated one quarter ahead:

```
Y_e     = exp(α_Y · log(Y_{t-1}) + β_Y + ε_Y)
gamma_e = Y_e / Y_{t-1} - 1
pi_e    = exp(α_π · π_{t-1} + β_π + ε_π) - 1
```

The history before the simulation starts (`T_prime` quarters of real data) is what
these regressions are fitted on — that's why `model.agg.Y` is longer than the number
of simulated steps.

```julia
model.prop.T_prime            # length of the historical burn-in
length(model.agg.Y)           # history + simulated quarters so far
Bit.growth_inflation_expectations(model)   # (Y_e, gamma_e, pi_e)
```

Every agent uses the *same* `gamma_e`/`pi_e`. No heterogeneous beliefs in the
baseline — a natural place to extend the model.

### 3.2 Taylor rule

`src/agent_actions/central_bank.jl:50`:

```
r_bar = ρ·r_bar + (1-ρ)·(r* + π* + ξ_π·(π_EA - π*) + ξ_γ·γ_EA)
```

then clipped at zero by `pos()` (zero lower bound).

```julia
cb = model.cb
(rho = cb.rho, r_star = cb.r_star, pi_star = cb.pi_star,
 xi_pi = cb.xi_pi, xi_gamma = cb.xi_gamma, r_bar = cb.r_bar)

# feed it a 5% euro-area inflation by hand:
Bit.taylor_rule(cb.rho, cb.r_bar, cb.r_star, cb.pi_star, cb.xi_pi, cb.xi_gamma, 0.005, 0.05)
```

Note the rule reacts to **euro-area** inflation and growth (`model.rotw`), not
domestic — Austria is a small open economy inside the currency union.

The bank's lending rate is the policy rate plus a fixed markup `mu`
(`src/agent_actions/bank.jl`, `set_bank_rate!`).

---

## Lesson 4 — Firms: plan, then discover reality

### 4.1 Planning (`src/agent_actions/firms.jl:62`)

```
Q_s_i   = Q_d_i · (1 + gamma_e)              # target output = last demand, grown
P_i     = P_i · (1 + π_c_i) · (1 + pi_e)     # price = cost-push + expected inflation
I_d_i   = δ_i/κ_i · min(Q_s_i, K_i·κ_i)      # desired investment
DM_d_i  = min(Q_s_i, K_i·κ_i) / β_i          # desired materials
N_d_i   = max(1, round(min(Q_s_i, K_i·κ_i)/ᾱ_i))  # desired employment
Pi_e_i  = Pi_i · (1+pi_e) · (1+gamma_e)      # expected profits
DL_d_i  = max(0, -DD_e_i - D_i)              # desired new loans = expected cash gap
```

`π_c_i` (`firms.jl:1`) is cost-push inflation: labour + materials + capital costs
compared to the firm's own price. A firm whose input prices outran its output price
raises prices next quarter.

```julia
Bit.cost_push_inflation(model.firms, model)[1:5]
mean(model.firms.P_i)
```

### 4.2 Production is Leontief (`firms.jl:183`)

```
Y_i = min(Q_s_i, N_i·α_i, K_i·κ_i, M_i·β_i)
```

No substitution: output equals the **binding constraint** among target, labour,
capital and materials. This is where rationing propagates — a firm that fails to hire
simply produces less, cutting demand for its suppliers next quarter.

Which constraint binds right now?

```julia
f = model.firms
labour   = f.N_i .* f.alpha_bar_i
capital  = f.K_i .* f.kappa_i
material = f.M_i .* f.beta_i
binding = [argmin((f.Q_s_i[i], labour[i], capital[i], material[i])) for i in eachindex(f.Y_i)]
[count(==(k), binding) for k in 1:4]   # counts of: target, labour, capital, materials
```

(Approximation: production uses `alpha_i`, a utilisation-adjusted `alpha_bar_i`
capped at 1.5× — see `firms.jl:149`. Fine for counting who binds.)

After quarter 1 the target `Q_s_i` binds for essentially every firm — spare capacity
everywhere. By quarter 20 of the Austrian baseline, **labour** binds for ~75% of
firms and unemployment has fallen to zero: the model runs into a labour ceiling.

### 4.3 Bankruptcy

`Bit.finance_insolvent_firms!` runs at the *top* of the next step: firms with
negative equity are recapitalised out of household deposits and restart with
`zeta_b`-scaled loans (`src/agent_actions/firms.jl` + `src/model_init/init_firms.jl`).
Firms are never removed, so `length(model.firms)` is constant.

---

## Lesson 5 — Three markets, three matching rules

### Credit (`src/markets/search_and_matching_credit.jl:13`)

Firms are served in **random order** until the bank hits a constraint:

```
DL_i = max(0, min( DL_d_i,                     # what the firm wants
                   ζ_LTV·K_e_i - L_e_i,        # loan-to-value limit
                   E_k/ζ - Σ L_e - Σ DL ))     # bank capital requirement
```

Random order = whoever asks first gets credit. Rerunning with a different seed gives
a different allocation. That's the model's micro-level randomness.

```julia
sum(model.firms.DL_d_i), sum(model.firms.DL_i)   # desired vs granted credit
model.bank.E_k / model.prop.zeta                  # max lending capacity
```

At quarter 1 desired ≈ granted (no rationing). By quarter 20 of the baseline, ~15754
desired vs ~13566 granted — the LTV limit `ζ_LTV·K_e_i - L_e_i` starts biting for
firms whose expected capital is small relative to existing debt.

### Labour (`src/markets/search_and_matching_labour.jl:22`)

`V_i = N_d_i - N_i`. Negative vacancies fire (random workers), positive vacancies are
filled one at a time from a shuffled unemployment pool until one side runs out.

```julia
O = model.w_act.O_h                       # 0 = unemployed, i > 0 = employed by firm i
unemployment_rate = count(==(0), O) / length(O)
```

(The `-1 = inactive` code in the `Workers` docstring never appears in `w_act` —
inactive persons live in the separate `w_inact` object.)

Wages: a firm hitting its capacity ceiling pays up to `1.5×` its average wage
(`firms_wages`, `firms.jl:115`) — the only wage-pressure channel.

### Goods (`src/markets/search_and_matching.jl:10`)

Per product `g`, a two-stage market: firms buying capital/materials first, then
retail (households, government, exports). Buyers pick sellers with probability
weighted by price and available stock. This is the one loop that is threaded
(`parallel = true` splits over products `g`).

---

## Lesson 6 — Accounting closes the loop

Phase 6 is pure bookkeeping, but it is what makes the model *stock-flow consistent*:
every euro spent lands in someone's deposits.

```
inflation, P_bar = log(Σ P_i·Y_i / Σ Y_i / P_bar), Σ P_i·Y_i / Σ Y_i
Pi_i             = sales + interest - wages - materials - depreciation - taxes - interest paid
D_i              = D_i + (all firm cash flows)
L_i              = (1-θ)·L_i + DL_i
E_i              = D_i + materials + inventories + capital - loans
GDP              = Σ Y_i                              (aggregates.jl:1)
```

Verify a balance sheet by hand for one firm:

```julia
i = 1
f = model.firms
mats = f.M_i[i] * sum(model.prop.a_sg[:, f.G_i[i]] .* model.agg.P_bar_g)
f.D_i[i] + mats + f.P_i[i]*f.S_i[i] + model.agg.P_bar_CF*f.K_i[i] - f.L_i[i] ≈ f.E_i[i]
```

Aggregate identities (income = production, GDP = expenditure) are checked by
`Bit.get_accounting_identities(model.data)` (`src/utils/get_accounting_identities.jl:1`).

---

## Lesson 7 — Running and reading a simulation

```julia
Random.seed!(1)
model = Bit.Model(parameters, initial_conditions)
Bit.run!(model, 20)
d = model.data
```

`d` is a `Bit.Data` object (`src/utils/data.jl`) with the national-accounts series:
`real_gdp`, `nominal_gdp`, `real_household_consumption`, `real_government_consumption`,
`real_capitalformation`, `real_exports`, `real_imports`, `wages`, `euribor`,
`operating_surplus`, `real_sector_gva`, …

```julia
plot(d.real_gdp, label="real GDP", xlabel="quarter")
plot!(d.nominal_gdp, label="nominal GDP")

deflator = d.nominal_gdp ./ d.real_gdp
plot(100 .* (deflator[2:end] ./ deflator[1:end-1] .- 1), label="quarterly inflation %")
```

`main.jl` in the repo root is exactly this, with a 3×3 panel of the main series.

Important: real series are deflated by the model's *own* price indices, and index
values are relative to the initial quarter — levels are in million euro of the base
period, so compare **growth rates**, not levels, against real data.

---

## Lesson 8 — Stochasticity: never trust one run

The model has three noise sources: euro-area shocks (`set_epsilon!`), random matching
order in all three markets, and government/export/import AR(1) innovations. A single
trajectory says nothing.

```julia
T, n_sims = 20, 32
base = Bit.Model(parameters, initial_conditions)
models = Bit.ensemblerun!([deepcopy(base) for _ in 1:n_sims], T)
dv = Bit.DataVector(models)          # fields become T×n_sims matrices

g = dv.real_gdp
m, s = mean(g, dims=2), std(g, dims=2) ./ sqrt(n_sims)
plot(m, ribbon=s, fillalpha=0.2, label="mean real GDP ± s.e.")
```

`Bit.ensemblerun(model, T, n_sims)` (no `!`) deep-copies for you.

---

## Lesson 9 — Scenario analysis with shocks

A shock is **any callable taking the model**, invoked each step at
`src/one_step.jl:46` — right after the Taylor rule, before firms plan. Built-ins in
`src/shocks/shocks.jl`: `NoShock`, `InterestRateShock(rate, final_time)`,
`ProductivityShock(mult)`, `ConsumptionShock(mult, final_time)`.

```julia
shock = Bit.InterestRateShock(0.02, 8)    # pin policy rate at 2% for 8 quarters

base_models  = Bit.ensemblerun!([deepcopy(base) for _ in 1:32], 20)
shock_models = Bit.ensemblerun!([deepcopy(base) for _ in 1:32], 20; shock! = shock)

ratio = mean(Bit.DataVector(shock_models).real_gdp, dims=2) ./
        mean(Bit.DataVector(base_models).real_gdp, dims=2)
plot(ratio, label="shocked / baseline GDP", xlabel="quarter")
```

Your own shock — a struct plus a call method:

```julia
struct VATShock
    multiplier::Float64
    final_time::Int
end
function (s::VATShock)(model)
    if model.agg.t == 1
        model.prop.tau_VAT *= s.multiplier
    elseif model.agg.t == s.final_time
        model.prop.tau_VAT /= s.multiplier
    end
end

Bit.ensemblerun!([deepcopy(base) for _ in 1:8], 12; shock! = VATShock(1.10, 6));
```

Because the shock fires *before* firm planning, a parameter change is visible to
expectations in the same quarter.

See `examples/scenario_analysis_via_shock.jl` and
`examples/scenario_analysis_via_overload.jl` (the second overloads an agent-action
function instead — more invasive, more flexible).

---

## Lesson 10 — Where to go next in the repo

| Want to… | Read |
|---|---|
| See the whole quarter at a glance | `src/one_step.jl` |
| Understand a specific agent's rules | `src/agent_actions/<agent>.jl` |
| Change how a market clears | `src/markets/*.jl` |
| Add tracked variables | `collect_data!` docstring, `src/utils/data.jl:60` |
| Add a new agent type / model variant | `src/model_extensions/`, `examples/basic_inheritance.jl` |
| Forecast and compare to real data | `examples/prediction_pipeline.jl`, `examples/compare_model_vs_real.jl` |
| Calibrate another country | `src/utils/calibration.jl`, CalibrateBeforeIT.jl |
| Differentiate through the model | `examples/automatic_differentiation.jl` |

Paper: Poledna, Miess, Hommes, Rabitsch, *Economic forecasting with an agent-based
model*, European Economic Review, 2023.

---

## Exercises

1. Run 20 quarters twice with the same seed and twice with different seeds. Which
   pairs match exactly, and why?
2. Compute the unemployment rate series over a 20-quarter run. (Hint: `O_h == 0` is
   unemployed, `-1` is inactive; you must record it yourself each step.)
3. Raise `zeta` (bank capital requirement) by 50% and measure the effect on mean GDP
   over 20 quarters with 32 replications. Which channel transmits it?
4. Set `xi_pi = 0` in the central bank. What happens to inflation volatility?
5. Which constraint binds most often in `leontief_production` at quarter 1 vs quarter
   20? What does the drift tell you?

### Answers

**1.** `Random.seed!(n)` before `Bit.Model(...)` makes runs identical — matching order,
euro-area innovations and AR(1) draws all come from the global RNG. Different seeds
diverge immediately because credit and labour matching are shuffled per step.

**2.**
```julia
Random.seed!(1); m = Bit.Model(parameters, initial_conditions)
u = Float64[]
for t in 1:20
    Bit.step!(m); Bit.collect_data!(m)
    push!(u, count(==(0), m.w_act.O_h) / length(m.w_act.O_h))
end
plot(u, label="unemployment rate")
```
Starts near 6.1% and falls to 0 by quarter 20 — the baseline has no mechanism
holding unemployment up once demand grows.

**3.**
```julia
function mean_gdp(mod_params; T=20, n=32)
    p = deepcopy(parameters)
    m0 = Bit.Model(p, initial_conditions); mod_params(m0)
    ms = Bit.ensemblerun!([deepcopy(m0) for _ in 1:n], T)
    mean(Bit.DataVector(ms).real_gdp, dims=2)[end]
end
mean_gdp(m -> nothing), mean_gdp(m -> m.prop.zeta *= 1.5)
```
Channel: `E_k/ζ` is the lending ceiling in `search_and_matching_credit.jl:26`. Less
credit → firms cut `I_d_i` funding → lower capital → Leontief capital constraint
binds → less output.

**4.** With `xi_pi = 0` the policy rate stops responding to euro-area inflation; the
rate path flattens, the loan rate flattens, and inflation shocks propagate into firm
cost-push pricing with no offset. Expect higher inflation variance and mildly higher
mean GDP.

**5.** Use the `binding` snippet from Lesson 4.2 at both dates. Seed 1, Austrian
baseline: quarter 1 → `[624, 0, 0, 0]` (target binds everywhere, idle capacity);
quarter 20 → `[144, 478, 0, 2]` (labour binds for 77% of firms). The drift says the
expansion is absorbed by the fixed labour force, not by capital — output growth stops
being demand-driven and becomes supply-constrained, matching the unemployment series
from exercise 2 hitting zero.
