# ODD+D Description of the Austrian Small-Open-Economy ABM

## Extraction scope

This description covers the implemented Austrian agent-based model (ABM) reported by Sebastian Poledna, Michael Gregor Miess, Cars Hommes, and Katrin Rabitsch in *Economic forecasting with an agent-based model*, *European Economic Review* 151 (2023), 104306. The paper does not give the ABM a distinct proper name.

Three uses or variants are distinguished:

1. the baseline model used for unconditional forecasts;
2. a conditional-forecast setup in which realized paths of Austrian exports, imports, and government consumption are supplied to the ABM; and
3. a COVID-19 scenario variant that adds a domestic supply shock, an export-demand shock, an import-supply shock, and a short-time-work policy.

The VAR, VECM, AR, and DSGE models in the paper are benchmarks, not variants of the ABM.

The attached paper describes an implemented model but provides only a **partial model description**. It explicitly places the exact behavioral equations, market algorithms, accounting definitions, detailed calibration, conditional-forecast implementation, and COVID-19 shock implementation in an Online Appendix that was not attached and therefore was not used. The reconstruction below uses only the attached 26-page article. Page citations refer to the article's printed page numbers.

# I. Overview

## I.i Purpose

### I.i.a Study purpose

**[Explicit]** The model was developed to fit the historical state of a data-rich small open economy and produce out-of-sample forecasts of aggregate variables, including GDP and its components, inflation, and interest rates. Its forecast performance is validated against standard time-series and DSGE benchmarks. Its detailed sectoral structure also supports disaggregated forecasting and policy analysis; the paper demonstrates this by estimating the medium-run effects of Austrian COVID-19 lockdown measures. **Evidence:** pp. 1, 3-4, Abstract and §1; p. 23, §7.

### I.i.b Intended audience

**[Explicit]** The immediate audience is a wide readership interested in macroeconomic modeling and forecasting. The prospective users include researchers and institutional forecasters, while the proposed applications - policy analysis, stress testing, and assessment of monetary and fiscal measures - also target policymakers and decision-makers. **Evidence:** pp. 1-2, Abstract and §1; pp. 23-24, §7.

## I.ii Entities, state variables, and scales

### I.ii.a Entities

**[Explicit]** The model represents the following entity types and organizing structures:

- **Non-financial firms.** Each firm belongs to one NACE/CPA industry and produces that industry's product. The overview twice says that the firm sector contains 64 industries, whereas the calibration section says that the operational values are `S = G = 62` because categories T and U are excluded. The paper does not reconcile this wording; Table 2 supports 62 modeled industries/products.
- **Households/natural persons.** Household agents are classified as employed, unemployed, investors, or inactive. Employed households additionally have sector-specific characteristics. There is one investor owner per firm.
- **General-government entities.** These represent municipalities, public schools, social-insurance carriers, districts, and similar public bodies.
- **A bank/banking sector.** The singular descriptions of lending, balance-sheet constraints, and profit indicate one modeled banking-sector agent, although the sector is also described generically as financial corporations.
- **A central bank.** It sets the policy rate, provides advances, accepts bank reserves, and holds government bonds.
- **Rest-of-world entities.** A segment of domestic firms imports and exports, while foreign consumers/importers represent foreign demand for Austrian products. World prices and aggregate external trade trends are exogenous.
- **Products and industries.** The calibrated model contains 62 modeled product/industry categories aligned with NACE/CPA after excluding categories T and U.
- **Markets and accounting structures.** Credit, labor, and goods markets organize decentralized transactions. Separate agent balance sheets and double-entry flows connect entities across sectors.

**Evidence:** p. 3, §1; pp. 5-6, §§3-3.1; pp. 9-11, §§4.1-4.1.2 and Table 2; p. 20, §5.5.

### I.ii.b Attributes

**[Explicit]** The paper identifies the following attributes, while leaving complete state schemas to the unattached Online Appendix:

| Entity | Dynamic state variables or flows reported | Fixed-within-run parameters or classifications reported |
|---|---|---|
| Firm | Balance-sheet assets and liabilities; equity; deposits and outstanding debt; capital; labor/employment; intermediate inputs; inventory/unsold stock; output, sales, revenue, input costs, cash flow, profit, dividends, prices, and tax/interest payments. Bankruptcy occurs when equity becomes negative. | Industry membership; production technology coefficients for labor, capital, and intermediate inputs; depreciation; average wage; input-output coefficients; product and production tax rates; dividend payout ratio; risk premium; debt-instalment rate; leverage limit; replacement-firm loan-to-capital ratio. Initial firm sizes match a power-law distribution, but whether size is subsequently treated as a parameter or state is not stated. |
| Household | Employment status; sector of employment; wage or previous wage; labor, benefit, dividend, transfer, and disposable income; deposits; consumption and housing-investment expenditure. The complete balance-sheet fields are not listed. | Household type at initialization; marginal propensities to consume and invest in housing; income and employee social-insurance tax rates; unemployment replacement rate. Whether type memberships other than employment status can change is not reported. |
| Investor household | Firm ownership and dividend income, in addition to household attributes. | One investor is assigned to each firm; the persistence of that assignment is not reported. |
| Government entity/sector | Tax and contribution revenues; transfers, subsidies, consumption, interest and other expenditures; deficit and debt. A deficit raises subsequent debt and interest payments. | Number of government entities; tax rates; government-bond rate; government-consumption process parameters. |
| Bank | Household and firm deposits; firm loans; capital/equity; central-bank reserves and advances; interest income and expense; bad-debt write-offs; profit. | Capital ratio, loan-to-value ceiling, policy-rate markup/risk premium, and lending conditions. |
| Central bank | Policy rate; advances to and reserves from the bank; external assets/government bonds. | Inflation/growth targets and Taylor-rule coefficients. |
| Rest of world/foreign consumers | Imports supplied and exports demanded during a period; euro-area GDP and inflation enter as external macro states. | Number of foreign consumers; parameters of the import, export, euro-area GDP, and euro-area inflation processes. |
| Product/industry | Industry output, price, demand, supply, value added, employment, and inter-industry input flows can vary over time. | NACE/CPA identity; Leontief technology and use coefficients; industry-specific tax, wage, productivity, capital, and depreciation parameters. |
| Firms and households that form expectations | Expected log output, expected producer-price inflation, implied expected real growth and inflation, AR(1) parameter estimates, and forecast errors. | The forecasting-rule class - univariate AR(1) - is fixed and homogeneous; its two coefficients are learned over time. |

**Evidence:** pp. 3-4, §1; pp. 6-9, §§3.1-3.5; pp. 10-12, §§4.1.2-4.1.5 and Table 2; p. 20, §5.5.

### I.ii.c Exogenous factors

**[Explicit]** Baseline external drivers are Austrian exports, imports, and final government consumption, plus euro-area GDP growth and inflation; each follows an estimated AR(1) process and is disturbed by exogenous shocks. There are also exogenous shocks to agents' forecasts of log output and producer-price inflation. World prices are unaffected by the modeled Austrian economy. The policy rate is endogenous to a generalized Taylor rule, but the attached paper does not fully specify the rule's inputs. In conditional forecasts, observed future paths of exports, imports, and government consumption replace their freely simulated paths. The COVID-19 application additionally imposes a lockdown-related domestic supply shock, export-demand and import-supply shocks, and the short-time-work policy. **Evidence:** pp. 6 and 8, §§3.1 and 3.4; p. 12, §4.1.5; p. 16, §5.3; p. 21, §6.

