# BeforeIT parameter inventory

This document explains every entry in `Bit.AUSTRIA2010Q1.parameters` and how the
inventory supports surrogate-model sensitivity screening. The generated values
and source locations are in [`parameter-inventory.csv`](parameter-inventory.csv).

The inventory is complete relative to the Austrian parameter dictionary. It
does not include initial conditions, evolving model state, random seeds, or
surrogate-model hyperparameters.

## Classification summary

| Classification | Count | Interpretation |
|---|---:|---|
| `structural_dimension` | 10 | Model size, topology, or calibration horizon; fixed during ordinary sensitivity analysis |
| `independent_continuous_candidate` | 38 | Scalar candidate that still needs economically valid bounds |
| `jointly_constrained_group_candidate` | 15 | Vector or matrix that must be perturbed as a structured block |
| **Total** | **63** | 53 non-structural screening candidates |

`screening_eligible` means only that a parameter is not classified as
structural. It does not guarantee valid bounds or a safe sampling method.

## Structural dimensions

| Parameter | Austrian baseline | Meaning |
|---|---:|---|
| `G` | 62 | Number of goods or product categories |
| `S` | 62 | Number of producing sectors, currently aligned one-to-one with `G` |
| `H_act` | 4,743 | Economically active household agents, including workers and business owners |
| `H_inact` | 4,130 | Economically inactive household agents |
| `I_s` | 62×1, sum 624 | Number of firms in each sector |
| `J` | 156 | Number of government purchasing entities |
| `L` | 312 | Number of foreign-consumer agents |
| `T_prime` | 54 | Historical window available for expectation estimation |
| `T` | 12 | Calibration or forecast horizon in quarters |
| `T_max` | 12 | Future quarters for which observed exogenous data is available |

`G`, `I_s`, `H_act`, `H_inact`, `J`, and `L` determine array sizes and agent
populations. `S`, `T`, and `T_max` are primarily calibration metadata and are
not consumed by the runtime simulation.

## Household, banking, and credit parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `psi` | 0.909668 | Fraction of expected disposable income allocated to consumption |
| `psi_H` | 0.071251 | Fraction allocated to residential investment |
| `theta_UB` | 0.358583 | Unemployment-benefit replacement rate |
| `theta_DIV` | 0.785807 | Fraction of after-tax positive corporate profits distributed as dividends |
| `theta` | 0.05 | Fraction of outstanding firm debt repaid each quarter |
| `mu` | 0.026714 | Commercial-loan risk premium over the policy rate |
| `zeta` | 0.03 | Bank capital requirement used to cap total credit |
| `zeta_LTV` | 0.60 | Maximum loan-to-value ratio for firm credit |
| `zeta_b` | 0.50 | Debt-to-capital ratio assigned to a replacement firm after bankruptcy |

Consumption and residential investment must satisfy

```math
\psi + \psi_H \leq 1.
```

The current eight-input generator explicitly enforces this constraint. Credit
parameters also need positive denominators and economically valid balance-sheet
limits.

## Fiscal parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `tau_INC` | 0.213407 | Household income-tax rate |
| `tau_FIRM` | 0.077012 | Corporate profit-tax rate |
| `tau_VAT` | 0.152868 | VAT on household consumption |
| `tau_SIF` | 0.212151 | Employer social-insurance contribution |
| `tau_SIW` | 0.171148 | Employee social-insurance contribution |
| `tau_EXPORT` | 0.002949 | Tax on exports |
| `tau_CF` | 0.087614 | Tax on household capital formation |
| `tau_G` | 0.009148 | Tax on government consumption |

Most fiscal parameters affect agent budgets and government revenue. `tau_G`
primarily affects recorded government-consumption and accounting aggregates,
not the government's behavioral expenditure rule.

## Monetary-policy parameters

The policy rate follows

```math
r_t = \max\left(0,\rho r_{t-1} + (1-\rho)\left[r^* + \pi^*
      + \xi_\pi(\pi_t-\pi^*) + \xi_\gamma\gamma_t\right]\right).
```

| Parameter | Baseline | Meaning |
|---|---:|---|
| `rho` | 0.925967 | Interest-rate smoothing or persistence |
| `r_star` | -0.003425 | Equilibrium real interest rate |
| `pi_star` | 0.004963 | Inflation target |
| `xi_pi` | 0.309969 | Policy response to the inflation gap |
| `xi_gamma` | 1.328593 | Policy response to euro-area GDP growth |
| `r_G` | 0.008981 | Interest rate paid on government debt |

