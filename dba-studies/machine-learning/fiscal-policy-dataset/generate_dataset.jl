import BeforeIT as Bit
using CSV, DataFrames, Dates, Random, SHA, Statistics, TOML

include(joinpath(@__DIR__, "..", "government-rl", "government_policy.jl"))
using .GovernmentPolicy: PolicyModel

const POLICY_NAMES = ("tau_INC", "tau_VAT", "theta_UB", "log_m_G")
const OUTPUT_NAMES = (
    :real_gdp, :real_household_consumption, :real_capitalformation,
    :unemployment_rate, :gdp_deflator_inflation, :government_revenue,
    :government_debt, :debt_to_gdp, :planned_government_consumption,
    :realized_government_consumption,
)

function load_settings(path)
    config = TOML.parsefile(path)
    e, b = config["experiment"], config["bounds"]
    n = Int(e["configurations"])
    n >= 9 || error("configurations must be at least 9 (baseline and eight boundaries)")
    seeds = Int(e["seeds"])
    horizon = Int(e["horizon"])
    seeds > 0 && horizon > 0 || error("seeds and horizon must be positive")
    source = String(e["source"])
    source in ("zenodo", "bundled") || error("source must be zenodo or bundled")
    scale = Float64(e["scale"])
    scale > 0 || error("scale must be positive")
    deltas = Dict(name => Float64(b[name * "_delta"]) for name in POLICY_NAMES[1:3])
    all(x -> isfinite(x) && x > 0, values(deltas)) || error("rate deltas must be positive and finite")
    spending = Float64.(b["spending_multiplier"])
    length(spending) == 2 && 0 < spending[1] < 1 < spending[2] && all(isfinite, spending) ||
        error("spending_multiplier must bracket 1 with positive finite bounds")
    output = String(e["output_dir"])
    output = isabspath(output) ? output : joinpath(dirname(abspath(path)), output)
    return (; n, seeds, horizon, source, scale, master_seed = Int(e["master_seed"]),
            output, deltas, spending)
end

function calibration(settings)
    if settings.source == "bundled"
        settings.scale == 0.001 || error("bundled Austria 2010Q1 only supports scale = 0.001")
        state = Bit.AUSTRIA2010Q1
        return state.parameters, state.initial_conditions
    end
    object = Bit.download_zenodo_calibration_object("AT")
    return Bit.get_params_and_initial_conditions(
        object, DateTime(2010, 3, 31); scale = settings.scale,
    )
end

function policy_bounds(parameters, settings)
    bounds = Dict{String, Tuple{Float64, Float64}}()
    for name in POLICY_NAMES[1:3]
        center = Float64(parameters[name])
        delta = settings.deltas[name]
        bounds[name] = (center - delta, center + delta)
        0 <= bounds[name][1] < center < bounds[name][2] <= 1 ||
            error("invalid bounds for $name")
    end
    bounds["log_m_G"] = Tuple(log.(settings.spending))
    return bounds
end

function configurations(parameters, bounds, n, rng)
    baseline = [Float64(parameters[name]) for name in POLICY_NAMES[1:3]]
    push!(baseline, 0.0)
    policies = Vector{Vector{Float64}}([baseline])
    kinds = ["baseline"]
    for (j, name) in enumerate(POLICY_NAMES)
        for (label, value) in zip(("low", "high"), bounds[name])
            p = copy(baseline)
            p[j] = value
            push!(policies, p)
            push!(kinds, "$(name)_$(label)")
        end
    end
    n_lhs = n - length(policies)
    lhs = Matrix{Float64}(undef, n_lhs, length(POLICY_NAMES))
    for (j, name) in enumerate(POLICY_NAMES)
        low, high = bounds[name]
        strata = randperm(rng, n_lhs)
        lhs[:, j] = low .+ (high - low) .* ((strata .- rand(rng, n_lhs)) ./ n_lhs)
    end
    for i in 1:n_lhs
        push!(policies, vec(lhs[i, :]))
        push!(kinds, "lhs")
    end

    splits = fill("train", n)
    # Keep the calibrated baseline in training; hold out whole other policies.
    permutation = randperm(rng, n - 1) .+ 1
    n_test = max(1, round(Int, 0.1n))
    n_validation = max(1, round(Int, 0.1n))
    splits[permutation[1:n_test]] .= "test"
    splits[permutation[n_test+1:n_test+n_validation]] .= "validation"
    return DataFrame(
        configuration_id = 1:n, kind = kinds, split = splits,
        tau_INC = getindex.(policies, 1), tau_VAT = getindex.(policies, 2),
        theta_UB = getindex.(policies, 3), log_m_G = getindex.(policies, 4),
        spending_multiplier = exp.(getindex.(policies, 4)),
    )