### I.ii.d Representation of space

**[Not reported]** The model's geographical extent is Austria interacting with the euro area/rest of world, but the paper reports no explicit within-country spatial coordinates, grid, GIS layer, distance, neighborhood, boundary, or movement rule. The NUTS 2 field in one census dataset is named, but no use of NUTS regions as model space is described. Market search and matching is organized by economic market and product/industry, not by a reported physical topology. The article does not establish whether spatial detail exists in the full implementation. **Evidence:** p. 6, §3.1; pp. 9-10, §§4.1-4.1.1 and Table 1.

### I.ii.e Temporal and spatial scales

**[Explicit]** One simulation period is one quarter. Each baseline forecast recursively simulates at most 12 quarters. Forecast validation recalibrates the ABM at 39 reference quarters from 2010:Q1 through 2019:Q3 and evaluates forecasts through 2019:Q4. Exogenous AR(1) and Taylor-rule parameters use expanding samples beginning in 1997:Q1, with 1996:Q2-1996:Q4 as presample. The COVID-19 analysis follows trajectories through the end of 2022. The spatial extent is the Austrian national economy, with the euro area/rest of world represented externally. Agent resolution is 1:1: each agent represents one natural or legal person/entity. No physical spatial resolution is reported. **Evidence:** pp. 8-9, §§3.5 and 4.1; pp. 12-13, §4.1.5 and §5.1; pp. 21-22, §6.

## I.iii Process overview and scheduling

### I.iii.a Processes and execution order

**[Explicit]** The model is recursive, sequential, and discrete-time. Endogenous variables are solved one at a time. The paper gives this quarterly schedule:

```text
for each quarter:
    1. Form next-quarter output and inflation expectations with learned AR(1) rules.
       Derive expected real growth and expected inflation used by other heuristics.
    2. Draw normal shocks to those expectations and to exogenous AR(1) processes.
    3. Randomly reshuffle relevant agents and solve credit-market matching.
    4. Randomly reshuffle relevant agents and solve labor-market matching.
    5. Carry out firm production.
    6. Randomly reshuffle buyers and solve goods-market matching transaction by transaction.
       Draw sellers with weights increasing in firm size and decreasing in price.
    7. Solve accounting equations; update remaining stocks and flows.
    8. Calculate GDP and other aggregates.
```

Credit, labor, and goods matching is asynchronous/sequential at transaction level because agents are randomly ordered and endogenous quantities are solved one at a time. The paper does not state whether accounting updates within a market are immediate or buffered until the end of that market. Decisions and state updates occur quarterly; several markets can contain many transactions within that period. For a forecast, this loop is run for up to 12 quarters in each of 500 Monte Carlo simulations, after which aggregate trajectories are averaged. The same schedule is stated for baseline forecasting; conditional forecasts substitute realized external paths, and the COVID-19 version modifies shocks and short-time-work behavior, but variant-specific scheduling is not given. **Evidence:** pp. 8-9, §3.5; p. 16, §5.3; p. 21, §6.

# II. Design Concepts

## II.i Theoretical and empirical background

### II.i.a General foundations

**[Explicit]** The model is based on the stylized macro-ABM of Assenza et al. (2015) but expands it to all institutional sectors and detailed Austrian industries. Its accounting structure follows ESA 2010, including separate balance sheets, explicit financial flows, double-entry bookkeeping, and three consistent GDP approaches. Production uses fixed-coefficient Leontief technology calibrated from input-output data. Decentralized search and matching replaces Walrasian market clearing and allows shortages, unsold stocks, and trade frictions. Behavioral Learning Equilibrium (BLE), following Hommes and Zhu (2014), supplies the expectations framework. These components support the paper's complex-systems premise: macroeconomic growth, fluctuations, propagation, and path dependence arise bottom-up from heterogeneous agents, nonlinear constraints, externalities, and market interactions. **Evidence:** pp. 3 and 5, §§1 and 3; pp. 6-8, §§3.1-3.4; p. 20, §5.5.

### II.i.b Decision-model assumptions

**[Explicit]** Firms and households are boundedly rational and use simple heuristics rather than full intertemporal optimization. They face fundamental uncertainty and do not know the economy's true nonlinear law of motion. Their common prediction mechanism is an empirically updated, deliberately misspecified AR(1) rule for log output and producer-price inflation. Firm production, pricing, demand, employment, investment, and related decisions use expected growth and inflation; firm investment tracks expected wear and tear on capital. Household expenditure uses calibrated propensities and, for some rules, expected growth and inflation. Market choice is a probabilistic heuristic based on seller price and size. Bank credit decisions follow capital and borrower-leverage constraints; monetary policy follows a generalized Taylor rule. Some rules are theory- or literature-based (BLE, Leontief production, Taylor rule), some are institutional (tax, benefit, banking rules), some are calibrated empirical relationships, and exact behavioral equations are not in the attached paper. **Evidence:** pp. 2-3, §1; pp. 5-8, §§3-3.4; pp. 11-12, Table 2 and §§4.1.3-4.1.5.

### II.i.c Rationale for model choice

**[Explicit]** The authors choose a data-anchored national-accounting structure to avoid arbitrary agent counts and weak stylized-fact calibration; simple micro heuristics calibrated with data to discipline bounded rationality; adaptive AR(1) learning as the most parsimonious empirically relevant forecasting rule; decentralized matching to represent market institutions and trade frictions; Leontief production because it is consistent with the input-output data and prior literature; and out-of-sample forecast comparison as a stronger empirical validation than merely reproducing stylized facts. The high-resolution sector structure is retained to enable policy and sectoral analysis, while the stated goal remains the simplest prototype whose bottom-up macroeconomy forecasts comparably to standard approaches. **Evidence:** pp. 2-5, §§1-3 and footnote 9; p. 6, §3.1 and footnote 18; p. 7, §§3.2-3.3; p. 23, §7.

### II.i.d Empirical foundation

**[Explicit]** The model is designed, initialized, and calibrated from Austrian micro- and macroeconomic evidence:

- Eurostat population census and business-demography data determine household activity counts, firm counts by industry, and total active persons.
- Eurostat symmetric input-output tables and fixed-asset cross-classifications determine technology, consumption, capital-formation, productivity, depreciation, wage, and industry tax parameters.
- Government statistics and sector accounts determine average tax rates, propensities to consume/invest, dividend payout, interest flows, debt, and related parameters.
- National accounts and money-market series estimate AR(1) external processes and the Taylor rule.
- Statutory rules, Basel III/ECB requirements, banking practice, and literature determine unemployment benefits, capital and lending ratios, repayment, and the inflation target.
- A more detailed purchased Statistik Austria input-output table supplies the investment-purpose breakdown.
- For the COVID-19 variant, Austrian Public Employment Service administrative labor-market data and Oxford Economics scenarios calibrate lockdown, trade, and short-time-work assumptions.

