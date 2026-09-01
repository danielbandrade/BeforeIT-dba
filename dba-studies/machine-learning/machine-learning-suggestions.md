# Machine-learning suggestions for BeforeIT

Machine learning can be used in two different ways:

1. Study the existing model without changing its economic mechanisms.
2. Replace selected behavioural rules with learned decisions.

The first approach is the safer starting point because the model remains
economically interpretable.

## 1. Build a surrogate model

Run BeforeIT many times under different parameters, shocks, initial conditions,
and policies. Train a machine-learning model to approximate the simulation:

$$
\mathcal{S}(\theta, x_0, \varepsilon, p)
=
(Y, \pi, u, G)
$$

Here, $\mathcal{S}$ is the surrogate, $\theta$ contains model parameters,
$x_0$ is the initial state, $\varepsilon$ contains shocks, $p$ is policy,
and the outputs are GDP $Y$, inflation $\pi$, unemployment $u$, and
inequality $G$.

The surrogate could answer questions such as:

- Which parameters drive recessions?
- What produces persistent unemployment?
- Which policies reduce inequality without greatly reducing output?
- Where are the model's tipping points?

A gradient-boosted tree would be a sensible first method. A neural network
would only become necessary for large or complete time-series outputs.

## 2. Use simulation-based inference for calibration

BeforeIT is stochastic and does not provide a convenient analytical
likelihood. Simulation-based inference could estimate which parameter values
are plausible given observed economic data:

$$
p(\theta \mid X_{\mathrm{observed}})
$$

The workflow would be:

```text
sample parameter values
    -> run BeforeIT
    -> compare simulated and observed statistics
    -> learn which parameter combinations are plausible
```

Unlike selecting one best calibration, this produces uncertainty intervals and
reveals when multiple parameter combinations explain the same observations.

## 3. Explain firm and household outcomes

Train supervised models on simulation records to study outcomes such as firm
bankruptcy, unemployment, income loss, or credit rationing.

For example:

$$
\Pr(B_{i,t+1}=1)
=
f(L_{i,t},D_{i,t},E_{i,t},\Pi_{i,t},K_{i,t},N_{i,t},G_i,r_t)
$$

Feature importance could reveal nonlinear thresholds that are difficult to see
from individual equations. Here, ML is an analytical instrument and does not
participate in the simulation.

## 4. Discover economic regimes

Use clustering to identify recurring patterns across simulations, such as:

- Stable growth
- Inflationary expansion
- Credit-constrained stagnation
- Bankruptcy cascades
- Deflationary recessions
- Unequal recoveries

Represent each simulation with a compact feature vector:

$$
z_s=
(\bar{\gamma}_s,\sigma_{\gamma,s},\bar{\pi}_s,u_s,B_s,C_s,G_s)
$$

Here, $z_s$ describes simulation $s$ using average GDP growth, growth
volatility, average inflation, unemployment, bankruptcies, credit rationing,
and income inequality.

Clustering these vectors could show whether continuous parameter changes lead
to qualitatively different economic regimes.

## 5. Replace one firm rule with reinforcement learning

Instead of converting every firm into a learning agent, replace one decision
rule for a small share of firms.

Information available to an RL firm:

$$
s_{i,t}=
(Q^d_{i,t},S_{i,t},K_{i,t},M_{i,t},L_{i,t},D_{i,t},\pi_t^e,\gamma_t^e)
$$

Decisions made by the firm:

$$
a_{i,t}=(P_{i,t},Q^s_{i,t},I_{i,t})
$$

Possible reward:

$$
R_{i,t}=\Pi_{i,t}-\lambda_B\mathbf{1}(E_{i,t}<0)
$$

Compare economies containing 0%, 10%, 50%, and 100% RL firms. This would test
whether individually more adaptive firms stabilize or destabilize the wider
economy.

## 6. Learn heterogeneous household consumption

The baseline model uses a common consumption propensity. A model estimated from
household data could instead represent heterogeneous behaviour:

$$
C^d_{h,t}=
f(Y^e_{h,t},D_{h,t},K_{h,t},O_{h,t},T_h,\pi_t^e)
$$

This could capture different responses among low-income households, wealthy
households, unemployed workers, wage earners, and investors.

The learned rule should retain explicit economic constraints:

$$
C^d_{h,t}\geq 0
$$

$$
B_{h,t}\leq \bar{B}_{h,t}
$$

This application would be especially useful for studying inequality and
distributional effects of fiscal policy.

## 7. Optimize policy

Treat BeforeIT as an environment for evaluating candidate policies.

$$
p=(\tau_{INC},\tau_{VAT},\theta_{UB},sb_{other},\bar{r})
$$

A policy objective could be expressed as:

$$
J(p)=
Y
-\lambda_u u
-\lambda_\pi\lvert\pi-\pi^*\rvert
-\lambda_G G
-\lambda_D L_G
$$

Bayesian optimization could search for promising policies with fewer expensive
simulation runs. The preferred result should be a set of trade-offs rather
than a supposedly universal optimum:

$$
\text{equality}\longleftrightarrow\text{output}
$$

$$
\text{lower debt}\longleftrightarrow\text{stronger stabilization}
$$

The weights placed on these objectives are political or normative choices, not
facts that machine learning can determine.

## Recommended progression

1. Generate a structured dataset from repeated BeforeIT simulations.
2. Train a surrogate and perform sensitivity analysis.
3. Add distributional outputs such as income and wealth inequality.
4. Use simulation-based inference to improve calibration.
5. Only then experiment with one RL-controlled behavioural rule.

An accurate surrogate only reproduces the assumptions embedded in BeforeIT. It
does not independently validate those assumptions or establish causal effects
in the real economy.
