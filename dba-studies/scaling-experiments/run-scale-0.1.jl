import BeforeIT as Bit
using Dates
using JLD2
using Random

const SCALE = 1
const HORIZON = 12
const SEED = 1234
const CALIBRATION_DATE = DateTime(2010, 3, 31)
const OUTPUT = joinpath(@__DIR__, "scale-1-results.jld2")

println("Calibrating Italy at scale $SCALE...")
parameters, initial_conditions = Bit.get_params_and_initial_conditions(
    Bit.ITALY_CALIBRATION,
    CALIBRATION_DATE;
    scale = SCALE,
)

println("firms: ", sum(parameters["I_s"]))
println("active households: ", parameters["H_act"])
println("inactive households: ", parameters["H_inact"])

Random.seed!(SEED)
println("Initializing model...")
model = Bit.Model(parameters, initial_conditions)

println("Running $HORIZON quarters...")
elapsed = @elapsed Bit.run!(model, HORIZON; parallel = false)

metadata = Dict(
    "country" => "Italy",
    "calibration_date" => string(Date(CALIBRATION_DATE)),
    "scale" => SCALE,
    "horizon" => HORIZON,
    "seed" => SEED,
    "simulation_seconds" => elapsed,
)
JLD2.save(OUTPUT, "data", model.data, "metadata", metadata)

@assert length(model.data.collection_time) == HORIZON + 1
println("Finished in $(round(elapsed; digits = 2)) seconds")
println("final real GDP: ", model.data.real_gdp[end])
println("saved: ", OUTPUT)
