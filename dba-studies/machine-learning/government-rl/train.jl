using TOML, Random, Statistics, Serialization
import BeforeIT as Bit

include("government_policy.jl")
using .GovernmentPolicy: run_episode

function main()
    parameters = Bit.AUSTRIA2010Q1.parameters
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    settings = TOML.parsefile(joinpath(@__DIR__, "experiment.toml"))["reward"]
    reward_config = (; (Symbol(k) => v for (k, v) in settings)...)

    lambda_d = parse(Float64, only(ARGS))
    lambda_d in reward_config.lambda_d_candidates ||
        error("Choose a lambda_d from experiment.toml")

    actions = vec([
        (tax, benefit, spending)
        for tax in (-0.01, 0.0, 0.01),
            benefit in (-0.01, 0.0, 0.01),
            spending in (0.95, 1.0, 1.05)
    ])

    weights = zeros(length(actions), 4)
    baseline = nothing
    scores = Float64[]

    for episode in 1:100
        trace = Tuple{Vector{Float64}, Vector{Float64}, Int}[]

        policy = (obs, rng) -> begin
            x = [1.0, 10 * obs.unemployment_rate,
                 obs.debt_to_gdp, obs.quarter / 12]
            logits = weights * x
            probabilities = exp.(logits .- maximum(logits))
            probabilities ./= sum(probabilities)

            index = min(
                searchsortedfirst(cumsum(probabilities), rand(rng)),
                length(actions),
            )
            push!(trace, (x, probabilities, index))

            tax, benefit, spending = actions[index]
            (
                tax_rate = parameters["tau_INC"] + tax,
                benefit_rate = parameters["theta_UB"] + benefit,
                log_spending_multiplier = log(spending),
            )
        end

        model, rows = run_episode(
            policy, parameters, initial_conditions;
            seed = 50 + episode,
            policy_seed = 1000 + episode,
            reward_config,
        )
        score = GovernmentPolicy.episode_score(
            model, rows, initial_conditions, lambda_d
        ).total
        push!(scores, score)

        if !isnothing(baseline)
            gradient = zeros(size(weights))
            for (x, probabilities, index) in trace
                gradient .-= probabilities * x'
                gradient[index, :] .+= x
            end
            weights .+=
                (0.02 * (score - baseline) / length(trace)) .* gradient
        end

        baseline = isnothing(baseline) ?
            score : 0.9 * baseline + 0.1 * score

        if episode % 10 == 0
            println("Episode $episode: mean score of last 10 = ",
                    mean(scores[end-9:end]))
        end
    end

    serialize(
        joinpath(@__DIR__, "trained_policy.jls"),
        (; weights, lambda_d),
    )
end

main()