These parameters cannot all use generic `[0, 1]` bounds: `r_star` is negative
in the baseline and `xi_gamma` is greater than one.

## Exogenous AR(1) processes

The shipped Austrian calibration uses the log-level form

```math
X_t = \exp\left(\alpha_X \log X_{t-1} + \beta_X + \varepsilon_t\right).
```

| Process | Persistence | Intercept | Innovation scale |
|---|---:|---:|---:|
| Government consumption | `alpha_G` = 0.990595 | `beta_G` = 0.093732 | `sigma_G` = 0.011235 |
| Export demand | `alpha_E` = 0.962809 | `beta_E` = 0.392600 | `sigma_E` = 0.020320 |
| Import supply | `alpha_I` = 0.966236 | `beta_I` = 0.354928 | `sigma_I` = 0.021228 |
| Euro-area GDP | `alpha_Y_EA` = 0.963578 | `beta_Y_EA` = 0.536003 | `sigma_Y_EA` = 0.006618 |
| Euro-area inflation | `alpha_pi_EA` = 0.384561 | `beta_pi_EA` = 0.002622 | `sigma_pi_EA` = 0.002533 |

Euro-area inflation uses `log(1 + inflation)`. `sigma_G` and `sigma_pi_EA`
directly generate shocks. The current simulation does not directly use
`sigma_E`, `sigma_I`, or `sigma_Y_EA`; their correlated innovations are drawn
from `C` instead.

## Sector-specific production parameters

Each parameter below is a 62×1 vector with one value per sector.

| Parameter | Baseline range | Meaning |
|---|---:|---|
| `alpha_s` | 10.43–480.92 | Labor productivity: output per worker |
| `beta_s` | 1.06–8.22 | Intermediate-input productivity |
| `kappa_s` | 0.033–5.749 | Capital productivity |
| `delta_s` | 0.0009–0.1911 | Capital depreciation rate |
| `w_s` | 0.270–53.77 | Reference wage by sector |
| `tau_Y_s` | 0.0009–0.0659 | Sector-specific product or output tax |
| `tau_K_s` | -0.2611–0.0453 | Sector-specific production tax; negative values represent subsidies |

The firm-level Leontief production function is

```math
Y_i = \min(Q_i^*, N_i\alpha_i, K_i\kappa_i, M_i\beta_i).
```

These vectors should not be varied cell-by-cell without preserving sectoral
consistency and plausible firm profitability.

## Product-composition vectors

Each parameter is a 62×1 vector of product shares.

| Parameter | Meaning |
|---|---|
| `b_HH_g` | Household-consumption basket |
| `b_CFH_g` | Household residential-investment basket |
| `b_CF_g` | Firm fixed-capital-formation basket |
| `c_G_g` | Government-consumption composition |
| `c_E_g` | Export composition |
| `c_I_g` | Import composition |

These vectors are normalized compositions whose elements sum to approximately
one. Perturb the complete vector and renormalize it instead of sampling cells
independently.

## Input-output and shock matrices

| Parameter | Shape | Meaning and constraint |
|---|---:|---|
| `a_sg` | 62×62 | Input-output technology matrix. Row `g` is an input product and column `s` is a producing sector. Sectoral input compositions must preserve normalization and non-negativity. |
| `C` | 3×3 | Covariance matrix for shocks to euro-area GDP, exports, and imports. It must remain symmetric positive-definite because the simulation uses a Cholesky decomposition. |

## Inventory columns

- `parameter`: key in the calibration dictionary.
- `type`: Julia runtime type.
- `shape`: scalar or array dimensions.
- `baseline`: exact scalar value or min/max/mean array summary.
- `classification`: structural, scalar candidate, or constrained group.
- `screening_eligible`: `false` only for explicitly structural parameters.
- `source_usage`: source locations containing the exact text
  `parameters["name"]`.
- `review_note`: required next step before screening.

`source_usage` is a text search, not a complete dependency graph. It does not
follow downstream uses after values are copied into `model.prop`, `model.rotw`,
or another agent.

## Relationship to the current surrogate pipeline

The inventory identifies 53 possible screening candidates, but the current
dataset generator samples only

```julia
psi, psi_H, mu, theta_UB, theta_DIV, theta, zeta, zeta_LTV
```

That generator is an older eight-input pipeline check. Before expanding it to
all candidates, define economic bounds for every scalar and
structure-preserving transformations for every vector and matrix.
