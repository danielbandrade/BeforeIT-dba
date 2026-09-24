include(joinpath(@__DIR__, "src", "explanation_traces.jl"))

using .ExplanationTraces

specification = isempty(ARGS) ? joinpath(@__DIR__, "experiment.toml") : abspath(ARGS[1])
output = generate_experiment(specification)
println("saved: $output")
