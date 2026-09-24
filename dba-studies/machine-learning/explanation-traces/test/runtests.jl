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

@testset "complete quarterly model snapshots" begin
    seed, horizon = 91, 2
    mktempdir() do folder
        final_model, paths = simulate_snapshots(
            PARAMETERS, INITIAL_CONDITIONS;
            horizon,
            seed,
            output_directory = joinpath(folder, "snapshots"),
            experiment_id = "test",
            run_id = "baseline-seed-$seed",
            scenario_id = "baseline",
        )

        @test length(paths) == horizon + 1
        snapshots = load_snapshot.(paths)
        @test [snapshot["quarter"] for snapshot in snapshots] == collect(0:horizon)
        @test all(snapshot -> snapshot["schema_version"] == SCHEMA_VERSION, snapshots)
        @test all(snapshot -> typeof(snapshot["model"]) === typeof(final_model), snapshots)
        @test state_equal(last(snapshots)["model"], final_model)

        open(joinpath(folder, "snapshots", "quarter-9999.jld2.tmp.jld2"), "w") do io
            write(io, "interrupted write")
        end
        @test snapshot_paths(joinpath(folder, "snapshots")) == paths
        partial_directory = joinpath(folder, "partial")
        mkpath(partial_directory)
        cp(first(paths), joinpath(partial_directory, basename(first(paths))))
        @test_throws ErrorException snapshot_paths(partial_directory)

        initial_deposit = first(snapshots)["model"].firms.D_i[1]
        final_model.firms.D_i[1] += 1
        @test load_snapshot(first(paths))["model"].firms.D_i[1] == initial_deposit
        @test_throws ErrorException save_snapshot(
            first(paths), final_model;
            experiment_id = "test", run_id = "duplicate", scenario_id = "baseline",
            seed, horizon, quarter = 0,
        )

        panel = firm_panel(paths; fields = [:Y_i, :credit_gap])
        matrix = firm_matrix(panel, :Y_i)
        @test size(matrix.values) == (length(unique(panel.firm_id)), horizon + 1)
        @test matrix.quarters == collect(0:horizon)
        @test all(matrix.sectors .== sort(matrix.sectors))
        @test nrow(panel) == sum(length(snapshot["model"].firms.ID) for snapshot in snapshots)

        transitions = firm_transition_panel(paths)
        @test all(ismissing, transitions[transitions.quarter .== 0, :employment_decision])
        first_firm = first(snapshots[2]["model"].firms.ID)
        previous_index = findfirst(==(first_firm), snapshots[1]["model"].firms.ID)
        current_index = findfirst(==(first_firm), snapshots[2]["model"].firms.ID)
        first_transition = only(
            transitions[(transitions.quarter .== 1) .& (transitions.firm_id .== first_firm), :employment_decision],
        )
        @test first_transition ==
            snapshots[2]["model"].firms.N_d_i[current_index] - snapshots[1]["model"].firms.N_i[previous_index]
        expected_bankruptcies = vcat(
            [
                (snapshot["model"].firms.D_i .< 0) .& (snapshot["model"].firms.E_i .< 0)
                    for snapshot in snapshots
            ]...
        )
        @test transitions.bankruptcy_trigger == expected_bankruptcies
        @test size(firm_matrix(transitions, :employment_decision_direction).values) == size(matrix.values)

        real_gdp = aggregate_series(paths, :real_gdp)
        @test real_gdp.quarter == collect(0:horizon)
        @test all(isfinite, real_gdp.value)
    end

    mktempdir() do folder
        Random.seed!(seed)
        normal_model = Bit.Model(deepcopy(PARAMETERS), deepcopy(INITIAL_CONDITIONS))
        Bit.run!(normal_model, horizon; parallel = false)
        recorded_model, _ = simulate_snapshots(
            PARAMETERS, INITIAL_CONDITIONS;
            horizon,
            seed,
            output_directory = joinpath(folder, "snapshots"),
            experiment_id = "test",
            run_id = "recorded-seed-$seed",
            scenario_id = "baseline",
        )
        @test state_equal(normal_model, recorded_model)
    end

    mktempdir() do folder
        specification = Dict(
            "experiment" => Dict(
                "id" => "test-quarterly-states",
                "research_question" => "How do firms change through time?",
                "calibration" => "AUSTRIA2010Q1",
                "horizon" => 1,
                "seeds" => [17],
                "shock" => "none",
            ),
            "scenarios" => [
                Dict("id" => "baseline", "role" => "baseline", "description" => "baseline"),
                Dict(
                    "id" => "lower-zeta-ltv",
                    "role" => "intervention",
                    "description" => "zeta_LTV x 0.5",
                    "changes" => [
                        Dict("parameter" => "zeta_LTV", "operation" => "multiply", "value" => 0.5),
                    ],
                ),
            ],
        )
        specification_path = joinpath(folder, "experiment.toml")
        open(specification_path, "w") do io
            TOML.print(io, specification)
        end

        output_root = joinpath(folder, "output")
        experiment_directory = generate_experiment(specification_path; output_root)
        runs = CSV.read(joinpath(experiment_directory, "runs.csv"), DataFrame)
        @test nrow(runs) == 2
        @test all(runs.success)
        @test all(runs.snapshots_written .== 2)
        @test all(runs.total_bytes .> 0)
        for run in eachrow(runs)
            paths = snapshot_paths(joinpath(experiment_directory, run.snapshot_directory))
            @test length(paths) == 2
            @test all(load_snapshot(path)["run_id"] == run.run_id for path in paths)
        end
        @test_throws ErrorException generate_experiment(specification_path; output_root)
    end
end
