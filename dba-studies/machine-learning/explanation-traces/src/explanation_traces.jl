module ExplanationTraces

import BeforeIT as Bit

using CSV
using DataFrames
using Dates
using JLD2
using Random
using TOML

export SCHEMA_VERSION, aggregate_series, firm_matrix, firm_panel, firm_transition_panel,
    generate_experiment, load_snapshot, save_snapshot, simulate_snapshots, snapshot_paths,
    state_equal

const SCHEMA_VERSION = 2
const ROOT = normpath(joinpath(@__DIR__, ".."))
const REQUIRED_KEYS = Set(
    [
        "schema_version", "experiment_id", "run_id", "scenario_id", "seed", "horizon",
        "quarter", "model_time", "captured_at_utc", "model",
    ]
)

"""Return whether two model states have identical types, fields, and values."""
function state_equal(left, right)
    typeof(left) === typeof(right) || return false
    if left isa AbstractArray || left isa AbstractDict
        return isequal(left, right)
    elseif left isa Base.RefValue
        return state_equal(left[], right[])
    elseif fieldcount(typeof(left)) > 0
        return all(
            state_equal(getfield(left, field), getfield(right, field))
                for field in fieldnames(typeof(left))
        )
    end
    return isequal(left, right)
end

function snapshot_name(quarter::Integer)
    quarter >= 0 || error("quarter must be non-negative")
    return "quarter-$(lpad(string(quarter), 4, '0')).jld2"
end

is_snapshot_path(path) = match(r"^quarter-\d+\.jld2$", basename(path)) !== nothing

"""Save one complete model state without overwriting an existing snapshot."""
function save_snapshot(
        path, model;
        experiment_id, run_id, scenario_id, seed::Integer, horizon::Integer, quarter::Integer,
    )
    quarter <= horizon || error("quarter $quarter exceeds horizon $horizon")
    isfile(path) && error("Refusing to overwrite completed snapshot: $path")
    mkpath(dirname(path))
    temporary = path * ".tmp.jld2"
    isfile(temporary) && rm(temporary)
    try
        JLD2.save(
            temporary,
            "schema_version", SCHEMA_VERSION,
            "experiment_id", string(experiment_id),
            "run_id", string(run_id),
            "scenario_id", string(scenario_id),
            "seed", Int(seed),
            "horizon", Int(horizon),
            "quarter", Int(quarter),
            "model_time", Int(model.agg.t),
            "captured_at_utc", Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
            "model", model,
        )
        loaded = load_snapshot(temporary)
        typeof(loaded["model"]) === typeof(model) || error("Model type changed during JLD2 round trip")
        state_equal(loaded["model"], model) || error("Model state changed during JLD2 round trip")
        mv(temporary, path)
    finally
        isfile(temporary) && rm(temporary)
    end
    return path
end

"""Load and validate one complete quarterly model snapshot."""
function load_snapshot(path)
    isfile(path) || error("Missing snapshot: $path")
    snapshot = JLD2.load(path)
    missing_keys = setdiff(REQUIRED_KEYS, Set(keys(snapshot)))
    isempty(missing_keys) || error("Snapshot is missing keys: $(join(sort!(collect(missing_keys)), ", "))")
    snapshot["schema_version"] == SCHEMA_VERSION ||
        error("Unsupported snapshot schema $(snapshot["schema_version"]); expected $SCHEMA_VERSION")
    snapshot["model"] isa Bit.AbstractModel || error("Snapshot does not contain a BeforeIT model")
    snapshot["model_time"] == snapshot["model"].agg.t || error("Snapshot model_time does not match model.agg.t")
    0 <= snapshot["quarter"] <= snapshot["horizon"] || error("Snapshot quarter is outside its horizon")
    return snapshot
end

"""List a run's completed snapshots in quarter order."""
function snapshot_paths(run_directory)
    isdir(run_directory) || error("Missing snapshot directory: $run_directory")
    paths = sort!(filter(is_snapshot_path, readdir(run_directory; join = true)))
    isempty(paths) && error("No snapshots found in $run_directory")
    snapshots = load_snapshot.(paths)
    quarters = Int[snapshot["quarter"] for snapshot in snapshots]
    horizons = unique(Int[snapshot["horizon"] for snapshot in snapshots])
    run_ids = unique(string(snapshot["run_id"]) for snapshot in snapshots)
    length(horizons) == 1 || error("Snapshots disagree on horizon: $horizons")
    length(run_ids) == 1 || error("Snapshots contain multiple run IDs: $run_ids")
    quarters == collect(0:only(horizons)) || error("Snapshot run is incomplete: $quarters")
    return paths
end

