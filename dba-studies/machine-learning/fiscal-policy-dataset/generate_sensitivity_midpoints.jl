include(joinpath(@__DIR__, "generate_dataset.jl"))

function generate_sensitivity_midpoints(config_path = joinpath(@__DIR__, "experiment-expanded.toml"))
    settings = load_settings(config_path)
    parameters, initial_conditions = calibration(settings)
    reference = [Float64(parameters[name]) for name in POLICY_NAMES[1:3]]
    push!(reference, 1.0)
    frames = DataFrame[]

    for (j, name) in enumerate(POLICY_NAMES), factor in (0.5, 1.5)
        values = copy(reference)
        values[j] *= factor
        policy = (
            tau_INC = values[1], tau_VAT = values[2], theta_UB = values[3],
            spending_multiplier = values[4],
        )
        for seed_index in 1:settings.seeds
            seed = settings.master_seed + seed_index
            trajectory = simulate(parameters, initial_conditions, policy, 0, seed, settings.horizon)
            insertcols!(trajectory, 1, :varied_parameter => fill(name, settings.horizon),
                        :factor => fill(factor, settings.horizon))
            push!(frames, trajectory)
        end
        println("$(name) at $(factor) × reference: $(settings.seeds) seeds complete")
    end

    output = joinpath(settings.output, "sensitivity")
    mkpath(output)
    path = joinpath(output, "paired_midpoints.csv")
    atomic_csv(path, vcat(frames...))
    println("Saved $path")
    return path
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) <= 1 || error("usage: julia --project=. generate_sensitivity_midpoints.jl [experiment.toml]")
    generate_sensitivity_midpoints(isempty(ARGS) ? joinpath(@__DIR__, "experiment-expanded.toml") : ARGS[1])
end
