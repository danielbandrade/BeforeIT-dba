# Research notes — BeforeIT basics

## Scope

- Audience: professor and graduate classmates new to BeforeIT.
- Room: live academic presentation.
- Assumed duration: 15 minutes.
- Audience outcome: explain why the paper matters, identify the model's agents,
  and narrate one simulated quarter from expectations to macro aggregates.

## Evidence-backed claims

### Paper contribution

- Poledna, Miess, Hommes, and Rabitsch develop a small-open-economy ABM whose
  out-of-sample aggregate forecasts are competitive with benchmark VAR and DSGE
  models.
- The model supports aggregate and sector-level forecasts.
- The paper demonstrates the model with medium-run effects of Austrian COVID-19
  lockdown measures.
- Data sources include national and sector accounts, input-output tables,
  government statistics, census data, and business-demography data.
- The economy follows the ESA 2010 activity classification.

Sources:

- Poledna et al., *Economic forecasting with an agent-based model*, European
  Economic Review 151 (2023), article 104306:
  https://doi.org/10.1016/j.euroecorev.2022.104306
- Open-access record and abstract:
  https://pure.iiasa.ac.at/18339

### What a macro ABM is

- A macro ABM simulates heterogeneous agents and their interactions; aggregate
  outcomes emerge from micro-level behavior.
- Compared with representative-agent equilibrium models, ABMs naturally admit
  heterogeneity, nonlinear interactions, and disequilibrium dynamics, but need
  more computation and calibration.

Source:

- Glielmo et al., *BeforeIT.jl: High-Performance Agent-Based Macroeconomics Made
  Easy*, sections 1–2: https://arxiv.org/abs/2502.13267

### Agent architecture

- Economic roles: households, non-financial firms, financial institutions,
  central bank, government, and rest of the world.
- Current BeforeIT objects separate active and inactive households, producing
  seven agent objects: `w_act`, `w_inact`, `firms`, `bank`, `cb`, `gov`, and
  `rotw`; `prop` and `agg` store parameters and aggregates.
- Austria 2010Q1 scaled calibration: 624 firms, 4,743 active persons, 4,130
  inactive persons, 62 products/sectors, 156 government entities, 312 foreign
  consumers, and 54 historical quarters for expectations.

Sources:

- `TUTORIAL.md`, lessons 0–1.
- `src/model_init/agents.jl` and `src/model_init/init.jl`.
- Glielmo et al. (2025), section 2: https://arxiv.org/abs/2502.13267

### One simulated quarter

- One `step!` call represents one quarter.
- Operational phases: expectations and rates; firm planning; credit and labour
  matching plus production; household/public/external budgets; goods matching;
  final accounting.
- Ordering matters: firms plan before realized demand, so inventories,
  unemployment, and rationing can emerge.
- `run!` repeats `step!` and then records data for each quarter.

Sources:

- `src/one_step.jl`.
- `src/one_simulation.jl`.
- `TUTORIAL.md`, lesson 2.

### Firms and markets

- Firms plan output from prior demand and expected growth, set prices from
  expected inflation and cost pressure, and derive desired labour, materials,
  investment, and credit.
- Production is Leontief: output is limited by the minimum of target demand,
  labour capacity, capital capacity, and intermediate-input capacity.
- Credit, labour, and goods are decentralized search-and-matching markets.
- Random matching order introduces micro-level stochasticity and possible
  rationing.

Sources:

- `src/agent_actions/firms.jl`.
- `src/markets/search_and_matching_credit.jl`.
- `src/markets/search_and_matching_labour.jl`.
- `src/markets/search_and_matching.jl`.
- `TUTORIAL.md`, lessons 4–5.

### Forecasts and experiments

- The model records GDP, inflation, consumption, capital formation, exports,
  imports, wages, and sectoral quantities.
- Multiple stochastic simulations are needed; one trajectory is not a forecast
  distribution.
- Shocks can modify model attributes before firm planning, enabling monetary,
  fiscal, productivity, and consumption counterfactuals.

Sources:

- `src/utils/data.jl`.
- `src/one_simulation.jl`.
- `src/shocks/shocks.jl`.
- `TUTORIAL.md`, lessons 7–9.

### BeforeIT.jl implementation

- BeforeIT is open-source Julia software based on the 2023 model, designed for
  reproducibility, extensibility, and experimentation.
- The 2025 software paper reports the small calibrated model at approximately
  17× the Matlab speed and 4× the Matlab-generated C speed in its benchmark;
  the reported large-model comparisons are approximately 35× and 10×.
- Current essential API: construct `Bit.Model(parameters, initial_conditions)`
  and call `Bit.run!(model, T)`.

Sources:

- Glielmo et al. (2025), sections 2–4: https://arxiv.org/abs/2502.13267
- Repository `README.md` and current `src/model_init/init.jl`.

## Visual policy

- Use diagrams and typographic figures drawn in HTML/SVG.
- No decorative stock photography.
- Put short source references on evidence slides and a full bibliography at the
  end.
