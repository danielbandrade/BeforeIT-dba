import BeforeIT as Bit
using CSV
using DataFrames

const STRUCTURAL = Set(["G", "H_act", "H_inact", "J", "L", "S", "T", "T_max", "T_prime", "I_s"])

function source_usage(name, source_root)
    needle = "parameters[\"$name\"]"
    hits = String[]
    for (root, _, files) in walkdir(source_root), file in files
        endswith(file, ".jl") || continue
        path = joinpath(root, file)
        for (line, text) in enumerate(eachline(path))
            occursin(needle, text) && push!(hits, "$(relpath(path, dirname(source_root))):$line")
        end
    end
    return join(hits, "; ")
end

function inventory(parameters)
    rows = DataFrame(
        parameter = String[], type = String[], shape = String[], baseline = String[],
        classification = String[], screening_eligible = Bool[], source_usage = String[],
        review_note = String[],
    )
    source_root = normpath(joinpath(@__DIR__, "..", "..", "..", "src"))
    for name in sort!(collect(keys(parameters)))
        value = parameters[name]
        structural = name in STRUCTURAL
        scalar = value isa Number
        classification = structural ? "structural_dimension" : scalar ? "independent_continuous_candidate" : "jointly_constrained_group_candidate"
        note = structural ? "Fixed during sensitivity analysis" : scalar ? "Define an economic validity range before screening" : "Define a structure-preserving perturbation; do not vary cells independently"
        push!(rows, (
            name,
            string(typeof(value)),
            scalar ? "scalar" : join(size(value), "x"),
            scalar ? string(value) : "summary(min=$(minimum(value)), max=$(maximum(value)), mean=$(sum(value) / length(value)))",
            classification,
            !structural,
            source_usage(name, source_root),
            note,
        ))
    end
    return rows
end

if abspath(PROGRAM_FILE) == @__FILE__
    output = joinpath(@__DIR__, "parameter-inventory.csv")
    rows = inventory(Bit.AUSTRIA2010Q1.parameters)
    CSV.write(output, rows)
    @assert nrow(rows) == length(Bit.AUSTRIA2010Q1.parameters)
    @assert all(!isempty(rows.source_usage[i]) for i in 1:nrow(rows) if rows.screening_eligible[i])
    println("inventoried $(nrow(rows)) parameters ($(count(rows.screening_eligible)) screening candidates)")
    println("saved: $output")
end
