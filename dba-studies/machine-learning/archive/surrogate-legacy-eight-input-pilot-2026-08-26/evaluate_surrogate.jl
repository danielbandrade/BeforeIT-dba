import BeforeIT as Bit
include("surrogate_utils.jl")

function predict_surrogate(parameters::AbstractDict, model_path = joinpath(@__DIR__, "results", "surrogate.jld2"))
    saved = JLD2.load(model_path)
    names, targets, bounds = saved["parameter_names"], saved["target_names"], saved["bounds"]
    values = Float64[]
    for name in names
        value = Float64(parameters[name])
        lower, upper = bounds[name]["lower"], bounds[name]["upper"]
        lower <= value <= upper || error("$name=$value is outside the trained range [$lower, $upper]")
        push!(values, value)
    end
    values[1] + values[2] <= 1 || error("psi + psi_H must not exceed 1")
    x = vcat(1.0, (values .- saved["means"]) ./ saved["scales"])
    estimates = vec(x' * saved["coefficients"])
    return DataFrame(
        target = targets,
        prediction = estimates,
        lower_90 = [estimates[i] + saved["residual_intervals"][targets[i]][1] for i in eachindex(targets)],
        upper_90 = [estimates[i] + saved["residual_intervals"][targets[i]][2] for i in eachindex(targets)],
    )
end

function compare_with_simulation(parameters::AbstractDict; seeds = 5, horizon = 12, master_seed = 90_000)
    predictions = predict_surrogate(parameters)
    simulation_parameters = deepcopy(Bit.AUSTRIA2010Q1.parameters)
    for name in PARAMETER_NAMES
        simulation_parameters[name] = parameters[name]
    end
    outcomes = [Float64[] for _ in TARGET_NAMES]
    for seed in 1:seeds
        Random.seed!(master_seed + seed)
        model = Bit.Model(deepcopy(simulation_parameters), deepcopy(Bit.AUSTRIA2010Q1.initial_conditions))
        Bit.run!(model, horizon; parallel = false)
        targets = scalar_targets(trajectory(model.data))
        for (i, target) in enumerate(TARGET_NAMES)
            push!(outcomes[i], targets[target])
        end
    end
    predictions[!, :simulation_mean] = mean.(outcomes)
    predictions[!, :absolute_error] = abs.(predictions.prediction .- predictions.simulation_mean)
    return predictions
end

if abspath(PROGRAM_FILE) == @__FILE__
    baseline = Dict(name => Float64(Bit.AUSTRIA2010Q1.parameters[name]) for name in PARAMETER_NAMES)
    comparison = compare_with_simulation(baseline; seeds = parse(Int, get(ENV, "SURROGATE_VALIDATION_SEEDS", "5")))
    mkpath(joinpath(@__DIR__, "results"))
    CSV.write(joinpath(@__DIR__, "results", "fresh_validation.csv"), comparison)
    display(comparison)
end
