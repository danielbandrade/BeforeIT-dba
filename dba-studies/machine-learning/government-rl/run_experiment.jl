using TOML
import BeforeIT as Bit
using Statistics

include("government_policy.jl")
using .GovernmentPolicy

settings = TOML.parsefile(joinpath(@__DIR__, "experiment.toml"))["reward"]
reward_config = (; (Symbol(k) => v for (k, v) in settings)...)

no_op(obs, _) = (
    tax_rate = obs.tax_rate,
    benefit_rate = obs.benefit_rate,
    log_spending_multiplier = 0.0,
)

_, rows = run_episode(
    no_op,
    Bit.AUSTRIA2010Q1.parameters,
    Bit.AUSTRIA2010Q1.initial_conditions;
    reward_config,
)

println("Total reward: ", sum(row.reward for row in rows))

parameters = Bit.AUSTRIA2010Q1.parameters
initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions

fixed_policy(tax_change, benefit_change, spending_multiplier) =
    (obs, rng) -> (
        tax_rate = parameters["tau_INC"] + tax_change,
        benefit_rate = parameters["theta_UB"] + benefit_change,
        log_spending_multiplier = log(spending_multiplier),
    )

function evaluate(policy, seed)
    model, rows = run_episode(
        policy, parameters, initial_conditions;
        seed, reward_config,
    )
    return (
        reward = sum(row.reward for row in rows),
        unemployment = mean(row.unemployment_rate for row in rows),
        debt = model.gov.L_G,
        debt_ratio = last(rows).debt_to_gdp,
    )
end

seeds = 1:10
baseline = [evaluate(fixed_policy(0.0, 0.0, 1.0), seed) for seed in seeds]

for (name, tax_change, benefit_change, spending_multiplier) in (
    ("tax +1 pp", 0.01, 0.0, 1.0),
    ("benefit +1 pp", 0.0, 0.01, 1.0),
    ("spending +5%", 0.0, 0.0, 1.05),
)
    trials = [
        evaluate(fixed_policy(tax_change, benefit_change, spending_multiplier), seed)
        for seed in seeds
    ]
    pairs = collect(zip(baseline, trials))
    reward_diffs = [trial.reward - base.reward for (base, trial) in pairs]

    println(name,
        ": mean Δreward=", mean(reward_diffs),
        ", range=", extrema(reward_diffs),
        ", mean Δunemployment=",
        mean(trial.unemployment - base.unemployment for (base, trial) in pairs),
        ", mean Δdebt=",
        mean(trial.debt - base.debt for (base, trial) in pairs),
        ", mean Δdebt/GDP=",
        mean(trial.debt_ratio - base.debt_ratio for (base, trial) in pairs),
    )
end