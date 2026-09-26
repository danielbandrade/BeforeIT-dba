include(joinpath(@__DIR__, "..", "machine-learning", "explanation-traces", "src", "explanation_traces.jl"))
using .ExplanationTraces: load_snapshot

const EXPERIMENT = "consumption-shock-80-quarterly-states-v3"
const RUN = "consumption-shock-80-percent-seed-4101"
const SOURCE = joinpath(
    @__DIR__, "..", "machine-learning", "explanation-traces", "experiments",
    EXPERIMENT, "snapshots", RUN,
)

paths = sort(filter(path -> occursin(r"^quarter-\d{4}\.jld2$", basename(path)), readdir(SOURCE; join = true)))
isempty(paths) && error("No quarterly snapshots found in $SOURCE")

output = joinpath(@__DIR__, "data.js")
temporary = output * ".tmp"
open(temporary, "w") do io
    print(io, "window.BEFOREIT_TRACE={experiment:", repr(EXPERIMENT), ",run:", repr(RUN), ",quarters:[")
    horizon = nothing
    for (index, path) in enumerate(paths)
        snapshot = load_snapshot(path)
        quarter = Int(snapshot["quarter"])
        quarter == index - 1 || error("Missing or repeated quarter at $path")
        horizon === nothing && (horizon = Int(snapshot["horizon"]))
        snapshot["horizon"] == horizon || error("Inconsistent horizon at $path")
        snapshot["experiment_id"] == EXPERIMENT && snapshot["run_id"] == RUN || error("Unexpected run at $path")

        model = snapshot["model"]
        firms = model.firms
        firm_count = length(firms.ID)
        all(length(field) == firm_count for field in (
            firms.G_i, firms.Y_i, firms.N_i, firms.Pi_i, firms.L_i,
            firms.Q_s_i, firms.N_d_i, firms.Pi_e_i, firms.L_e_i,
        )) ||
            error("Misaligned firm fields at $path")
        allunique(firms.ID) || error("Repeated firm ID at $path")

        gdp = Float64(last(model.data.real_gdp))
        unemployment = count(==(0), model.w_act.O_h) / length(model.w_act.O_h)
        isfinite(gdp) && isfinite(unemployment) || error("Nonfinite aggregate at $path")
        index > 1 && print(io, ',')
        print(io, "{quarter:", quarter, ",gdp:", repr(gdp), ",unemployment:", repr(unemployment), ",firms:[")
        for i in eachindex(firms.ID)
            values = (
                Float64(firms.Y_i[i]), Float64(firms.N_i[i]), Float64(firms.Pi_i[i]), Float64(firms.L_i[i]),
                Float64(firms.Q_s_i[i]), Float64(firms.N_d_i[i]), Float64(firms.Pi_e_i[i]), Float64(firms.L_e_i[i]),
            )
            all(isfinite, values) || error("Nonfinite firm value at $path, firm $(firms.ID[i])")
            i > 1 && print(io, ',')
            print(io, '[', firms.ID[i], ',', firms.G_i[i], ',', join(repr.(values), ','), ']')
        end
        print(io, "]}")
    end
    length(paths) == horizon + 1 || error("Expected $(horizon + 1) quarters, found $(length(paths))")
    print(io, "]};\n")
end
mv(temporary, output; force = true)

println("Wrote $(length(paths)) quarters to $output")