Table 1 provides the Eurostat table codes: `cens_11an_r2`, `bd_9ac_l_form_r2`, `naio_10_cp1700`, `nama_10_nfa_st`, `gov_10a_main`, `gov_10a_exp`, `gov_10q_ggnfa`, `gov_10q_ggdebt`, `nasq_10_f_bs`, `nasa_10_nf_tr`, `nasq_10_nf_tr`, `namq_10_gdp`, and `irt_st_q`. The article identifies administrative/statistical sources but does not describe their original survey sampling or collection instruments. **Evidence:** pp. 9-12, §§4.1-4.1.5 and Tables 1-2; p. 21, §6.

### II.i.e Data aggregation

**[Explicit]** Data occur at several levels: census counts represent individual persons; business demography supplies firms by industry and active persons; input-output tables aggregate transactions by product and industry; cross-classification tables connect institutional sectors to industries/assets; sector and government accounts aggregate institutional-sector flows; and national accounts and interest-rate series are economy-wide quarterly time series. The model nevertheless represents natural and legal persons at 1:1 scale. Consequently, some macro rates are applied uniformly to micro agents: annual average tax rates and propensities are calculated from sector aggregates and assigned to every relevant individual agent, abstracting from tax progressivity and agent-specific exemptions. Firm labor productivity is common within an industry but differs across industries. **Evidence:** pp. 9-12, §§4.1-4.1.3 and footnotes 25-28.

## II.ii Individual decision-making

### II.ii.a Subjects, objects, and levels

**[Explicit]** Reported decision processes are:

| Decision-maker | Object/target and alternatives | Decision level and connections |
|---|---|---|
| Firm | Forecast product demand, input costs, and profit margin; choose planned quantities and prices; seek credit and workers; produce; seek intermediate/capital inputs; sell output; invest to offset expected capital wear; distribute dividends; reduce later production when inventories remain. | Individual firm. Choices depend on common aggregate growth/inflation forecasts, the firm's industry technology and state, financing/input constraints, and realized market matches. |
| Household | Supply labor if active; allocate disposable income to consumption and dwellings; participate as employed, involuntarily unemployed, investor, or inactive; use expected inflation/growth in some expenditure heuristics. | Individual person/household. Income depends on labor matches, sectoral wage, prior wage and benefits, ownership, transfers, and firm outcomes. |
| Customer (household, firm, government, or other demander) | Select a seller for a product and purchase up to its budget and available supply. | Individual transaction. Seller selection is random with price/size weights; aggregate shortages can prevent budget exhaustion. |
| Firm in labor market | Select an applicant after firms are randomly ordered. | Individual transaction; detailed applicant ranking and hiring criteria are not reported. |
| Bank | Set the loan rate as a markup over policy rate; grant or limit firm credit. | Bank-firm relationship constrained by bank capital and borrower leverage. |
| Central bank | Set policy interest rate; supply/absorb bank liquidity; hold government bonds. | Economy-wide institution using a Taylor rule with inflation and growth terms. |
| Government | Purchase goods; collect taxes/contributions; distribute benefits, transfers, and subsidies; finance deficits with debt. | Government sector/entities. Government-consumption dynamics are externally estimated; whether individual government entities decide independently is not reported. |
| Foreign consumers/rest of world | Demand exports and supply imports. | External aggregate paths plus modeled foreign consumers; Austrian trade does not affect world prices. |

**Evidence:** pp. 6-9, §§3.1-3.5; pp. 11-12, Table 2 and §§4.1.3-4.1.5.

### II.ii.b Rationality, objectives, and success criteria

**[Explicit]** Agents satisfice through boundedly rational heuristics; the paper contrasts them with fully rational optimizers. Firms use expectations to plan sales, margins, inputs, production, employment, and prices under financial and physical constraints. Households use income shares for consumption and housing investment. Buyers attempt to exhaust budgets subject to aggregate supply. Banks restrict credit to satisfy minimum capital and maximum borrower-leverage conditions. The central bank follows a Taylor rule. No utility functions, profit-maximization problems, aspiration thresholds, or explicit individual success metrics are reported. Bounds arise from partial information, fundamental uncertainty, budgets, available stock, production inputs, cash flow, leverage, and bank capital. **Evidence:** pp. 2-3, §1; pp. 5-8, §§3-3.4; pp. 11-12, Table 2 and §4.1.4.

### II.ii.c Decision mechanism

**[Explicit]** Firms and households translate learned AR(1) forecasts of log output and producer-price inflation into expected real growth and inflation, which feed fixed behavioral heuristics. Firms then form demand, cost, margin, quantity, price, production, hiring, financing, and investment decisions. Household spending is governed by calibrated fractions of income and, in some rules, expectations. In goods matching, a seller's selection probability decreases with its price and increases with its size; the selected transaction is limited by buyer budget and seller stock. Bank lending uses capital and leverage thresholds, and the central bank's policy rate uses a generalized Taylor rule. The attached article does not contain the full equations, threshold order, or algorithms needed to reproduce these translations; it refers to Online Appendix A. **Evidence:** pp. 6-9, §§3.1-3.5; pp. 11-12, Table 2 and §§4.1.3-4.1.5.

### II.ii.d Adaptation

**[Explicit]** With fixed decision-rule forms, agents change choices when their inputs change. Examples include firms altering production and prices with expected growth/inflation, reducing production after unsold inventory, laying off or rehiring workers as production changes, and changing investment when capital wear or financing conditions change. Households change expenditure with expected net disposable income, employment, transfers, and expected inflation. Banks' feasible lending changes with capital losses and firm leverage. These are adaptation because inputs to existing rules change. Updating the AR(1) rule coefficients is learning and is treated separately in II.iii. **Evidence:** pp. 6-8, §§3.1 and 3.4; pp. 21-22, §§6.1-6.2.

### II.ii.e Social norms and cultural values

**[Not reported]** No trust, identity, convention, cultural value, or socially enforced norm is described as an input to individual decisions. Austrian tax, welfare, banking, and monetary rules are represented as formal institutions and calibrated parameters, not as social norms. The attached article does not establish whether any normative mechanisms appear in the full implementation. **Evidence:** p. 6, §3.1; pp. 11-12, §§4.1.3-4.1.4.

### II.ii.f Spatial aspects

**[Not reported]** No individual decision is described as depending on geographic position, distance, neighborhood, transport cost, or spatial accessibility. Decisions depend on industries, prices, sizes, budgets, and market matching. This does not prove that all spatial effects are absent from the complete model; they are not specified in the attached paper. **Evidence:** pp. 6-7, §§3.1-3.2; pp. 9-10, §§4.1-4.1.1.

### II.ii.g Temporal aspects

**[Explicit]** Decisions are quarterly and depend on lagged observations through AR(1) forecasting. Agents continuously re-estimate rule coefficients from observed history; forecast errors therefore affect later beliefs. Persistent stocks - capital, inventories, deposits, loans, equity, government debt, and prior wages - transmit outcomes across quarters. Firms repay 5% of outstanding debt each quarter; unemployment benefits depend on previous wages; current inventories affect next-period production; deficits raise future interest payments; and bankruptcies or layoffs can generate multi-period path dependence. The exact memory window, estimation gain, expectation timing within the data sample, and planning horizons other than the one-quarter forecasts are not reported. **Evidence:** pp. 6-8, §§3.1 and 3.3-3.5; pp. 11-12, Table 2 and §§4.1.3-4.1.4.