"""Run one seeded serial simulation and save initialization plus every quarter."""
function simulate_snapshots(
        parameters, initial_conditions;
        horizon::Integer, seed::Integer, output_directory, experiment_id, run_id, scenario_id,
        shock! = Bit.NoShock(),
    )
    horizon >= 1 || error("horizon must be positive")
    ispath(output_directory) && error("Refusing to overwrite snapshot directory: $output_directory")
    mkpath(output_directory)
    Random.seed!(seed)
    model = Bit.Model(deepcopy(parameters), deepcopy(initial_conditions))
    save_snapshot(
        joinpath(output_directory, snapshot_name(0)), model;
        experiment_id, run_id, scenario_id, seed, horizon, quarter = 0,
    )
    for quarter in 1:horizon
        Bit.step!(model; parallel = false, shock!)
        Bit.collect_data!(model)
        save_snapshot(
            joinpath(output_directory, snapshot_name(quarter)), model;
            experiment_id, run_id, scenario_id, seed, horizon, quarter,
        )
    end
    return model, snapshot_paths(output_directory)
end

function configured_shock(scenario)
    config = get(scenario, "shock", "none")
    config == "none" && return Bit.NoShock()
    config isa AbstractDict || error("Invalid shock configuration in scenario $(scenario["id"])")
    get(config, "type", "") == "consumption" || error("Unsupported shock type: $(get(config, "type", ""))")
    multiplier, final_time = Float64(config["multiplier"]), Int(config["final_time"])
    multiplier > 0 || error("Consumption-shock multiplier must be positive")
    final_time > 1 || error("Consumption-shock final_time must be greater than 1")
    return Bit.ConsumptionShock(multiplier, final_time)
end

function calibration(name)
    symbol = Symbol(name)
    isdefined(Bit, symbol) || error("Unknown BeforeIT calibration: $name")
    value = getfield(Bit, symbol)
    hasproperty(value, :parameters) && hasproperty(value, :initial_conditions) ||
        error("$name is not a calibration with parameters and initial conditions")
    return value
end

function apply_changes!(parameters, scenario)
    for change in get(scenario, "changes", Any[])
        name = change["parameter"]
        haskey(parameters, name) || error("Unknown parameter in scenario $(scenario["id"]): $name")
        parameters[name] isa Number || error("Only scalar parameter changes are supported: $name")
        operation, value = change["operation"], change["value"]
        parameters[name] = if operation == "multiply"
            parameters[name] * value
        elseif operation == "add"
            parameters[name] + value
        elseif operation == "set"
            value
        else
            error("Unsupported parameter operation: $operation")
        end
    end
    return parameters
end

function git_metadata()
    commit = try
        strip(read(`git rev-parse HEAD`, String))
    catch
        "unknown"
    end
    dirty = try
        !isempty(strip(read(`git status --porcelain`, String)))
    catch
        missing
    end
    return commit, dirty
end

function write_manifest(path, rows)
    CSV.write(path, DataFrame(rows))
    return path
end

"""Generate all declared runs as directories of complete quarterly snapshots."""
function generate_experiment(specification_path; output_root = joinpath(ROOT, "experiments"))
    specification = TOML.parsefile(specification_path)
    experiment = specification["experiment"]
    scenarios = specification["scenarios"]
    get(experiment, "shock", "none") == "none" || error("Only unshocked runs are currently supported")

    experiment_id = experiment["id"]
    experiment_directory = joinpath(output_root, experiment_id)
    ispath(experiment_directory) && error("Refusing to overwrite experiment directory: $experiment_directory")
    mkpath(joinpath(experiment_directory, "snapshots"))
    cp(specification_path, joinpath(experiment_directory, "specification.toml"))

    source = calibration(experiment["calibration"])
    horizon = Int(experiment["horizon"])
    seeds = Int.(experiment["seeds"])
    commit, dirty = git_metadata()
    manifest_rows = NamedTuple[]
    manifest_path = joinpath(experiment_directory, "runs.csv")

    for seed in seeds, scenario in scenarios
        scenario_id, role = scenario["id"], get(scenario, "role", "scenario")
        run_id = "$(scenario_id)-seed-$(seed)"
        pair_id = "seed-$(seed)"
        relative_directory = joinpath("snapshots", run_id)
        output_directory = joinpath(experiment_directory, relative_directory)
        started = time()
        success, failure_reason = true, ""
        paths = String[]
        try
            parameters = apply_changes!(deepcopy(source.parameters), scenario)
            shock! = configured_shock(scenario)
            _, paths = simulate_snapshots(
                parameters, source.initial_conditions;
                horizon, seed, output_directory, experiment_id, run_id, scenario_id,
                shock!,
            )
        catch exception
            success = false
            failure_reason = sprint(showerror, exception, catch_backtrace())
            paths = isdir(output_directory) ?
                sort!(filter(is_snapshot_path, readdir(output_directory; join = true))) : String[]
        end
        total_bytes = sum(filesize, paths; init = 0)
        push!(
            manifest_rows, (
                run_id,
                scenario_id,
                role,
                pair_id,
                seed,
                horizon,
                snapshot_directory = relative_directory,
                snapshots_written = length(paths),
                total_bytes,
                runtime_seconds = time() - started,
                success,
                failure_reason,
                git_commit = commit,
                dirty_worktree = dirty,
                julia_version = string(VERSION),
                beforeit_version = string(Base.pkgversion(Bit)),
            )
        )
        write_manifest(manifest_path, manifest_rows)
    end
    all(row.success for row in manifest_rows) || error("One or more runs failed; see $manifest_path")
    return experiment_directory
