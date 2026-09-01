include("surrogate_utils.jl")

function summarize_dataset(data_dir = joinpath(@__DIR__, "data"))
    runs = CSV.read(joinpath(data_dir, "raw_runs.csv"), DataFrame)
    rows = DataFrame()
    for run in eachrow(runs)
        run.success || continue
        values = JLD2.load(joinpath(data_dir, run.trajectory_path), "trajectory")
        validate_trajectory(values, run.horizon)
        targets = scalar_targets(values)
        row = DataFrame(configuration_id = [run.configuration_id], seed = [run.seed])
        for name in PARAMETER_NAMES
            row[!, name] = [run[name]]
        end
        for name in TARGET_NAMES
            row[!, name] = [targets[name]]
        end
        append!(rows, row; cols = :union)
    end
    isempty(rows) && error("No successful trajectories were found")
    CSV.write(joinpath(data_dir, "scalar_targets.csv"), rows)

    grouped = groupby(rows, :configuration_id)
    parameter_means = [name => mean => name for name in PARAMETER_NAMES]
    target_statistics = vcat(
        [name => mean => name for name in TARGET_NAMES],
        [name => (x -> length(x) > 1 ? std(x) : 0.0) => "$(name)_std" for name in TARGET_NAMES],
    )
    aggregate = combine(grouped, parameter_means..., target_statistics...)
    CSV.write(joinpath(data_dir, "configuration_targets.csv"), aggregate)
    return aggregate
end

abspath(PROGRAM_FILE) == (@__FILE__) && summarize_dataset()
