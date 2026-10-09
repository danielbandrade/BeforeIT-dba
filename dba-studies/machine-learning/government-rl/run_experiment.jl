using TOML
import BeforeIT as Bit

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