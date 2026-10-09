using TOML, Statistics
import BeforeIT as Bit

include("government_policy.jl")
using .GovernmentPolicy: run_episode

function main(lambda_d)
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    settings = TOML.parsefile(joinpath(@__DIR__, "experiment.toml"))["reward"]
    reward_config = (; (Symbol(k) => v for (k, v) in settings)...)

    lambda_d in reward_config.lambda_d_candidates ||
        error("Choose a lambda_d from experiment.toml")

    feedback_policy(threshold) = (obs, _) -> (
        tax_rate = parameters["tau_INC"] - 0.01,
        benefit_rate = parameters["theta_UB"],
        log_spending_multiplier =
            obs.unemployment_rate >= threshold ? log(1.05) : 0.0,
    )

    fixed_policy(multiplier) = (obs, _) -> (
        tax_rate = parameters["tau_INC"] - 0.01,
        benefit_rate = parameters["theta_UB"],
        log_spending_multiplier = log(multiplier),
    )

    function score(policy, seed)
        model, rows = run_episode(
            policy, parameters, initial_conditions;
            seed, reward_config,
        )
        return GovernmentPolicy.episode_score(
            model, rows, initial_conditions, lambda_d
        ).total
    end

    thresholds = (0.04, 0.05, 0.06, 0.07, 0.08)
    training_seeds = 151:170

    training_means = [
        mean(score(feedback_policy(threshold), seed) for seed in training_seeds)
        for threshold in thresholds
    ]

    for (threshold, value) in zip(thresholds, training_means)
        println("Threshold ", threshold, ": training mean score = ", value)
    end

    best_threshold = thresholds[argmax(training_means)]
    println("Selected threshold: ", best_threshold)

    test_seeds = 171:200
    adaptive = feedback_policy(best_threshold)
    adaptive_scores = [score(adaptive, seed) for seed in test_seeds]

    for (name, multiplier) in (("always +5%", 1.05), ("never +5%", 1.0))
        fixed = fixed_policy(multiplier)
        fixed_scores = [score(fixed, seed) for seed in test_seeds]
        differences = adaptive_scores .- fixed_scores

        println(
            "Feedback minus ", name,
            ": mean Δscore = ", mean(differences),
            ", SE = ", std(differences) / sqrt(length(differences)),
        )
    end
end

main(parse(Float64, only(ARGS)))