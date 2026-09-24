using CSV
using DataFrames
using Random
using Test
using TOML

import BeforeIT as Bit

include(joinpath(@__DIR__, "..", "src", "explanation_traces.jl"))
using .ExplanationTraces

const PARAMETERS = Bit.AUSTRIA2010Q1.parameters
const INITIAL_CONDITIONS = Bit.AUSTRIA2010Q1.initial_conditions

function metadata(seed, horizon; role = "baseline", scenario = "baseline")
    return Dict{String, Any}(
        "experiment_id" => "test",
        "research_question" => "test",
        "calibration_id" => "AUSTRIA2010Q1",
        "run_id" => "$scenario-seed-$seed",
        "scenario_id" => scenario,
        "role" => role,
        "pair_id" => "seed-$seed",
        "seed" => seed,
        "horizon" => horizon,
    )
end

@testset "explanation traces" begin
    seed, horizon = 91, 2
    trace, traced_model = simulate_trace(
        PARAMETERS, INITIAL_CONDITIONS; horizon, seed, metadata = metadata(seed, horizon),
    )

    @test length(trace["snapshots"]) == horizon + 1
    @test !isempty(trace["events"])
    @test validate_trace(trace; horizon) === trace

    inventory_model = Bit.Model(deepcopy(PARAMETERS), deepcopy(INITIAL_CONDITIONS))
    inventory = field_inventory(inventory_model)
    expected_fields = sum(
        length(fieldnames(typeof(getfield(inventory_model, component)))) for component in
            (:prop, :w_act, :w_inact, :firms, :bank, :cb, :gov, :rotw, :agg, :data)
    )
    @test nrow(inventory) == expected_fields
    @test count(==("runtime_excluded"), inventory.storage_class) == 6

    Random.seed!(seed)
    normal_model = Bit.Model(deepcopy(PARAMETERS), deepcopy(INITIAL_CONDITIONS))
    initial_lengths = Dict("Y" => length(normal_model.agg.Y), "pi_" => length(normal_model.agg.pi_))
    Bit.run!(normal_model, horizon; parallel = false)
    @test isequal(snapshot(normal_model, horizon, initial_lengths), last(trace["snapshots"]))

    trace_again, _ = simulate_trace(
        PARAMETERS, INITIAL_CONDITIONS; horizon, seed, metadata = metadata(seed, horizon),
    )
    @test isequal(trace_again["snapshots"], trace["snapshots"])
    @test isequal(trace_again["events"], trace["events"])

    first_deposit = trace["snapshots"][1]["firms"]["D_i"][1]
    traced_model.firms.D_i[1] += 1
    @test trace["snapshots"][1]["firms"]["D_i"][1] == first_deposit

    expected_stages = [
        :start, :after_financing, :after_expectations, :after_firm_decisions,
        :after_credit_market, :after_labour_market, :after_production,
        :after_budgets, :after_goods_market, :after_accounting,
    ]
    Random.seed!(seed)
    observed_model = Bit.Model(deepcopy(PARAMETERS), deepcopy(INITIAL_CONDITIONS))
    observed_stages = Symbol[]
    Bit.step!(observed_model; parallel = false, observer = (stage, _) -> push!(observed_stages, stage))
    @test observed_stages == expected_stages

    mktempdir() do folder
        trace_path = joinpath(folder, "trace.jld2")
        save_trace(trace_path, trace)
        @test isequal(load_trace(trace_path), trace)
        @test_throws ErrorException save_trace(trace_path, trace)

        specification = Dict(
            "experiment" => Dict(
                "id" => "test-experiment",
                "research_question" => "Does tighter firm loan-to-value reduce credit and GDP?",
                "calibration" => "AUSTRIA2010Q1",
                "horizon" => 2,
                "seeds" => [17],
                "shock" => "none",
                "outcomes" => ["real_gdp"],
                "mechanisms" => ["credit_allocation"],
            ),
            "scenarios" => [
                Dict("id" => "baseline", "role" => "baseline", "description" => "baseline"),
                Dict(
                    "id" => "lower-zeta-ltv",
                    "role" => "intervention",
                    "description" => "zeta_LTV x 0.5",
                    "changes" => [Dict("parameter" => "zeta_LTV", "operation" => "multiply", "value" => 0.5)],
                ),
            ],
        )
        specification_path = joinpath(folder, "experiment.toml")
        open(specification_path, "w") do io
            TOML.print(io, specification)
        end

        experiment_dir = generate_experiment(specification_path; output_root = joinpath(folder, "output"))
        runs = CSV.read(joinpath(experiment_dir, "runs.csv"), DataFrame)
        periods = CSV.read(joinpath(experiment_dir, "derived", "periods.csv"), DataFrame)
        firms = CSV.read(joinpath(experiment_dir, "derived", "firms.csv"), DataFrame)
        households = CSV.read(joinpath(experiment_dir, "derived", "households.csv"), DataFrame)
        paired = CSV.read(joinpath(experiment_dir, "derived", "paired-differences.csv"), DataFrame)

        @test nrow(runs) == 2
        @test all(runs.success)
        @test nrow(periods) == 2 * (2 + 1)
        @test nrow(firms) == 2 * (2 + 1) * length(inventory_model.firms.ID)
        household_count = length(inventory_model.w_act.ID) + length(inventory_model.w_inact.ID) +
            length(inventory_model.firms.ID) + 1
        @test nrow(households) == 2 * (2 + 1) * household_count
        @test nrow(paired) == 2 + 1
        @test isfile(joinpath(experiment_dir, "derived", "explanation-summary.md"))
        @test_throws ErrorException generate_experiment(specification_path; output_root = joinpath(folder, "output"))
    end
end