### II.ii.h Uncertainty

**[Explicit]** Firms face fundamental uncertainty about future sales, prices, input availability, input costs, cash flow, and financing conditions. Firms and households do not know the true nonlinear law of motion and make forecasts that need not be realized. Uncertainty enters through misspecified AR(1) beliefs, normally distributed shocks to output/inflation expectations and external processes, and randomized market ordering/matching. Credit and input constraints, market shortages, and possible default create further endogenous uncertainty. The paper does not report explicit risk preferences or utility-based attitudes toward risk. **Evidence:** pp. 5-8, §§3-3.4; pp. 8-9, §3.5.

## II.iii Learning

### II.iii.a Individual learning

**[Explicit]** Firms and households continuously update the two coefficients of each univariate AR(1) forecasting rule for log output and producer-price inflation. They learn rules consistent with the observed unconditional mean and first-order autocorrelation of each variable. The rule family remains fixed, but its estimated coefficients - the agents' internal predictive model - change through experience, so this is learning rather than mere adaptation. In the long run the process tends toward a Behavioral Learning Equilibrium: the perceived AR(1) mean and autocorrelation match those of the realized nonlinear process, even though conditional forecasts remain misspecified. The exact recursive estimator, gain, initial coefficient values, and whether every agent stores separate estimates are not reported in the attached article. **Evidence:** pp. 3 and 7-8, §1 and §§3.3-3.4.

### II.iii.b Collective learning

**[Not reported]** No imitation, communication-based learning, evolutionary selection of strategies, institutional learning, or group-level belief revision is described. Expectations are homogeneous and depend on aggregate realized variables, but the paper does not specify agents exchanging or pooling information, so this is insufficient to classify the process as collective learning. **Evidence:** p. 7, §3.3.

## II.iv Individual sensing

### II.iv.a Perceived variables

**[Explicit]** Firms and households use observed histories of aggregate log output and producer-price inflation to estimate forecasts and derive expected growth and inflation. Firms also use partial information about their own current condition and its history, including sales, prices, inputs, costs, cash flow, financing, inventory, and production constraints. Households use income/employment information and expected inflation in spending rules. Goods-market buyers use seller price and size in the matching probability; the bank uses its own capital and borrower leverage; the central bank uses inflation and growth in its rule. The macro forecasting rule is deliberately incomplete because it ignores cross-correlations and nonlinearities. The paper does not specify reporting delays, measurement error, exact observation sets for each rule, or whether observations other than forecasts are noisy. **Evidence:** pp. 6-9, §§3.1-3.5.

### II.iv.b Perception of other agents

**[Explicit]** A goods buyer's matching probability depends on a candidate firm's price and size, and the bank assesses a borrowing firm's leverage/default risk. Firms encounter applicants in the labor market. Beyond these facts, the paper does not specify what agents observe about counterparties, how candidate sets are formed, or whether counterparty information can be wrong. **Evidence:** pp. 6-7, §§3.1-3.2; p. 9, §3.5.

### II.iv.c Spatial scale of sensing

**[Not reported]** Forecast inputs are economy-wide aggregates, while transaction information is acquired in particular markets. No geographic sensing radius, neighborhood, network distance, or local-versus-global spatial rule is reported. **Evidence:** pp. 6-9, §§3.1-3.5.

### II.iv.d Information-acquisition mechanism

**[Explicit]** Agents are assumed to estimate AR(1) rules from observed macroeconomic histories. Market information is acquired through explicit randomized search and matching: buyers encounter sellers and firms encounter labor applicants. The paper does not report a separate search effort, messaging protocol, database, signal process, or observation algorithm for macro variables. **Evidence:** pp. 7-9, §§3.2-3.5.

### II.iv.e Information and cognition costs

**[Not reported]** No monetary cost, search time, attention budget, memory limit, or computational-capacity constraint is quantified for information acquisition or cognition. Bounded rationality is represented by a simple misspecified forecasting rule, not by an explicit cost function. Market frictions arise from matching, but the paper does not identify them as information costs. **Evidence:** pp. 5 and 7, §§3 and 3.2-3.3.

## II.v Individual prediction

### II.v.a Prediction data

**[Explicit]** Firms and households use current and past realizations of aggregate log output and producer-price inflation. The learned AR(1) rules are fitted to the variables' sample mean and first-order autocorrelation. Firms combine the resulting expected growth and inflation with their own current status and past development to anticipate sales, input costs, and profit margins. External forecasts for government consumption, trade, euro-area output, and euro-area inflation are generated by estimated AR(1) processes; realized external paths are supplied in the conditional variant. **Evidence:** pp. 3 and 6-8, §1 and §§3.1, 3.3-3.5; p. 12, §4.1.5; p. 16, §5.3.

### II.v.b Internal models

**[Explicit]** The internal predictive model is a homogeneous univariate AR(1) rule for each of two variables: log output and producer-price inflation. Agents re-estimate two coefficients per rule. These predictions yield expected real growth and expected inflation, which other fixed decision heuristics translate into actions. The AR(1) perceived law is the best univariate linear approximation targeted by BLE learning, not the true nonlinear conditional law. Full equations and estimation mechanics are deferred to Online Appendix A. **Evidence:** pp. 3 and 7-8, §1 and §§3.3-3.5.

### II.v.c Prediction error

**[Explicit]** Predictions can be wrong because the AR(1) rule ignores cross-correlations and nonlinearities, agents lack the true law of motion, and both beliefs and external processes receive random shocks. Agents learn from past forecast mistakes. At a BLE, forecast errors are described as unbiased and uncorrelated even though forecasts do not equal the true conditional expectation. The attached paper does not report the error-update equation or agent-specific bias/noise. **Evidence:** pp. 7-8, §§3.3-3.5.

## II.vi Interaction

### II.vi.a Interaction types

**[Explicit]** Direct interactions occur through credit matching between bank and firms, labor matching between firms and workers/applicants, and goods matching between firms and household, firm, government, or foreign customers. Firms are linked indirectly through input-output supply chains; households and firms through wages, consumption, ownership, and dividends; all domestic sectors through taxes, contributions, transfers, subsidies, and government purchases; firms and the bank through loan interest and defaults; the bank and central bank through reserves/advances; government and central bank through bonds; and Austria and the rest of world through imports and exports. Resource-mediated interactions propagate through inventories, capital, credit capacity, income, and aggregate demand. **Evidence:** pp. 3 and 6-9, §1 and §§3.1-3.5; p. 20, §5.5.

### II.vi.b Conditions for interaction

**[Explicit]** Market interaction occurs in the quarterly schedule when an agent demands credit, labor, or a product and a counterparty is available. Agents are randomly ordered. In the goods market, seller-selection probability rises with seller size and falls with price; transaction quantity is bounded by customer budget and seller supply. Credit is bounded by bank capital requirements and borrower leverage. Labor-market firms select applicants after random reshuffling, but detailed eligibility and selection conditions are not reported. Product compatibility is structured by industry-specific goods and input-output coefficients. **Evidence:** pp. 6-9, §§3.1-3.5.

### II.vi.c Communication