end

function firm_value(firms, field::Symbol)
    if field == :credit_gap
        return max.(firms.DL_d_i .- firms.DL_i, 0)
    end
    field in fieldnames(typeof(firms)) || error("Unknown firm field: $field")
    values = getfield(firms, field)
    values isa AbstractVector || error("Firm field $field is not a vector")
    return values
end

"""Create a long firm-quarter table from complete snapshot files."""
function firm_panel(paths; fields = [:Y_i, :Q_i, :Q_d_i, :N_i, :V_i, :P_i, :Pi_i, :E_i, :L_i, :D_i, :DL_d_i, :DL_i, :credit_gap])
    frames = DataFrame[]
    for path in paths
        snapshot = load_snapshot(path)
        firms = snapshot["model"].firms
        count = length(firms.ID)
        frame = DataFrame(
            run_id = fill(snapshot["run_id"], count),
            scenario_id = fill(snapshot["scenario_id"], count),
            seed = fill(snapshot["seed"], count),
            quarter = fill(snapshot["quarter"], count),
            firm_id = copy(firms.ID),
            sector = copy(firms.G_i),
        )
        for field in fields
            values = firm_value(firms, field)
            length(values) == count || error("Firm field $field is not aligned with firms.ID")
            frame[!, field] = copy(values)
        end
        push!(frames, frame)
    end
    return vcat(frames...; cols = :setequal)
end

"""
Derive firm transitions from consecutive snapshots. `bankruptcy_trigger` is the
end-of-quarter insolvency condition refinanced at the start of the next quarter;
`employment_decision` is desired employment minus prior-quarter employment.
"""
function firm_transition_panel(paths)
    frames = DataFrame[]
    previous_employment = Dict{Int, Int}()
    for path in paths
        snapshot = load_snapshot(path)
        firms = snapshot["model"].firms
        count = length(firms.ID)
        decisions = Union{Missing, Int}[
            haskey(previous_employment, id) ? firms.N_d_i[index] - previous_employment[id] : missing
                for (index, id) in enumerate(firms.ID)
        ]
        realized_changes = Union{Missing, Int}[
            haskey(previous_employment, id) ? firms.N_i[index] - previous_employment[id] : missing
                for (index, id) in enumerate(firms.ID)
        ]
        push!(
            frames,
            DataFrame(
                run_id = fill(snapshot["run_id"], count),
                scenario_id = fill(snapshot["scenario_id"], count),
                seed = fill(snapshot["seed"], count),
                quarter = fill(snapshot["quarter"], count),
                firm_id = copy(firms.ID),
                sector = copy(firms.G_i),
                bankruptcy_trigger = (firms.D_i .< 0) .& (firms.E_i .< 0),
                employment_decision = decisions,
                employment_decision_direction = [ismissing(value) ? missing : sign(value) for value in decisions],
                realized_employment_change = realized_changes,
            ),
        )
        previous_employment = Dict(id => firms.N_i[index] for (index, id) in enumerate(firms.ID))
    end
    return vcat(frames...; cols = :setequal)
end

"""Convert a firm panel into a stable firm-by-quarter heatmap matrix."""
function firm_matrix(panel::DataFrame, measure::Symbol)
    measure in propertynames(panel) || error("Missing firm measure: $measure")
    sectors = Dict{Int, Int}()
    for row in eachrow(panel)
        sector = Int(row.sector)
        if haskey(sectors, row.firm_id) && sectors[row.firm_id] != sector
            error("Firm $(row.firm_id) changes sector across snapshots")
        end
        sectors[Int(row.firm_id)] = sector
    end
    firm_ids = sort!(collect(keys(sectors)); by = id -> (sectors[id], id))
    quarters = sort!(unique(Int.(panel.quarter)))
    values = fill(NaN, length(firm_ids), length(quarters))
    occupied = falses(size(values))
    firm_index = Dict(id => index for (index, id) in enumerate(firm_ids))
    quarter_index = Dict(quarter => index for (index, quarter) in enumerate(quarters))
    for row in eachrow(panel)
        position = (firm_index[Int(row.firm_id)], quarter_index[Int(row.quarter)])
        occupied[position...] && error("Duplicate firm-quarter row: $(row.firm_id), $(row.quarter)")
        occupied[position...] = true
        value = row[measure]
        values[position...] = ismissing(value) ? NaN : Float64(value)
    end
    return (
        values,
        firm_ids,
        quarters,
        sectors = [sectors[id] for id in firm_ids],
        measure,
    )
end

"""Read the last recorded aggregate value from each quarterly snapshot."""
function aggregate_series(paths, field::Symbol)
    rows = NamedTuple[]
    for path in paths
        snapshot = load_snapshot(path)
        data = snapshot["model"].data
        field in fieldnames(typeof(data)) || error("Unknown aggregate field: $field")
        history = getfield(data, field)
        value = history isa AbstractVector ? last(history) : history
        push!(rows, (quarter = snapshot["quarter"], value = Float64(value)))
    end
    return sort!(DataFrame(rows), :quarter)
end

end
