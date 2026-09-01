# Outline — BeforeIT basics

Narrative: from the paper's forecasting problem to one quarter inside the
simulation, then back out to forecasts and experiments.

1. **BeforeIT simulates the economy from the bottom up**
   - Fact: the package implements a behavioral macro agent-based model in Julia.
   - Visual: cover with an abstract economy network becoming a GDP line.

2. **The paper turns an ABM into a forecasting instrument**
   - Fact: the 2023 model achieved out-of-sample performance competitive with
     benchmark VAR and DSGE models.
   - Visual: three-model comparison centered on the ABM's added sector detail.

3. **Macro outcomes emerge instead of being imposed**
   - Fact: heterogeneous agents follow rules and interact outside a solved
     representative-agent equilibrium.
   - Visual: micro agents → markets → GDP, inflation, and employment.

4. **Real data reconstructs the starting economy**
   - Fact: calibration combines national accounts, sector accounts,
     input-output tables, government data, census, and business demographics.
   - Visual: data streams converging into the initial-state model.

5. **Six economic roles form one connected system**
   - Fact: households, firms, banks, central bank, government, and rest of world
     exchange labour, goods, credit, taxes, and trade flows.
   - Visual: circular economy map with six nodes and labeled flows.

6. **The Austrian calibration is detailed but computationally scaled**
   - Fact: 624 firms, 8,873 people, 62 sectors, 156 government entities, and 312
     foreign consumers represent Austria in 2010Q1.
   - Visual: large-number stat strip plus scale annotation.

7. **One call to `step!` advances one quarter**
   - Fact: six ordered phases connect expectations to final accounting.
   - Visual: horizontal six-stage process flow.

8. **Firms plan before they know realized demand**
   - Fact: firms choose target output, prices, inputs, employment, and credit
     from expectations and prior outcomes.
   - Visual: decision funnel from forecasts to desired quantities.

9. **The scarcest input determines production**
   - Fact: Leontief output is the minimum of target, labour, capital, and
     intermediate-input capacities.
   - Visual: four capacity bars with the binding minimum highlighted.

10. **Search and matching creates rationing and propagation**
    - Fact: credit, labour, and goods markets match decentralized buyers and
      sellers in random order.
    - Visual: three linked matching panels ending in realized transactions.

11. **Accounting closes the quarter and feeds the next one**
    - Fact: sales update profits, balance sheets, government debt, GDP, prices,
      inventories, and the next expectation round.
    - Visual: feedback loop from realized trades to updated state.

12. **A forecast is a distribution, not one trajectory**
    - Fact: repeated Monte Carlo runs generate aggregate and sector-level
      forecast distributions.
    - Visual: several paths opening into a forecast fan.

13. **The same machinery evaluates counterfactual shocks**
    - Fact: shocks enter before firm planning and can alter monetary, fiscal,
      productivity, or consumption conditions.
    - Visual: baseline/shock fork followed by outcome comparison.

14. **BeforeIT makes the research model inspectable and extensible**
    - Fact: the current API initializes and runs the Austrian calibration in a
      few Julia lines; the software paper reports major speed gains over Matlab.
    - Visual: terminal-style code block paired with a compact benchmark strip.

15. **Read `step!`, then run a baseline and one shock**
    - Fact: this is the shortest path from the paper's theory to the model's
      causal mechanics.
    - Visual: three-step academic CTA and compact bibliography.