**[Not reported]** No explicit message, negotiation, advertising, social communication, or inter-agent information exchange is specified. Prices, firm size, loan applications, and applicant encounters must be available for reported transactions, but their communication representation, timing, and possible error are not described. **Evidence:** pp. 7-9, §§3.2-3.5.

### II.vi.d Coordination and networks

**[Explicit]** Coordination is predominantly decentralized through random search and matching rather than a central market-clearing mechanism. The central bank and government are centralized institutions for monetary and fiscal flows, respectively. Industry and supply-chain structure is imposed initially from NACE/CPA and input-output tables. Transaction matches emerge during each market process, but the paper does not report persistent buyer-seller, credit, ownership, or social networks beyond one investor owner per firm. **Evidence:** pp. 3 and 5-9, §1 and §§3-3.5.

## II.vii Collectives

### II.vii.a Membership and formation

**[Explicit]** Agents are assigned to ESA institutional sectors, firms to NACE/CPA industries, and households to employed, unemployed, investor, or inactive categories. Employed households have sector-specific characteristics. These collectives are imposed from statistical classifications and calibrated population counts, not reported as emergent groups. Firms may move between employment outcomes or be replaced after bankruptcy, but the paper does not describe endogenous creation, dissolution, or membership-change rules for collectives. **Evidence:** pp. 5-6, §§3-3.1; pp. 9-11, §§4.1-4.1.2 and Table 2.

### II.vii.b Representation

**[Explicit]** Institutional sectors and industries aggregate agent balance sheets, flows, output, employment, and value added under ESA rules. Industries carry distinct Leontief technologies, wages, productivity, taxes, and input-output relationships; household classes carry distinct income sources and labor-market roles. Government and financial sectors have sector-specific rules and accounts. The attached paper does not report the software classes, containers, or aggregation algorithms that implement these collectives. **Evidence:** pp. 6 and 9-12, §3.1 and §§4.1-4.1.5; pp. 19-20, §§5.4-5.5.

## II.viii Heterogeneity

### II.viii.a General heterogeneity

**[Explicit]** Firms differ by industry-specific production function, input mix, productivity, wage, taxes, capital/depreciation parameters, and size; firm sizes follow a power-law distribution calibrated to Austria. Households differ by employment/inactivity/investor status, sector-specific employment characteristics, income source, previous wage, ownership, and current financial state. Government, bank, central bank, and foreign agents have distinct institutional roles. Heterogeneity in current balance-sheet states and realized market outcomes is also possible. **Evidence:** pp. 3 and 5-6, §1 and §§3-3.1; pp. 10-12, §§4.1.1-4.1.4 and Table 2.

### II.viii.b Decision-making heterogeneity

**[Explicit]** Decision objects and constraints differ by role: firms price, produce, hire, borrow, invest, and sell; households work and spend; investors receive dividends; the bank lends under capital/leverage constraints; the central bank sets policy; and government taxes, transfers, borrows, and purchases. Household classes have different income-generation rules, and industries give firms different technologies and constraints. In contrast, firms and households form output and inflation expectations homogeneously with the same AR(1) rule class, and annual average tax rates are applied uniformly to relevant agents. Agent-specific objectives, risk preferences, or alternative forecasting strategies are not reported. **Evidence:** pp. 6-7, §§3.1 and 3.3; pp. 11-12, §§4.1.3-4.1.4 and Table 2.

## II.ix Stochasticity

### II.ix.a Random processes

**[Explicit]** The model draws normally distributed shocks to agents' AR(1) expectations of log output and producer-price inflation and to external AR(1) processes for exports, imports, government expenditure, euro-area growth, and euro-area inflation. Uniform draws reshuffle agents before credit/labor and goods-market matching. Goods sellers are sampled randomly from an empirical cumulative distribution weighted positively by size and negatively by price. These processes generate alternative Monte Carlo trajectories and trade frictions; 500 runs are averaged per forecast/scenario. Random initialization of the power-law firm-size distribution, random seeds, generator, stream handling, cross-shock covariance implementation, and reproducibility controls are not reported. **Evidence:** pp. 4 and 8-9, §1 and §§3.4-3.5; p. 11, Table 2; pp. 13-22, §§5-6.

## II.x Observation

### II.x.a Recorded outputs

**[Explicit]** Outputs include quarterly and annual real GDP, GDP growth, GDP-deflator inflation, household consumption, fixed investment, government consumption, exports, imports, the Euribor/policy-rate outcome, unemployment, government debt, sectoral output and gross value added, and GDP components under production, income, and expenditure approaches. The stock-flow-consistent accounts also permit reporting wages, operating surplus, taxes, subsidies, intermediate inputs, employment, productivity, and every agent's economic activity. For validation, 500-run mean forecasts are evaluated at 1-, 2-, 4-, 8-, and 12-quarter horizons using RMSE, modified Diebold-Mariano tests, mean forecast bias, and Mincer-Zarnowitz tests; graphical forecasts show 90% intervals. A 400/600-run sensitivity check found nearly identical Table 3 results. COVID-19 outputs are differences from a baseline, displayed with one standard deviation, and are compared with later realized GDP and institutional forecasts. **Evidence:** pp. 9 and 13-20, §3.5 and §§5-5.5, Tables 3-7 and Figs. 1-4; pp. 21-23, §6, Figs. 5-6 and footnote 40.

### II.x.b Emergence

**[Explicit]** GDP and its market value emerge from individual production and trading and can be reconciled through expenditure and income accounts. Trend growth, business-cycle fluctuations, unemployment, inventories, defaults, credit restrictions, and sectoral distributions arise from agents' beliefs, heuristics, constraints, and matches. Endogenous bankruptcy cascades can transmit losses through supply chains, layoffs, household demand, and bank capital, creating multiplier effects, path dependence, and hysteresis. Near-unit-root learning can place the economy near self-fulfilling growth paths and tends toward a BLE. These endogenous outcomes are distinct from imposed external trade/government/euro-area shocks and COVID-19 scenario assumptions. **Evidence:** pp. 3 and 7-8, §1 and §§3.3-3.4; pp. 20-23, §§5.5-7.

# III. Details

## III.i Implementation details

### III.i.a Implementation

**[Not reported]** For the ABM, the attached article does not state the programming language, modeling platform, software architecture, libraries, numerical precision, random-number generator, seeds, parallelization method, or runtime. It states that the discrete-time model is solved numerically and sequentially, behavioral rule by behavioral rule and transaction by transaction; forecasts use 500 Monte Carlo simulations; and reported computational results used the Vienna Scientific Cluster. Normal and uniform random draws are identified, but their implementation is not. Dynare is mentioned only for the benchmark DSGE model, not for the ABM. **Evidence:** p. 5, §2; pp. 8-9, §3.5; p. 15, footnote 35; p. 24, Acknowledgements.

### III.i.b Accessibility

**[Explicit]** The paper says that a detailed model description and documentation of replication codes are in the Online Appendix and gives a supplementary-material link: `https://doi.org/10.5281/zenodo.7271552`. The attached article does not itself identify a source-code repository, license, executable, software version, or exact file inventory. Because the Online Appendix/supplement was not attached, its contents are outside this extraction. **Evidence:** p. 2, §1; p. 24, Supplementary material.

