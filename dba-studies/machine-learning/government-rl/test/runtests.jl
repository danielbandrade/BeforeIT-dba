using Test, Random
import BeforeIT as Bit

include(joinpath(@__DIR__, "..", "government_policy.jl"))
using .GovernmentPolicy

include(joinpath(
    @__DIR__, "..", "..", "explanation-traces", "src", "explanation_traces.jl",
))
using .ExplanationTraces: state_equal

parameters = Bit.AUSTRIA2010Q1.parameters
initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
seed = 5101
horizon = 12

Random.seed!(seed)
baseline = Bit.Model(deepcopy(parameters), deepcopy(initial_conditions))
Bit.run!(baseline, horizon; parallel = false)

no_op(obs, _) = (
    tax_rate = obs.tax_rate,
    benefit_rate = obs.benefit_rate,
    log_spending_multiplier = 0.0,
)

policy_model, rows = run_episode(
    no_op, parameters, initial_conditions; seed, horizon,
)

@test length(rows) == horizon
@test length(Bit.fields(policy_model)) == length(Bit.fields(baseline)) + 1
@test all(
    state_equal(x, y)
    for (x, y) in zip(Bit.fields(baseline), Bit.fields(policy_model))
)