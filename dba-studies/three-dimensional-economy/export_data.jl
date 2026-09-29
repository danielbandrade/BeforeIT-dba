include(joinpath(@__DIR__, "..", "machine-learning", "explanation-traces", "src", "explanation_traces.jl"))
using .ExplanationTraces: load_snapshot
using CSV, TOML

const EXPERIMENTS = joinpath(@__DIR__, "..", "machine-learning", "explanation-traces", "experiments")
const CHEATSHEET = joinpath(@__DIR__, "..", "model-mechanics", "sector-cheatsheet.md")

mapping = split(split(read(CHEATSHEET, String), "## Complete mapping"; limit = 2)[2], "## Interpretation notes"; limit = 2)[1]
sectors = [
    (id = parse(Int, match_row[1]), nace = strip(match_row[2]), description = strip(match_row[3]))
    for line in split(mapping, '\n')
    for match_row in (match(r"^\|\s*(\d+)\s*\|\s*([^|]+)\s*\|\s*([^|]+)\s*\|", line),)
    if match_row !== nothing
]
getproperty.(sectors, :id) == collect(1:62) || error("The sector cheatsheet must map sectors 1 through 62")

runs = NamedTuple[]
for directory in sort(readdir(EXPERIMENTS; join = true))
    manifest = joinpath(directory, "runs.csv")
    specification = joinpath(directory, "specification.toml")
    isfile(manifest) && isfile(specification) || continue
    spec = TOML.parsefile(specification)
    experiment = String(spec["experiment"]["id"])
    experiment == basename(directory) || error("Experiment ID differs from directory: $directory")
    for row in CSV.File(manifest)
        hasproperty(row, :snapshot_directory) || continue # older trace format has no quarterly model snapshots
        row.success === true || continue
        source = joinpath(directory, String(row.snapshot_directory))
        isdir(source) || error("Completed run has no snapshots: $source")
        scenario = String(row.scenario_id)
        any(item -> item["id"] == scenario, spec["scenarios"]) || error("Unknown scenario $scenario")
        horizon = Int(row.horizon)
        paths = sort(filter(path -> occursin(r"^quarter-\d{4}\.jld2$", basename(path)), readdir(source; join = true)))
        length(paths) == horizon + 1 || error("Incomplete snapshot run: $source")
        push!(runs, (experiment, run = String(row.run_id), scenario, seed = Int(row.seed),
            calibration = String(spec["experiment"]["calibration"]), horizon, paths))
    end
end
isempty(runs) && error("No completed quarterly snapshot runs found in $EXPERIMENTS")
allunique((run.experiment, run.run) for run in runs) || error("Repeated experiment/run identity")

output = joinpath(@__DIR__, "data.js")
temporary = output * ".tmp"
open(temporary, "w") do io
    print(io, "window.BEFOREIT_EXPERIMENTS={sectors:[null")
    for sector in sectors
        print(io, ",[", repr(sector.nace), ',', repr(sector.description), ']')
    end
    print(io, "],datasets:[")
    for (run_index, run) in enumerate(runs)
        run_index > 1 && print(io, ',')
        print(io, "{experiment:", repr(run.experiment), ",run:", repr(run.run),
            ",scenario:", repr(run.scenario), ",seed:", run.seed,
            ",calibration:", repr(run.calibration), ",horizon:", run.horizon, ",quarters:[")
        for (index, path) in enumerate(run.paths)
            snapshot = load_snapshot(path)
            quarter = Int(snapshot["quarter"])
            quarter == index - 1 || error("Missing or repeated quarter at $path")
            snapshot["horizon"] == run.horizon || error("Inconsistent horizon at $path")
            snapshot["experiment_id"] == run.experiment && snapshot["run_id"] == run.run ||
                error("Unexpected run identity at $path")

            model = snapshot["model"]
            firms = model.firms
            firm_count = length(firms.ID)
            all(length(field) == firm_count for field in (
                firms.G_i, firms.Y_i, firms.N_i, firms.Pi_i, firms.L_i,
                firms.Q_s_i, firms.N_d_i, firms.Pi_e_i, firms.L_e_i,
                firms.P_i, firms.Q_i, firms.S_i,
            )) || error("Misaligned firm fields at $path")
            allunique(firms.ID) || error("Repeated firm ID at $path")
            all(1 <= sector <= length(sectors) for sector in firms.G_i) || error("Unknown firm sector at $path")

            gdp = Float64(last(model.data.real_gdp))
            unemployment = count(==(0), model.w_act.O_h) / length(model.w_act.O_h)
            isfinite(gdp) && isfinite(unemployment) || error("Nonfinite aggregate at $path")
            imports = model.rotw
            all(length(field) == length(sectors) for field in (imports.P_m, imports.Y_m, imports.Q_m)) ||
                error("Misaligned import fields at $path")
            index > 1 && print(io, ',')
            print(io, "{quarter:", quarter, ",gdp:", repr(gdp), ",unemployment:", repr(unemployment), ",firms:[")
            for i in eachindex(firms.ID)
                values = (
                    Float64(firms.Y_i[i]), Float64(firms.N_i[i]), Float64(firms.Pi_i[i]), Float64(firms.L_i[i]),
                    Float64(firms.Q_s_i[i]), Float64(firms.N_d_i[i]), Float64(firms.Pi_e_i[i]), Float64(firms.L_e_i[i]),
                    Float64(firms.P_i[i]), Float64(firms.Q_i[i]), Float64(firms.S_i[i]),
                )
                all(isfinite, values) || error("Nonfinite firm value at $path, firm $(firms.ID[i])")
                i > 1 && print(io, ',')
                print(io, '[', firms.ID[i], ',', firms.G_i[i], ',', join(repr.(values), ','), ']')
            end
            print(io, "],imports:[")
            for g in eachindex(imports.P_m)
                values = (Float64(imports.P_m[g]), Float64(imports.Y_m[g]), Float64(imports.Q_m[g]))
                all(isfinite, values) || error("Nonfinite import value at $path, sector $g")
                g > 1 && print(io, ',')
                print(io, '[', join(repr.(values), ','), ']')
            end
            print(io, "]}")
        end
        print(io, "]}")
    end
    print(io, "]};\n")
end
mv(temporary, output; force = true)

println("Wrote $(length(runs)) runs to $output")