## III.ii Initialization

### III.ii.a Initial state

**[Explicit]** Each run starts from a reference-quarter calibration intended to reproduce exactly that quarter's aggregate GDP, GDP components, industry sizes, balance sheets, and economic flows. The initial population is at 1:1 scale: natural and legal persons/entities correspond to Austria. Firms are allocated by industry from business demography and sized to follow an Austrian-like power law; households are allocated among active/inactive and employment/investor categories from census/business data; one investor owns each firm; government and foreign-consumer counts use stated proportional assumptions. Industry technologies, consumption and investment shares, tax/benefit/financial parameters, balance sheets, and flows are calibrated from the sources in §4. The attached paper does not report the complete initial state of every agent, matching relationships, learned AR coefficients, inventories, capital, deposits, loans, government debt allocation, or bank/central-bank balance sheets. **Evidence:** pp. 4 and 6, §1 and §3.1; pp. 8-12, §3.5 and §§4.1-4.1.5.

### III.ii.b Variation among runs

**[Explicit]** Forecast experiments use 39 distinct calibrated reference-quarter initial states from 2010:Q1 through 2019:Q3. Within a given reference-quarter forecast, the same calibrated model is run 500 times while shocks, agent ordering, and matches vary stochastically; this common-initial-state interpretation is strongly implied but not stated in an explicit seed protocol. Annual inputs change by calendar year, while external-process and Taylor-rule coefficients are re-estimated for each expanding reference-quarter sample. Statutory/regulatory parameters are fixed across calibration quarters. Conditional forecasts replace three external paths, and the COVID-19 experiment changes shocks and policy assumptions. **Evidence:** pp. 8-13, §3.5 and §§4.1-5.1; p. 16, §5.3; p. 21, §6.

### III.ii.c Basis for initial values

**[Explicit]** Initial values come primarily from Austrian empirical statistics and accounting identities: census, business demography, input-output/fixed-asset tables, national and sector accounts, government statistics, and money-market rates. Some values come from statutes/regulation, banking practice, and literature. Two population values are explicit simplifying assumptions: foreign consumers equal 50% of domestic producing firms and government entities equal 25% of domestic producing firms. The COVID-19 initial scenario uses AMS data and Oxford Economics projections, including the assumption that about 65% of companies use short-time work. **Evidence:** pp. 9-12, §§4.1-4.1.5 and Tables 1-2; p. 21, §6.

## III.iii Input data

### III.iii.a External dynamic inputs

**[Explicit]** In baseline forecasts, the dynamic external series are generated inside the run by estimated AR(1) processes for real Austrian government consumption, exports, and imports and for euro-area real GDP and GDP-deflator inflation; the processes are shocked stochastically. Their parameters are estimated from quarterly national accounts and money-market data from 1997:Q1 to the current reference quarter. In conditional forecasts, realized paths of real exports, real imports, and real government consumption are supplied directly. In the COVID-19 version, sectoral March 2020 unemployment inflows from AMS and Oxford Economics import/export scenarios parameterize time-varying lockdown/trade shocks and short-time work. No filenames, file formats, data-loading procedures, missing-data treatment, revision-vintage handling, or exact quarterly scenario vectors are provided. **Evidence:** pp. 11-12, Table 2 and §4.1.5; p. 13, §5.1 and footnote 30; p. 16, §5.3; p. 21, §6.

## III.iv Submodels

### III.iv.a Process specification

**[Explicit]** The main article specifies the submodels only to the following level:

1. **Expectation formation and learning.** Firms and households forecast log output and producer-price inflation with separate univariate AR(1) rules. Two coefficients per rule are continuously re-estimated to match the realized mean and first-order autocorrelation. Forecasts imply expected growth and inflation; normal shocks perturb expectations. Exact equations, gain, sample window, and initialization are not reported.
2. **Firm planning and production.** Each firm uses a fixed-coefficient Leontief technology combining labor, capital, and industry-specific intermediate inputs. Expected growth/inflation feed expected demand, costs, margin, price, quantity, hiring, and financing heuristics. Investment replaces expected capital wear. Actual production follows credit/labor matching and precedes goods matching. Complete equations and rationing order are not reported.
3. **Household income and expenditure.** Employed households earn sector wages, unemployed households receive a fraction of previous wages, investors receive firm dividends, and inactive households receive government benefits; all receive equal additional transfers. Consumption and dwelling investment use calibrated income fractions and some expectation-dependent rules. Budget, wealth, and purchase equations are not reported.
4. **Government.** Government collects taxes and social contributions, pays benefits/transfers/subsidies/interest, purchases goods, and accumulates debt when in deficit. Government consumption follows an external AR(1) process. The allocation across `J` government entities is not specified.
5. **Banking and credit.** The bank accepts deposits and lends to firms at a fixed markup over the policy rate. Lending is constrained by minimum bank capital and maximum firm leverage/LTV. Profit equals loan interest minus deposit interest and default write-offs. The application, allocation, pricing, repayment, and default-recovery algorithms are incomplete.
6. **Monetary policy.** The central bank applies a generalized Taylor rule with smoothing, equilibrium-rate, inflation-target, inflation-weight, and growth-weight parameters; it provides advances, accepts reserves, and holds government bonds. The exact equation is deferred to Online Appendix A.5.1.
7. **Credit and labor matching.** Agents are uniformly reshuffled; the paper's example has firms choose applicants in random order. Candidate sets, wage adjustment, acceptance, and repeated-search logic are not reported.
8. **Goods matching.** Demanders are reshuffled. A firm is drawn from an empirical cumulative distribution with weight increasing in size and decreasing in price. Purchase quantity is limited by demander's budget and seller stock. Matching can leave excess demand or unsold inventories; exact weights and repeat-visit termination are not reported.
9. **Trade/rest of world.** Exports, imports, euro-area output, and euro-area inflation follow estimated external AR(1) processes. Austria is too small to change world prices. Product allocation and domestic importer/exporter algorithms are not reported.
10. **Bankruptcy and propagation.** A firm with negative equity goes bankrupt; debt write-offs reduce bank capital and may restrict later credit. Supplier income, worker employment, household demand, investment, and further bankruptcies transmit the event. Table 2 includes a 0.5 loan-to-capital ratio for a replacement firm, but entry/replacement timing is not given.
11. **Accounting and aggregation.** After markets, remaining stocks and flows are updated using separate balance sheets and double-entry bookkeeping. GDP is calculated consistently by production, income, and expenditure approaches. Complete identities are deferred to Online Appendix A.7.
12. **Conditional forecasting.** Observed future paths replace simulated exports, imports, and government consumption. No further ABM algorithm is given in the attached article.
13. **COVID-19 scenario.** The baseline is modified by sectoral domestic supply restrictions, export-demand and import-supply shocks, and government-reimbursed short-time work paying employees up to 90% of prior net remuneration. Shock equations, sectoral paths, and policy accounting are deferred to Online Appendix C.

The process descriptions are sufficient to understand causal structure but not to reimplement the model faithfully. **Evidence:** pp. 6-12, §§3.1-4.1.5; p. 16, §5.3; pp. 20-23, §§5.5-6.2.

### III.iv.b Parameters

