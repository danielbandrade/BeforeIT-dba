import BeforeIT as Bit
include("surrogate_utils.jl")

const ROOT = @__DIR__
const DATA_DIR = joinpath(ROOT, "data")
const TRAJECTORY_DIR = joinpath(DATA_DIR, "trajectories")

function simulate(parameters, initial_conditions, horizon, seed)
    Random.seed!(seed)
    model = Bit.Model(parameters, deepcopy(initial_conditions))
    Bit.run!(model, horizon; parallel = false)
    values = trajectory(model.data)
    validate_trajectory(values, horizon)
    return values
end

function write_metadata(path, baseline, bounds, n_configurations, seeds, horizon, master_seed)
    metadata = Dict(
        "experiment" => Dict(
            "configurations" => n_configurations,
            "seeds_per_configuration" => seeds,
            "horizon" => horizon,
            "master_seed" => master_seed,
            "parameter_width" => 0.20,
        ),
        "parameters" => Dict(name => Dict("baseline" => baseline[name], "lower" => bounds[name][1], "upper" => bounds[name][2]) for name in PARAMETER_NAMES),
    )
    open(path, "w") do io
        TOML.print(io, metadata)
    end
end

function generate_dataset(; n_configurations = 100, seeds = 5, horizon = 12, master_seed = 2025)
    mkpath(TRAJECTORY_DIR)
    baseline = deepcopy(Bit.AUSTRIA2010Q1.parameters)
    initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    samples, bounds = sample_configurations(baseline, n_configurations, MersenneTwister(master_seed))

    configurations = DataFrame(configuration_id = 1:n_configurations)
    for (j, name) in enumerate(PARAMETER_NAMES)
        configurations[!, name] = samples[:, j]
    end
    CSV.write(joinpath(DATA_DIR, "configurations.csv"), configurations)
    write_metadata(joinpath(DATA_DIR, "metadata.toml"), baseline, bounds, n_configurations, seeds, horizon, master_seed)

    index_path = joinpath(DATA_DIR, "raw_runs.csv")
    isfile(index_path) && rm(index_path)
    for row in eachrow(configurations), seed in 1:seeds
        id = Int(row.configuration_id)
        filename = "$(lpad(id, 4, '0'))_$(seed).jld2"
        relative_path = joinpath("trajectories", filename)
        started = time()
        success, failure = true, ""
        try
            parameters = deepcopy(baseline)
            for name in PARAMETER_NAMES
                parameters[name] = row[name]
            end
            run_seed = master_seed + 10_000id + seed
            values = simulate(parameters, initial_conditions, horizon, run_seed)
            path = joinpath(DATA_DIR, relative_path)
            JLD2.save(path, "trajectory", values)
            JLD2.load(path, "trajectory") == values || error("Trajectory changed during its JLD2 round trip")
            if id == 1 && seed == 1
                simulate(parameters, initial_conditions, horizon, run_seed) == values || error("Identically seeded runs are not reproducible")
            end
        catch error
            success, failure = false, sprint(showerror, error)
        end

        run = DataFrame(configuration_id = [id], seed = [seed], horizon = [horizon], trajectory_path = [relative_path], runtime_seconds = [time() - started], success = [success], failure_reason = [failure])
        for name in PARAMETER_NAMES
            run[!, name] = [row[name]]
        end
        CSV.write(index_path, run; append = isfile(index_path), writeheader = !isfile(index_path))
    end
    return index_path
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_dataset(
        n_configurations = parse(Int, get(ENV, "SURROGATE_CONFIGURATIONS", "100")),
        seeds = parse(Int, get(ENV, "SURROGATE_SEEDS", "5")),
        horizon = parse(Int, get(ENV, "SURROGATE_HORIZON", "12")),
        master_seed = parse(Int, get(ENV, "SURROGATE_MASTER_SEED", "2025")),
    )
end
