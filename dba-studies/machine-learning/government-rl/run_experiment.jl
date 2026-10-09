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
        debt_fraction =
        (model.gov.L_G - initial_conditions["L_G"]) /
        (4 * first(model.data.nominal_gdp)),
    )
end

seeds = 1:10
baseline = [evaluate(fixed_policy(0.0, 0.0, 1.0), seed) for seed in seeds]

results = NamedTuple[]

for tax_change in (-0.01, 0.0, 0.01),
    benefit_change in (-0.01, 0.0, 0.01),
    spending_multiplier in (0.95, 1.0, 1.05)

    trials = [
        evaluate(fixed_policy(tax_change, benefit_change, spending_multiplier), seed)
        for seed in seeds
    ]
    pairs = collect(zip(baseline, trials))

    push!(results, (
        tax_change = tax_change,
        benefit_change = benefit_change,
        spending_multiplier = spending_multiplier,
        delta_reward = mean(t.reward - b.reward for (b, t) in pairs),
        delta_unemployment = mean(t.unemployment - b.unemployment for (b, t) in pairs),
        delta_debt = mean(t.debt - b.debt for (b, t) in pairs),
        delta_debt_fraction = mean(t.debt_fraction - b.debt_fraction for (b, t) in pairs),
    ))
end

for lambda_d in reward_config.lambda_d_candidates
    ranked = sort(
        results;
        by = r -> r.delta_reward - lambda_d * r.delta_debt_fraction,
        rev = true,
    )

    println("\nλ_D = ", lambda_d)
    for r in ranked[1:3]
        println((
            tax_change = r.tax_change,
            benefit_change = r.benefit_change,
            spending_multiplier = r.spending_multiplier,
            delta_score = r.delta_reward - lambda_d * r.delta_debt_fraction,
            delta_unemployment = r.delta_unemployment,
            delta_debt = r.delta_debt,
        ))
    end
end

selected = Set{Tuple{Float64, Float64, Float64}}()
for lambda_d in reward_config.lambda_d_candidates
    ranked = sort(results;
        by = r -> r.delta_reward - lambda_d * r.delta_debt_fraction,
        rev = true,
    )
    for r in ranked[1:3]
        push!(selected, (r.tax_change, r.benefit_change, r.spending_multiplier))
    end
end

validation_seeds = 11:30
validation_baseline = [
    evaluate(fixed_policy(0.0, 0.0, 1.0), seed)
    for seed in validation_seeds
]

for (tax_change, benefit_change, spending_multiplier) in sort!(collect(selected))
    trials = [
        evaluate(fixed_policy(tax_change, benefit_change, spending_multiplier), seed)
        for seed in validation_seeds
    ]
    pairs = collect(zip(validation_baseline, trials))

    println("\nPolicy: ", (tax_change, benefit_change, spending_multiplier))
    println("  mean Δunemployment = ",
        mean(t.unemployment - b.unemployment for (b, t) in pairs),
        ", mean Δdebt = ",
        mean(t.debt - b.debt for (b, t) in pairs),
    )

    for lambda_d in reward_config.lambda_d_candidates
        diffs = [
            t.reward - b.reward -
            lambda_d * (t.debt_fraction - b.debt_fraction)
            for (b, t) in pairs
        ]
        println("  λ_D=", lambda_d,
            ": mean Δscore=", mean(diffs),
            ", SE=", std(diffs) / sqrt(length(diffs)),
        )
    end
end

starting_model = Bit.Model(deepcopy(parameters), deepcopy(initial_conditions))
u_trigger = count(iszero, starting_model.w_act.O_h) /
            length(starting_model.w_act.O_h)

feedback_policy(obs, _) = (
    tax_rate = parameters["tau_INC"] - 0.01,
    benefit_rate = parameters["theta_UB"],
    log_spending_multiplier =
        obs.unemployment_rate >= u_trigger ? log(1.05) : 0.0,
)

comparison_seeds = 31:50
fixed_on = [
    evaluate(fixed_policy(-0.01, 0.0, 1.05), seed)
    for seed in comparison_seeds
]
fixed_off = [
    evaluate(fixed_policy(-0.01, 0.0, 1.0), seed)
    for seed in comparison_seeds
]
feedback = [evaluate(feedback_policy, seed) for seed in comparison_seeds]

for (name, fixed) in (("always +5%", fixed_on), ("never +5%", fixed_off))
    pairs = collect(zip(fixed, feedback))
    println("\nFeedback minus ", name,
        ": mean Δunemployment=",
        mean(f.unemployment - b.unemployment for (b, f) in pairs),
        ", mean Δdebt=",
        mean(f.debt - b.debt for (b, f) in pairs),
    )

    for lambda_d in reward_config.lambda_d_candidates
        diffs = [
            f.reward - b.reward -
            lambda_d * (f.debt_fraction - b.debt_fraction)
            for (b, f) in pairs
        ]
        println("  λ_D=", lambda_d,
            ": mean Δscore=", mean(diffs),
            ", SE=", std(diffs) / sqrt(length(diffs)),
        )
    end
end