**[Explicit]** The table below transcribes the parameters reported in Table 2 for reference quarter 2010:Q4 and adds variation information stated in §4. Blank numerical entries in the source are recorded as “Online Appendix D/not reported.” “Not reported” under range means the article supplies no admissible bound; it does not mean the parameter cannot vary across calibrations. The paper calls all Table 2 entries parameters, although learned AR(1) coefficients for agents' two expectation variables are not included in that table.

| Parameter | Meaning | Entity or submodel | Units/dimensions | Reference/default value | Allowed range or variation | Source |
|---|---|---|---|---|---|---|
| `G / S` | Number of products / industries | Industry/product structure | Count | 62 | Categories T and U excluded; fixed within run | Census/business demography grouping; p. 10; Table 2, p. 11 |
| `H^act` | Economically active persons | Households/labor | Persons | 4,729,215 | Census/business data; reference-year updates not fully stated | Census/business demography; Table 2, p. 11 |
| `H^inact` | Economically inactive persons | Households | Persons | 4,130,385 | Constant across reference quarters because census is decennial | Census; §4.1.1, p. 9; Table 2, p. 11 |
| `J` | Government entities | Government | Entities | 152,820 | Assumed 25% of domestic producing firms | Simplifying assumption; §4.1.1, p. 10; Table 2, p. 11 |
| `L` | Foreign consumers | Rest of world | Agents | 305,639 | Assumed 50% of domestic producing firms | Simplifying assumption; §4.1.1, p. 10; Table 2, p. 11 |
| `I_s` | Firms/investors in industry `s` | Firms/investors | Agents | Online Appendix D/not reported | Annual industry-specific calibration | Business demography; pp. 10-11 |
| `alpha_bar_i` | Average labor productivity of firm `i` | Production | Output per employed person (currency/volume basis not reported) | Firm/sector-specific; value not reported | Equal within an industry, different across industries; annual calibration | Input-output, business-demography, cross-classification data; pp. 10-11 |
| `kappa_i` | Capital productivity of firm `i` | Production | Not reported | Firm/sector-specific; value not reported | Annual industry/firm-specific calibration | Input-output/fixed-assets tables; pp. 10-11 |
| `beta_i` | Intermediate-consumption productivity of firm `i` | Production | Not reported | Firm/sector-specific; value not reported | Annual industry/firm-specific calibration | Input-output tables; pp. 10-11 |
| `delta_i` | Capital depreciation rate of firm `i` | Production/investment | Rate; period basis not separately reported | Firm/sector-specific; value not reported | Annual industry/firm-specific calibration | Fixed-assets tables; pp. 10-11 |
| `w_bar_i` | Average wage rate of firm `i` | Firm/labor | Currency per period; exact basis not reported | Firm/sector-specific; value not reported | Annual industry/firm-specific calibration | Input-output and cross-classification data; pp. 10-11 |
| `a_sg` | Input of product `g` in industry `s` | Leontief production | Normalized coefficient | Online Appendix D/not reported | Industry-product-specific; annual calibration | Input-output tables; pp. 10-11 |
| `b_g^CF` | Product-`g` capital-formation coefficient | Firm investment | Share/coefficient; exact dimension not reported | Online Appendix D/not reported | Product-specific; annual calibration | Input-output tables; pp. 10-11 |
| `b_g^CFH` | Product-`g` household-investment coefficient | Housing investment | Share/coefficient; exact dimension not reported | Online Appendix D/not reported | Product-specific; annual calibration | Input-output tables; pp. 10-11 |
| `b_g^HH` | Product-`g` household-consumption coefficient | Household consumption | Share/coefficient; exact dimension not reported | Online Appendix D/not reported | Product-specific; annual calibration | Input-output tables; pp. 10-11 |
| `c_g^G` | Government consumption of product `g` | Government/goods | Million euro | Online Appendix D/not reported | Product-specific; annual calibration | Input-output tables; pp. 10-11 |
| `c_g^E` | Exports of product `g` | Trade/goods | Million euro | Online Appendix D/not reported | Product-specific; annual calibration | Input-output tables; pp. 10-11 |
| `c_g^I` | Imports of product `g` | Trade/goods | Million euro | Online Appendix D/not reported | Product-specific; annual calibration | Input-output tables; pp. 10-11 |
| `tau_i^Y` | Net tax rate on firm `i` products | Firm/government | Rate | Firm/sector-specific; value not reported | Annual calibration; no admissible range reported | Input-output tables; pp. 10-11 |
| `tau_i^K` | Net tax rate on firm `i` production | Firm/government | Rate | Firm/sector-specific; value not reported | Annual calibration; no admissible range reported | Input-output tables; pp. 10-11 |
| `tau^INC` | Income tax rate | Household/government | Rate | 0.2134 | Annual average recalibrated by calendar year/reference quarter; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `tau^FIRM` | Corporate tax rate | Firm/government | Rate | 0.0762 | Annual average recalibrated; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `tau^VAT` | Value-added tax rate | Goods/government | Rate | 0.1529 | Annual average recalibrated; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `tau^SIF` | Employer social-insurance rate | Firm/government | Rate | 0.2122 | Annual average recalibrated; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `tau^SIW` | Employee social-insurance rate | Household/government | Rate | 0.1711 | Annual average recalibrated; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `tau^EXPORT` | Export tax rate | Trade/government | Rate | 0.0029 | Annual average recalibrated; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `tau^CF` | Capital-formation tax rate | Investment/government | Rate | 0.0876 | Annual average recalibrated; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `tau^G` | Government-consumption tax rate | Government/goods | Rate | 0.0091 | Annual average recalibrated; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `r^G` | Interest rate on government bonds | Government/central bank | Rate per quarter implied by calibration text | 0.0091 | Recalibrated from quarterly government data; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `mu` | Risk premium on policy rate | Bank credit | Rate | 0.0293 | Recalibrated from sector accounts and Euribor; no range reported | Government statistics/sector accounts; pp. 11-12 |
| `psi` | Income fraction devoted to consumption | Households | Fraction | 0.9394 | Annual calibration; no range reported | Input-output/government/sector accounts; pp. 11-12 |
| `psi^H` | Income fraction devoted to housing investment | Households | Fraction | 0.0736 | Annual calibration; no range reported | Input-output/government/sector accounts; pp. 11-12 |
| `theta^DIV` | Dividend payout ratio | Firms/investors | Fraction | 0.7768 | Annual calibration; no range reported | Input-output/sector accounts; pp. 11-12 |
| `theta^UB` | Unemployment-benefit replacement rate | Households/government | Fraction of gross prior income | 0.3586 | Fixed across reference quarters; formula `0.55(1-tau^INC)(1-tau^SIW)` | Statutory rule; p. 12 |
| `theta` | Debt-instalment rate | Firms/bank | Fraction of outstanding debt per quarter | 0.05 | Fixed across reference quarters | Banking practice; p. 12 |
| `zeta` | Bank capital ratio | Bank | Ratio | 0.03 | Fixed across reference quarters; no range reported | Basel III/regulation; p. 12 |
| `zeta^LTV` | Maximum loan-to-value ratio | Bank/firm credit | Ratio | 0.6 | Fixed across reference quarters | Banking practice; p. 12 |
| `zeta^b` | Loan-to-capital ratio for a replacement firm | Firm entry/bank | Ratio | 0.5 | Fixed across reference quarters | Banking practice/model assumption; p. 12 |
| `pi*` | Monetary authority inflation target | Central bank | Rate per quarter implied by 0.005 and quarterly model; exact transformation not stated | 0.005 | Fixed across reference quarters; described as ECB 2% target | ECB statute; p. 12 |
| `alpha^G` | AR coefficient, government consumption | External government-demand process | Dimensionless | 0.9845 | Re-estimated for each reference quarter using expanding sample | National accounts; pp. 11-12 |
| `beta^G` | Scalar constant, government consumption | External government-demand process | Not reported | 0.1515 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `sigma^G` | Standard deviation, government consumption | External government-demand process | Model-transformation units not reported | 0.0112 | Re-estimation/variation not separately stated | National accounts; Table 2, p. 11 |
| `alpha^E` | AR coefficient, exports | External export-demand process | Dimensionless | 0.9693 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `beta^E` | Scalar constant, exports | External export-demand process | Not reported | 0.3261 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `alpha^I` | AR coefficient, imports | External import-supply process | Dimensionless | 0.974 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `beta^I` | Scalar constant, imports | External import-supply process | Not reported | 0.2762 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `alpha_Y^EA` | AR coefficient, euro-area GDP | External euro-area process | Dimensionless | 0.9673 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `beta_Y^EA` | Scalar constant, euro-area GDP | External euro-area process | Not reported | 0.4817 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `alpha_pi^EA` | AR coefficient, euro-area inflation | External euro-area process | Dimensionless | 0.3834 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `beta_pi^EA` | Scalar constant, euro-area inflation | External euro-area process | Not reported | 0.0026 | Re-estimated by reference quarter | National accounts; pp. 11-12 |
| `sigma_pi^EA` | Standard deviation, euro-area inflation | External euro-area process | Inflation-transformation units not reported | 0.0025 | Re-estimation/variation not separately stated | National accounts; Table 2, p. 11 |
| `rho` | Policy-rate adjustment coefficient | Taylor rule | Dimensionless | 0.9263 | Re-estimated by reference quarter | Money-market rates/national accounts; pp. 11-12 |
| `r*` | Real equilibrium interest rate | Taylor rule | Rate; period basis not separately reported | -0.0034 | Re-estimated by reference quarter | Money-market rates/national accounts; pp. 11-12 |
| `xi_pi` | Weight on inflation target | Taylor rule | Coefficient | 0.3214 | Re-estimated by reference quarter | Money-market rates/national accounts; pp. 11-12 |
| `xi_gamma` | Weight on economic growth | Taylor rule | Coefficient | 1.2994 | Re-estimated by reference quarter | Money-market rates/national accounts; pp. 11-12 |
| `C` | Covariance matrix of euro-area GDP, imports, and exports | Correlated external shocks | Covariance matrix; dimensions/units not reported | Value not reported | Re-estimation/variation not separately stated | National accounts; Table 2, p. 11 |