end

function observe(model, policy, configuration_id, seed, quarter)
    d = model.data
    nominal, real = last(d.nominal_gdp), last(d.real_gdp)
    previous_nominal, previous_real = d.nominal_gdp[end-1], d.real_gdp[end-1]
    n = min(4, length(d.nominal_gdp))
    annual_gdp = 4 * mean(d.nominal_gdp[end-n+1:end])
    nominal > 0 && real > 0 && previous_nominal > 0 && previous_real > 0 && annual_gdp > 0 ||
        error("GDP must be positive at quarter $quarter")
    previous_deflator = previous_nominal / previous_real
    row = (
        configuration_id = configuration_id, seed = seed, quarter = quarter,
        tau_INC = policy.tau_INC, tau_VAT = policy.tau_VAT,
        theta_UB = policy.theta_UB, log_m_G = policy.log_m_G,
        spending_multiplier = exp(policy.log_m_G),
        real_gdp = real,
        real_household_consumption = last(d.real_household_consumption),
        real_capitalformation = last(d.real_capitalformation),
        unemployment_rate = count(iszero, model.w_act.O_h) / length(model.w_act.O_h),
        gdp_deflator_inflation = (nominal / real) / previous_deflator - 1,
        government_revenue = model.gov.Y_G,
        government_debt = model.gov.L_G,
        debt_to_gdp = model.gov.L_G / annual_gdp,
        planned_government_consumption = model.gov.C_G,
        realized_government_consumption = model.gov.C_j,
        nominal_gdp = nominal, annual_nominal_gdp = annual_gdp,
    )
    all(isfinite, (getproperty(row, name) for name in OUTPUT_NAMES)) ||
        error("non-finite output at quarter $quarter")
    return row
end

function simulate(parameters, initial_conditions, policy, configuration_id, seed, horizon)
    Random.seed!(seed)
    base = Bit.Model(deepcopy(parameters), deepcopy(initial_conditions))
    model = PolicyModel(Bit.fields(base)..., one(Bit.typeFloat))
    model.prop.tau_INC = policy.tau_INC
    model.prop.tau_VAT = policy.tau_VAT
    model.prop.theta_UB = policy.theta_UB
    model.spending_multiplier = exp(policy.log_m_G)

    rows = NamedTuple[]
    for quarter in 1:horizon
        Bit.step!(model; parallel = false)
        Bit.collect_data!(model)
        (model.prop.tau_INC, model.prop.tau_VAT, model.prop.theta_UB,
         model.spending_multiplier) ==
        (policy.tau_INC, policy.tau_VAT, policy.theta_UB, exp(policy.log_m_G)) ||
            error("fiscal policy changed during the run")
        push!(rows, observe(model, policy, configuration_id, seed, quarter))
    end
    length(model.data.collection_time) == horizon + 1 || error("incomplete trajectory")
    return DataFrame(rows)
end

function atomic_csv(path, table)
    temporary = path * ".tmp"
    CSV.write(temporary, table)
    mv(temporary, path; force = true)
end

function snapshot_sources(output, config_path)
    sources = (
        joinpath(@__DIR__, "generate_dataset.jl"),
        joinpath(@__DIR__, "..", "government-rl", "government_policy.jl"),
        abspath(config_path),
    )
    for source in sources
        destination = joinpath(output, basename(source))
        if isfile(destination)
            read(destination) == read(source) || error("source changed since this dataset started: $source")
        else
            cp(source, destination)
        end
    end
end

function save_metadata(path, settings, parameters, bounds)
    repo = normpath(joinpath(@__DIR__, "..", "..", ".."))
    revision = try
        readchomp(`git -C $repo rev-parse HEAD`)
    catch
        "unknown"
    end
    source_tree_dirty = !success(`git -C $repo diff --quiet HEAD -- src Project.toml`)
    source_patch_sha256 = bytes2hex(sha256(read(`git -C $repo diff --binary HEAD -- src Project.toml`)))
    content = Dict(
        "calibration" => Dict(
            "country" => "AT", "date" => "2010-03-31", "source" => settings.source,
            "scale" => settings.scale,
        ),
        "experiment" => Dict(
            "configurations" => settings.n, "seeds" => settings.seeds,
            "horizon" => settings.horizon, "master_seed" => settings.master_seed,
            "julia_version" => string(VERSION),
            "beforeit_git_commit" => revision,
            "beforeit_source_tree_dirty" => source_tree_dirty,
            "beforeit_source_patch_sha256" => source_patch_sha256,
            "seed_rule" => "master_seed + seed_index; common across configurations",
            "splits" => "80/10/10 by configuration, rounded for validation and test",
        ),
        "policy" => Dict(name => Dict(
            "baseline" => name == "log_m_G" ? 0.0 : Float64(parameters[name]),
            "lower" => bounds[name][1], "upper" => bounds[name][2],
        ) for name in POLICY_NAMES),
    )
    if isfile(path)
        TOML.parsefile(path) == content || error("calibration or code version changed since this dataset started")
        return
    end
    open(path, "w") do io
        TOML.print(io, content)
    end
