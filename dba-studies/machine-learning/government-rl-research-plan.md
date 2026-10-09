# Research plan: a learning fiscal-policy agent in BeforeIT

## Research question and scope

Can a government agent that adjusts taxes, social benefits, and government
consumption in response to the state of the economy improve a **predeclared
social-welfare objective** in BeforeIT, compared with fixed policies and simple
feedback rules, without unacceptable debt, volatility, or harm to vulnerable
households?

This is a simulation study of **policy design inside BeforeIT**. A positive
result would show what works under this model's assumptions; it would not by
itself establish an optimal policy for a real country. The immediate goal is to
decide whether a larger reinforcement-learning (RL) project is justified.

The idea extends [the existing ML suggestions](machine-learning-suggestions.md#7-optimize-policy):
their section 7 searches for a fixed policy vector, whereas this study asks
whether a *state-dependent sequence* of policy choices adds value. It also
respects the [recommended progression](machine-learning-suggestions.md#recommended-progression):
measure stochastic variation, examine policy sensitivity, and use the
[surrogate study](surrogate/surrogate-generation-plan.md) only after that model
passes its own validation gates.

## What is new and what is already known

Learning tax policy in a simulated economy is an established research idea:
[the AI Economist](https://arxiv.org/abs/2108.02755) trains a social planner in
an environment whose individual agents also learn. This proposal asks a narrower
question in a calibrated macroeconomic agent-based model: whether a learning
fiscal authority improves a transparent welfare measure when BeforeIT's firms
and households retain their existing behavioral rules. BeforeIT provides an
extensible simulation platform ([software paper](https://arxiv.org/abs/2502.13267)).
Published work on [robust policy design in agent-based simulators](https://openreview.net/pdf?id=vPzij1AYf2)
motivates testing across model assumptions, rather than relying on one
calibration and seed panel. These references motivate the experiment; they do
not validate this particular fiscal-policy setup.

## Hypotheses

1. **Policy response:** changes in the selected tax, benefit, and government
   consumption instruments produce measurable effects on household outcomes
   and fiscal accounts over a 12-quarter horizon. If effects are smaller than
   simulation noise, stop.
2. **Value of adaptation:** a state-dependent policy improves held-out welfare
   over the best feasible fixed policy and a simple feedback rule at a matched
   simulation budget. If it does not, RL adds no demonstrated value.
3. **Robustness:** any gain persists under unseen shocks, initial conditions,
   and plausible parameter perturbations, without worsening predeclared
   distributional or fiscal guardrails.

## Sequential decision problem

Use one BeforeIT run as an episode. At each decision quarter, the government
observes data available at the **end of the previous quarter**, selects a
policy, then the simulator advances one quarter. The central bank and all other
agent rules remain as implemented. There is one learning government agent, not
a second RL system for households or firms.

| Component | Pilot specification | Check before implementation |
| --- | --- | --- |
| Horizon | 12 quarters; report terminal as well as cumulative outcomes | Test whether a longer horizon changes the ranking or only rewards debt-financed short-run gains. |
| Observation $o_t$ | Lagged real GDP growth, inflation, unemployment, debt/GDP, government revenue, real government consumption, real consumption by household group, and current policy settings | Derive unavailable series from end-of-quarter model state. Verify units, group coverage, and that no current-quarter result leaks into the observation. |
| Action $a_t$ | Income-tax rate `model.prop.tau_INC`, unemployment-benefit replacement rate `model.prop.theta_UB`, and a bounded multiplier on government consumption demand | Bound levels and quarter-to-quarter changes using economically defensible ranges. Set rates after model initialization; apply the spending multiplier at the spending-decision point. |
| Later actions | VAT `model.prop.tau_VAT` and the general benefit `model.gov.sb_other` | Add only if the pilot instruments have identifiable effects and the transfer's update/indexation semantics are resolved. |
| Transition | Apply tax/benefit rates at the quarter boundary and the spending multiplier through the existing government-consumption rule; call `Bit.step!`, then `Bit.collect_data!` | Record proposed and applied actions, state, seed, and failures. Verify action timing and fiscal accounting. |

The pilot uses quarterly decisions to identify whether feedback helps; repeat
the comparison with annual policy changes if the quarterly policy is promising.
Do not include the interest rate: BeforeIT's central-bank rule sets it.

The code already uses `tau_INC` in household budgets and government revenue,
and `theta_UB` in unemployed household income and government benefit costs.
`sb_other` is a broad benefit that is automatically multiplied by expected
growth during each step; choosing a nominal level at the quarter boundary is
therefore not the same as choosing the transfer households receive. Its control
contract must be specified and checked against the accounting equations before
it joins the action space. Also inspect whether stored initial-condition fields
such as `model.prop.sb_other` need consistent treatment when benefits change.

Government consumption requires a different control point. In the existing
step, `set_gov_expenditure!` draws a new `model.gov.C_G` from an autoregressive,
stochastic rule and derives local demand `model.gov.C_d_j`; setting `C_G` at the
quarter boundary would be overwritten. Represent the policy action as a
multiplier $m^G_t$ on that quarter's rule-generated demand, with $m^G_t=1$ as
the no-op action. The intended effect is to scale `C_G` and every element of
`C_d_j` together at the spending decision, before the goods market. This
preserves their existing relationship and allows the altered `C_G` to
feed into next quarter's autoregressive rule. Implement this for the base
model with a study-local `PolicyModel` type and a dispatched
`gov_expenditure(model::PolicyModel)` method that scales both outputs of the
existing spending rule. The quarterly step loop remains unchanged. Verify
no-op equivalence; model extensions with different spending rules need their
own control contract. Record both
planned demand and realized spending
`model.gov.C_j`; they can differ because goods must be purchased in the market.
Check this intervention against the government debt identity before training.

### Welfare and constraints

Choose welfare weights **before** training. One transparent candidate is

$$
J(\mu)=\mathbb E\!\left[\sum_{t=1}^{T}\gamma^{t-1}
\left(
\frac{1}{H}\sum_{h=1}^{H}
\log\frac{c^{\mathrm{real}}_{h,t}+\epsilon}{c_{\mathrm{ref}}}
+\lambda_G\log\frac{g^{\mathrm{real}}_t/H+\epsilon_G}{g_{\mathrm{ref}}}
-\lambda_u u_t
-\lambda_\pi |\pi_t-\pi^*|
-\lambda_a\lVert a_t-a_{t-1}\rVert
\right)\right].
$$

Here $\mu$ is the government policy rule, $\pi_t$ is the inflation rate, and
$u_t$ is the unemployment rate among active workers. The term
$-\lambda_u u_t$, with a predeclared $\lambda_u>0$, penalizes unemployment in
every quarter's reward.
$c^{\mathrm{real}}$ is realized household consumption deflated with an
appropriate price index, $g^{\mathrm{real}}_t$ is realized government
consumption. The reference values and small offsets
are fixed from baseline
data. The government-consumption term is a **proxy** for the value of public
services: BeforeIT records spending but does not establish its utility or
quality. Report results with $\lambda_G=0$ and with a predeclared positive
range, since policy rankings may depend strongly on that assumption. Scale
components of $a_t-a_{t-1}$ by their allowed adjustment ranges before applying
the change penalty. Concavity gives greater weight to consumption gains among
households with less consumption. Check zero consumption and units before using
the logarithm. The weights, discount factor, inflation target, and reference
scale are normative research choices, not quantities learned from the data.
Publish a small, predeclared range of these choices and the resulting trade-offs
instead of reporting one universal optimum.

Apply hard feasibility rules to rate levels and policy changes. Specify debt and
deficit guardrails after measuring the baseline distribution, with a terminal
debt/GDP check so a policy cannot improve near-term welfare solely by shifting
costs beyond the episode. Report any constraint violation separately from the
reward. Track the bottom consumption quintile, consumption inequality, employment,
GDP, realized government consumption, inflation, and debt paths even if they
are not all reward terms. Define household coverage explicitly, including firm
and bank owners represented in the model. If the model cannot support a
credible household welfare measure, use a labeled proxy and narrow the study's
claim accordingly.

## Experimental sequence and decision gates

### 1. Establish the policy interface and measurement

- Audit the tax, benefit, government consumption, initialization, and debt
  equations; map each chosen instrument to affected functions and outcomes.
- Reproduce the unchanged baseline with the new policy wrapper and verify that
  a no-op action gives the same results as the original run under the same seed.
- Verify that a spending multiplier of one exactly reproduces the existing
  stochastic spending rule and that other multipliers preserve the relation
  between `C_G` and `C_d_j`.
- Verify observation timing, fiscal identities, household group counts, and
  reward calculations on a few hand-inspected episodes.

**Gate 1:** policy interventions change only the intended variables, the no-op
wrapper is neutral, and every reward and guardrail can be reconstructed from
saved run data.

### 2. Test policy sensitivity before RL

- Run paired baseline and feasible perturbations of income tax, unemployment
  benefits, and government-consumption demand under a common seed panel.
  Estimate mean effects and Monte Carlo uncertainty for household and public
  consumption, unemployment, revenue, and debt.
- Explore interactions and boundary behavior with a small space-filling policy
  design. Increase seed count until uncertainty is below a predeclared minimum
  effect of interest; choose that effect before viewing policy rankings.
- Check whether the model's behavioral responses to these interventions are
  plausible against available empirical evidence. Note mechanisms the model
  omits, such as tax avoidance or changes in labor supply, if applicable.

**Gate 2:** at least one feasible instrument has a stable, interpretable effect,
the baseline remains fiscally coherent, and the policy domain has no unresolved
accounting or calibration issue. Otherwise stop or revise the simulator first.

### 3. Build strong, simple comparators

Compare: (a) calibrated status quo; (b) the best feasible **fixed** tax,
benefit, and spending settings found by grid or Bayesian optimization; and
(c) a predeclared feedback rule that adjusts benefits with unemployment, taxes
with debt, and spending with weak GDP growth. Tune each on the same training
scenarios and charge all simulator calls, including tuning, to the reported
compute budget. A fixed-policy search directly tests section 7 of
the [ML suggestions](machine-learning-suggestions.md#7-optimize-policy).

**Gate 3:** retain RL as a research question only if the fixed and feedback
baselines are reproducible and there is meaningful variation across states for
an adaptive policy to exploit.

### 4. Train the smallest useful learning policy

Start with a small discrete action set of permitted rate and spending changes
and a tabular or compact function-approximation RL method, chosen after
measuring observation dimension and sample cost. Move to continuous-action
or deep RL only if this
baseline cannot represent useful behavior. Train on multiple seeds and
plausible shocks; log reward components, actions, violations, failures, and
simulation cost. Do not optimize the policy on the existing surrogate until
that surrogate is validated for *policy interventions*; prediction accuracy for
passive trajectories alone is insufficient. Always replay selected policies in
the full BeforeIT simulator.

**Gate 4:** the learning curve is stable across independent training runs, and
the policy is inspectable enough to explain which state changes trigger tax,
benefit, or spending adjustments.

### 5. Evaluate once on held-out scenarios

Freeze policy code, reward definitions, weights, feasibility rules, and
baseline tuning before final evaluation. Partition by complete simulation
scenario, not by quarter or household observation. Use separate test seeds,
shock sequences, initial conditions, and feasible parameter configurations.
Evaluate all policies on matched test scenarios and report paired differences
with confidence intervals, tail losses, constraint-violation rates, and paths
for every welfare component. Test several predeclared welfare weights, longer
horizons, and weaker/stronger behavioral responses. Do not select a winner from
the held-out set and then reuse it as an unbiased test.

**Go:** pursue the larger project only if RL beats both tuned comparators by a
predeclared minimum welfare gain on held-out scenarios, the uncertainty interval
supports that gain, fiscal and distributional guardrails pass, and the result is
not driven by one calibration or exploitable model artifact.

**No-go or redesign:** if static or simple feedback policy matches RL, if
results change sign under plausible assumptions, or if the agent exploits a
simulator omission, keep the simpler policy analysis and improve the economic
model before increasing RL complexity.

## Expected deliverables

1. A documented policy interface and observation/reward schema with equations
   and units.
2. A paired sensitivity report with a justified policy domain and noise floor.
3. Fixed-policy, feedback-rule, and RL evaluations under a comparable run
   budget, including all failed runs.
4. A table or frontier of welfare, distributional, and fiscal trade-offs across
   predeclared weights and model variants.
5. A short go/no-go memo distinguishing findings *within BeforeIT* from claims
   that would require external empirical validation.