**Evidence:** pp. 9-12, §§4.1-4.1.5 and Tables 1-2.

### III.iv.c Design, parameterization, and testing

**[Explicit]** Production was selected as Leontief because it is consistent with input-output data and established ABM literature. BLE learning was selected as a parsimonious, empirically relevant answer to unconstrained bounded rationality; the AR(1) class uses observable means and autocorrelations. Market search/matching was selected to represent decentralized institutions, rationing, and trade frictions. National-accounting structure was selected to anchor the model in observed entities and flows and permit stock-flow-consistent aggregation.

Parameters are (a) taken directly from census/business and input-output data, (b) calculated from national-accounting identities to reproduce observed flows, (c) estimated as AR(1)/Taylor-rule coefficients from expanding quarterly samples, (d) fixed from statutes, regulation, banking practice, or literature, or (e) explicitly assumed for foreign-consumer and government-entity counts. Each calibration reproduces its reference-quarter aggregate state.

Testing/evaluation is empirical rather than unit-level in the article. The authors compare rolling out-of-sample forecasts against VAR, VECM, AR, and DSGE models using RMSE, modified Diebold-Mariano tests, bias, and Mincer-Zarnowitz tests at five horizons. They test sectoral gross value added, conditional forecasts, and accounting-consistent GDP decompositions. Repeating a key exercise with 400 and 600 rather than 500 Monte Carlo simulations produces nearly identical results. The COVID-19 projection is compared retrospectively with realized 2020 GDP and institutional 2021 forecasts. The article reports no submodel unit tests, conservation-test tolerances, parameter-identification analysis, global sensitivity analysis, or validation of individual decision rules against held-out microdata. **Evidence:** pp. 2-3 and 5-7, §§1-3.3; pp. 9-13, §§4-5; pp. 13-23, §§5-7, Tables 3-7, Figs. 1-6, and footnotes 33 and 40.

# Critical documentation gaps

## 1. Reimplementation of the model

- The exact equations and update algorithms for expectation learning, firm demand/price/production/investment, household budgets, bank lending, labor matching, goods matching, entry/replacement, government allocation, trade, and accounting are absent; the article delegates them to unattached Online Appendices A and D.
- Complete entity state schemas, balance-sheet identities, stock-flow timing, transaction settlement, rationing/termination rules, and within-market update semantics are not given.
- Seller-weight formulas, applicant/credit candidate formation, bankruptcy replacement timing, learned-AR initialization/gain, shock equations, covariance values, and many industry/product parameter values are missing.
- The article does not reconcile its overview statement of 64 industries with the calibrated `S = G = 62`, although the latter is explained by excluding NACE/CPA T and U.
- ABM language, software version, architecture, numerical precision, dependencies, parallelization, and random-number implementation are not reported in the attached paper.

## 2. Reproduction of the simulation experiments

- Random seeds, generator/stream policy, complete shock distributions and covariance matrix, initialization draws, and Monte Carlo execution details are missing.
- Exact reference-quarter calibration files, data vintages, transformations, deflators, seasonal adjustments, revision handling, and preprocessing code are not in the attached paper.
- The conditional export/import/government paths and the COVID-19 quarterly sectoral shock and short-time-work vectors are not reported; implementation is delegated to unattached Online Appendices B and C.
- Hardware is named only as the Vienna Scientific Cluster; node configuration, runtime, resource use, and replication commands are absent.
- The supplementary-material DOI is provided, but the attached paper does not enumerate versions, checksums, software requirements, or an executable workflow.

## 3. Evaluation of human decision-making assumptions

- The complete individual heuristics and their empirical estimation/calibration targets are absent, so their behavioral content cannot be independently assessed.
- The paper does not report household- or firm-level validation of choice rules, alternative heuristics, heterogeneous expectations, sensitivity of outcomes to behavioral parameters, or identification uncertainty.
- Information sets, observation errors/delays, cognitive or search costs, risk preferences, aspiration criteria, and social/cultural mechanisms are not specified.
- It is unclear whether homogeneous expectations mean shared coefficients or separately estimated but identical-form rules, and the learning gain, memory window, and response to forecast error are missing.
- Applying sector-level average taxes and spending propensities uniformly to individuals is documented, but the behavioral consequences of this aggregation mismatch are not tested in the attached article.