end

function empty_run_index()
    return DataFrame(
        configuration_id = Int[], seed = Int[], status = String[],
        runtime_seconds = Float64[], trajectory_path = String[], failure = String[],
    )
end

function collect_outputs(output, runs, horizon)
    frames = DataFrame[]
    for run in eachrow(runs)
        run.status == "success" || continue
        path = joinpath(output, run.trajectory_path)
        isfile(path) || error("missing successful trajectory: $path")
        frame = CSV.read(path, DataFrame)
        nrow(frame) == horizon || error("wrong trajectory length: $path")
        push!(frames, frame)
    end
    isempty(frames) && return
    observations = vcat(frames...)
    atomic_csv(joinpath(output, "observations.csv"), observations)
    groups = groupby(observations, [:configuration_id, :quarter])
    operations = Any[nrow => :successful_seeds]
    for metric in OUTPUT_NAMES
        push!(operations, metric => mean => Symbol(metric, "_mean"))
        push!(operations, metric => (x -> length(x) > 1 ? std(x) / sqrt(length(x)) : missing) => Symbol(metric, "_se"))
    end
    summary = combine(groups, operations...)
    atomic_csv(joinpath(output, "summary.csv"), summary)
end

function generate_dataset(config_path = joinpath(@__DIR__, "experiment.toml"))
    settings = load_settings(config_path)
    println("Loading Austrian calibration ($(settings.source), scale $(settings.scale))...")
    parameters, initial_conditions = calibration(settings)
    bounds = policy_bounds(parameters, settings)
    configs = configurations(parameters, bounds, settings.n, MersenneTwister(settings.master_seed))
    output = settings.output
    mkpath(joinpath(output, "trajectories"))
    snapshot_sources(output, config_path)
    save_metadata(joinpath(output, "metadata.toml"), settings, parameters, bounds)
    config_file = joinpath(output, "configurations.csv")
    if isfile(config_file)
        CSV.read(config_file, DataFrame) == configs || error("configurations changed since this dataset started")
    else
        atomic_csv(config_file, configs)
    end

    index_file = joinpath(output, "runs.csv")
    runs = isfile(index_file) ? CSV.read(index_file, DataFrame) : empty_run_index()
    runs.failure = String.(coalesce.(runs.failure, ""))
    for config in eachrow(configs), seed_index in 1:settings.seeds
        id = config.configuration_id
        seed = settings.master_seed + seed_index
        filename = "$(lpad(id, 4, '0'))_$(seed).csv"
        relative_path = joinpath("trajectories", filename)
        path = joinpath(output, relative_path)
        existing = findfirst((runs.configuration_id .== id) .& (runs.seed .== seed))
        if !isnothing(existing) && runs.status[existing] == "success" && isfile(path)
            continue
        end
        policy = (
            tau_INC = config.tau_INC, tau_VAT = config.tau_VAT,
            theta_UB = config.theta_UB, log_m_G = config.log_m_G,
        )
        started = time()
        status, failure = "success", ""
        try
            trajectory = simulate(parameters, initial_conditions, policy, id, seed, settings.horizon)
            atomic_csv(path, trajectory)
        catch err
            status = "failed"
            failure = sprint(showerror, err, catch_backtrace())
        end
        record = (id, seed, status, time() - started, relative_path, failure)
        if isnothing(existing)
            push!(runs, record)
        else
            runs[existing, :] = collect(record)
        end
        atomic_csv(index_file, runs)
        println("configuration $id/$(settings.n), seed $seed: $status ($(round(record[4]; digits=1)) s)")
        GC.gc()
    end
    collect_outputs(output, runs, settings.horizon)
    failed = count(==("failed"), runs.status)
    println("Saved dataset in $output")
    failed == 0 || error("$failed runs failed; see runs.csv and rerun to retry")
    return output
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) <= 1 || error("usage: julia --project=. generate_dataset.jl [experiment.toml]")
    generate_dataset(isempty(ARGS) ? joinpath(@__DIR__, "experiment.toml") : ARGS[1])
end
