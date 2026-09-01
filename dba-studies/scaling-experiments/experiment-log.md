# Scaling experiments

## Purpose

These experiments test how BeforeIT changes when the same empirically calibrated
Italian economy is represented with different numbers of agents. The central
question is whether aggregate dynamics are robust to population resolution or
partly driven by finite-population effects.

The experiments use:

- Italy calibrated at 2010Q1;
- `Bit.get_params_and_initial_conditions` with the requested `scale`;
- a 12-quarter horizon;
- random seed `1234`;
- serial execution inside each simulation (`parallel = false`).

`scale = 0.1` represents approximately one tenth of the empirical population.
`scale = 1` uses the full counts in the Italian calibration data. Aggregate
national-accounting stocks and flows describe the same economy at both scales;
the calibration changes agent counts and corresponding per-agent quantities.

## Calibration fallbacks

Both runs emitted the same non-fatal warnings:

```text
Using annual 'interest_government_debt' - will apply timescale conversion
wages_by_sector not available, estimating from aggregate wages
Using annual 'government_deficit' - will NOT apply timescale conversion
```

Government-debt interest is converted from an annual to a quarterly flow. The
annual government deficit is used directly in the annual accounting identity.
Because the legacy Italian dataset contains only aggregate wages, sector wages
are allocated in proportion to sector employee compensation. Total wages are
preserved, but observed sector differences in the wage-to-compensation ratio are
not represented.

## Experiment 1 — scale 0.1

```text
country: Italy
calibration date: 2010Q1
scale: 0.1
seed: 1234
horizon: 12 quarters
firms: 466,050
active households: 2,352,163
inactive households: 3,629,784
initial real GDP: 396,922.2000
final real GDP: 401,029.5458
runtime: 232.7307 seconds (3.88 minutes)
observations saved: 13
output: scale-0.1-results.jld2
```

The output has 13 observations because BeforeIT saves the calibrated initial
state followed by 12 simulated quarters.

Real GDP changed by:

$$
\frac{401029.5458}{396922.2000}-1
=1.035\%
$$

## Experiment 2 — scale 1

```text
country: Italy
calibration date: 2010Q1
scale: 1
seed: 1234
horizon: 12 quarters
firms: 4,660,448
active households: 23,521,560
inactive households: 36,297,840
initial real GDP: 396,922.2000
final real GDP: 393,436.1780
runtime: 3,549.2040 seconds (59.15 minutes)
observations saved: 13
output: scale-1-results.jld2
```

Real GDP changed by:

$$
\frac{393436.1780}{396922.2000}-1
=-0.878\%
$$

Terminal log:

```text
firms: 4.660448e6
active households: 2.352156e7
inactive households: 3.629784e7
Initializing model...
Running 12 quarters...
Finished in 3549.2 seconds
final real GDP: 393436.1780270567
saved: dba-studies/scaling-experiments/scale-1-results.jld2
```

## Initial comparison

| Measure | Scale 0.1 | Scale 1 | Difference |
|---|---:|---:|---:|
| Firms | 466,050 | 4,660,448 | approximately 10× |
| Total households | 5,981,947 | 59,819,400 | approximately 10× |
| Runtime | 232.73 s | 3,549.20 s | 15.25× |
| Initial real GDP | 396,922.20 | 396,922.20 | effectively zero |
| Final real GDP | 401,029.55 | 393,436.18 | −7,593.37 |
| 12-quarter GDP change | +1.035% | −0.878% | −1.913 percentage points |

The identical initial GDP confirms that increasing the scale changes the
resolution of the economy rather than its calibrated aggregate size. Runtime
grew faster than the agent population: a tenfold increase in population took
about 15.25 times longer.

The difference in final GDP is not yet evidence of a systematic scale effect.
Each scale currently has only one stochastic run. Even with the same seed, the
random draws are assigned across different numbers of agents, so the two paths
are not paired realizations of identical microeconomic shocks.

## Next experiment

Run several seeds at each scale and compare distributions rather than individual
paths. At minimum, record the mean and standard deviation of final GDP, GDP
growth, unemployment, firm exits, and credit rationing. A useful next design is:

$$
\text{scale}\in\{0.001,0.01,0.1,1\}
$$

with at least 10 seeds per feasible scale. The full-scale runs take about one
hour each on the current machine, so fewer full-scale repetitions or a compute
server may be necessary.
