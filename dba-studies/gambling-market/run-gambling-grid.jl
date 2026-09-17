include(joinpath(@__DIR__, "run-paired-experiment.jl"))

using Distributions
using Statistics

const GRID_N_RUNS = parse(Int, get(ENV, "GAMBLING_GRID_N_RUNS", "20"))
const GRID_HORIZON = 16
const GRID_GAMBLING_SHARES = (0.02, 0.05, 0.1, 0.2)
const GRID_PARTICIPATION_SHARES = (0.1, 0.2, 0.4, 0.6)
const GRID_OWNER_SHARE = 0.1
const GRID_OUTPUT_PREFIX = get(ENV, "GAMBLING_GRID_OUTPUT_PREFIX", "gambling-grid")

const GRID_RESULTS_OUTPUT = joinpath(DATA_DIR, "$(GRID_OUTPUT_PREFIX)-results.csv")
const GRID_TRACE_OUTPUT = joinpath(DATA_DIR, "$(GRID_OUTPUT_PREFIX)-period-trace.csv")
const GRID_SUMMARY_OUTPUT = joinpath(DATA_DIR, "$(GRID_OUTPUT_PREFIX)-cell-summary.csv")

function participant_order(parameters, run)
    rng = MersenneTwister(SELECTION_SEED + run)
    number_of_firms = Int(sum(parameters["I_s"]))
    number_of_active_workers = Int(parameters["H_act"]) - number_of_firms - 1
    number_of_inactive_workers = Int(parameters["H_inact"])
    number_of_workers = number_of_active_workers + number_of_inactive_workers

    return (
        worker_order = randperm(rng, number_of_workers),
        owner_order = randperm(rng, number_of_firms),
        number_of_active_workers = number_of_active_workers,
        number_of_workers = number_of_workers,
        number_of_firms = number_of_firms,
    )
end

function participant_ids(order, worker_share)
    number_of_gamblers = max(1, round(Int, worker_share * order.number_of_workers))
    selected_workers = @view(order.worker_order[1:number_of_gamblers])
    active_ids = sort(
        [
            id for id in selected_workers if id <= order.number_of_active_workers
        ]
    )
    inactive_ids = sort(
        [
            id - order.number_of_active_workers for id in selected_workers if
                id > order.number_of_active_workers
        ]
    )

    number_of_owners = max(1, round(Int, GRID_OWNER_SHARE * order.number_of_firms))
    owner_ids = sort(order.owner_order[1:number_of_owners])
    return active_ids, inactive_ids, owner_ids
end

function scenario_result(
        model,
        trace_rows,
        run,
        scenario_id,
        simulation_seed,
        gambling_share,
        participation_share,
        active_ids,
        inactive_ids,
        owner_ids,
    )
    periods = trace_rows[2:end]
    period_mean(field) = mean(getproperty(row, field) for row in periods)
    pre_transfer_income = sum(row.household_income_pre_transfer for row in periods)
    cumulative_gambling_volume = sum(row.gambling_volume for row in periods)

    return (
        run = run,
        scenario_id = scenario_id,
        simulation_seed = simulation_seed,
        gambling_income_share = gambling_share,
        worker_participation_share = participation_share,
        owner_recipient_share = GRID_OWNER_SHARE,
        realized_worker_participation_share =
            (length(active_ids) + length(inactive_ids)) /
            (length(model.w_act) + length(model.w_inact)),
        realized_owner_recipient_share = length(owner_ids) / length(model.firms),
        active_gamblers = length(active_ids),
        inactive_gamblers = length(inactive_ids),
        recipient_owners = length(owner_ids),
        realized_transfer_intensity =
            cumulative_gambling_volume / pre_transfer_income,
        cumulative_gambling_volume = cumulative_gambling_volume,
        mean_real_gdp = period_mean(:real_gdp),
        final_real_gdp = model.data.real_gdp[end],
        mean_household_income_gini = period_mean(:household_income_gini),
        final_household_income_gini = periods[end].household_income_gini,
        mean_real_household_consumption = period_mean(:real_household_consumption),
        mean_real_imports = period_mean(:real_imports),
        mean_domestic_purchase_expenditure =
            period_mean(:household_domestic_purchase_expenditure),
        mean_imported_purchase_expenditure =
            period_mean(:household_imported_purchase_expenditure),
        mean_unfilled_purchase_demand = period_mean(:household_unfilled_purchase_demand),
        mean_firm_sales = period_mean(:firm_sales),
        mean_firm_output = period_mean(:firm_output_realized),
        mean_firm_profit = period_mean(:firm_profit),
        mean_firm_employment = period_mean(:firm_employment_realized),
        mean_firm_investment = period_mean(:firm_investment_realized),
    )
end

function append_scenario!(
        result_rows,
        trace_rows,
        run,
        scenario_id,
        base_parameters,
        base_initial_conditions,
        gambling_share,
        participation_share,
        active_ids,
        inactive_ids,
        owner_ids,
        simulation_seed,
    )
    model, scenario_trace = run_scenario(
        run,
        scenario_id,
        base_parameters,
        base_initial_conditions,
        gambling_share,
        active_ids,
        inactive_ids,
        owner_ids,
        simulation_seed;
        horizon = GRID_HORIZON,
    )
    append!(
        trace_rows,
        [
            merge(
                    row,
                    (
                        scenario_id = scenario_id,
                        worker_participation_share = participation_share,
                        owner_recipient_share = GRID_OWNER_SHARE,
                        realized_worker_participation_share =
                        (length(active_ids) + length(inactive_ids)) /
                        (
                            Int(base_parameters["H_act"]) - Int(sum(base_parameters["I_s"])) - 1 +
                            Int(base_parameters["H_inact"])
                        ),
                        realized_owner_recipient_share =
                        length(owner_ids) / Int(sum(base_parameters["I_s"])),
                    ),
                ) for row in scenario_trace
        ],
    )
    push!(
        result_rows,
        scenario_result(
            model,
            scenario_trace,
            run,
            scenario_id,
            simulation_seed,
            gambling_share,
            participation_share,
            active_ids,
            inactive_ids,
            owner_ids,
        ),
    )
    return
end

function cell_summary(results)
    metrics = (
        :mean_real_gdp,
        :final_real_gdp,
        :mean_household_income_gini,
        :final_household_income_gini,
        :mean_real_household_consumption,
        :mean_real_imports,
        :mean_domestic_purchase_expenditure,
        :mean_imported_purchase_expenditure,
        :mean_unfilled_purchase_demand,
        :mean_firm_sales,
        :mean_firm_output,
        :mean_firm_profit,
        :mean_firm_employment,
        :mean_firm_investment,
    )
    baseline = results[results.scenario_id .== "baseline", :]
    baseline_by_run = Dict(row.run => row for row in eachrow(baseline))
    rows = NamedTuple[]

    for gambling_share in GRID_GAMBLING_SHARES
        for participation_share in GRID_PARTICIPATION_SHARES
            cell = results[
                (results.gambling_income_share .== gambling_share) .&
                    (results.worker_participation_share .== participation_share),
                :,
            ]
            for metric in metrics
                treatment_values = Float64[getproperty(row, metric) for row in eachrow(cell)]
                baseline_values = Float64[
                    getproperty(baseline_by_run[row.run], metric) for row in eachrow(cell)
                ]
                deltas = treatment_values - baseline_values
                n = length(deltas)
                standard_error = std(deltas) / sqrt(n)
                critical_value = quantile(TDist(n - 1), 0.975)
                mean_delta = mean(deltas)
                push!(
                    rows,
                    (
                        gambling_income_share = gambling_share,
                        worker_participation_share = participation_share,
                        metric = String(metric),
                        runs = n,
                        mean_baseline = mean(baseline_values),
                        mean_treatment = mean(treatment_values),
                        mean_delta = mean_delta,
                        median_delta = median(deltas),
                        standard_error = standard_error,
                        ci_lower = mean_delta - critical_value * standard_error,
                        ci_upper = mean_delta + critical_value * standard_error,
                        positive_share = mean(deltas .> 0),
                    ),
                )
            end
        end
    end
    return DataFrame(rows)
end

function validate_benchmark_cell(trace)
    benchmark_path = joinpath(DATA_DIR, "paired-period-trace.csv")
    isfile(benchmark_path) || return
    benchmark = CSV.read(benchmark_path, DataFrame)
    benchmark = benchmark[benchmark.run .<= GRID_N_RUNS, :]
    current_cell = trace[
        (trace.gambling_income_share .== GAMBLING_SHARE) .&
            (trace.worker_participation_share .== PARTICIPATION_SHARE),
        :,
    ]
    grid_subset = vcat(
        trace[trace.scenario_id .== "baseline", :],
        current_cell;
        cols = :union,
    )
    sort!(grid_subset, [:run, :gambling_income_share, :period])
    sort!(benchmark, [:run, :gambling_income_share, :period])
    @assert nrow(grid_subset) == nrow(benchmark)

    for column in Symbol.(intersect(names(benchmark), names(grid_subset)))
        column == :scenario && continue
        left = benchmark[!, column]
        right = grid_subset[!, column]
        if eltype(left) <: Number
            @assert all(isapprox.(left, right; atol = 1.0e-10, rtol = 1.0e-10))
        else
            @assert left == right
        end
    end
    println("benchmark validation passed for 2% x 10%")
    return
end

function validate_period_zero(trace)
    outcomes = (
        :real_gdp,
        :household_income_gini,
        :household_consumption_desired,
        :household_consumption_realized,
        :household_housing_desired,
        :household_housing_realized,
        :firm_sales,
        :firm_profit,
        :real_imports,
    )
    period_zero = trace[trace.period .== 0, :]
    for run in 1:GRID_N_RUNS
        run_rows = period_zero[period_zero.run .== run, :]
        baseline = run_rows[run_rows.scenario_id .== "baseline", :]
        @assert nrow(baseline) == 1
        for outcome in outcomes
            @assert all(
                isapprox.(run_rows[!, outcome], baseline[1, outcome]; atol = 1.0e-10),
            )
        end
    end
    return
end

function grid_main()
    base_parameters = Bit.AUSTRIA2010Q1.parameters
    base_initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    result_rows = NamedTuple[]
    trace_rows = NamedTuple[]

    for run in 1:GRID_N_RUNS
        order = participant_order(base_parameters, run)
        baseline_active_ids, baseline_inactive_ids, baseline_owner_ids =
            participant_ids(order, PARTICIPATION_SHARE)
        simulation_seed = SIMULATION_SEED + run
        append_scenario!(
            result_rows,
            trace_rows,
            run,
            "baseline",
            base_parameters,
            base_initial_conditions,
            0.0,
            PARTICIPATION_SHARE,
            baseline_active_ids,
            baseline_inactive_ids,
            baseline_owner_ids,
            simulation_seed,
        )

        previous_workers = Set{Int}()
        for participation_share in GRID_PARTICIPATION_SHARES
            active_ids, inactive_ids, owner_ids =
                participant_ids(order, participation_share)
            selected_workers = Set(
                [
                    active_ids
                    order.number_of_active_workers .+ inactive_ids
                ]
            )
            @assert issubset(previous_workers, selected_workers)
            @assert owner_ids == baseline_owner_ids
            previous_workers = selected_workers
            for gambling_share in GRID_GAMBLING_SHARES
                scenario_id = "g$(round(Int, 100 * gambling_share))_p$(round(Int, 100 * participation_share))"
                append_scenario!(
                    result_rows,
                    trace_rows,
                    run,
                    scenario_id,
                    base_parameters,
                    base_initial_conditions,
                    gambling_share,
                    participation_share,
                    active_ids,
                    inactive_ids,
                    owner_ids,
                    simulation_seed,
                )
            end
        end
        println("completed grid run $run/$GRID_N_RUNS")
    end

    results = DataFrame(result_rows)
    trace = DataFrame(trace_rows)
    expected_scenarios = 1 + length(GRID_GAMBLING_SHARES) * length(GRID_PARTICIPATION_SHARES)
    @assert nrow(results) == GRID_N_RUNS * expected_scenarios
    @assert nrow(trace) == GRID_N_RUNS * expected_scenarios * (GRID_HORIZON + 1)
    @assert all(isapprox.(trace.transfer_residual, 0.0; atol = 1.0e-8))
    @assert all((0.0 .<= trace.household_income_gini) .& (trace.household_income_gini .<= 1.0))
    @assert all(isapprox.(trace.real_gdp_expenditure_residual, 0.0; atol = 1.0e-6))
    @assert all(isapprox.(trace.nominal_gdp_expenditure_residual, 0.0; atol = 1.0e-6))
    @assert all(
        iszero,
        trace.gambling_volume[trace.scenario_id .== "baseline"],
    )
    validate_benchmark_cell(trace)
    validate_period_zero(trace)

    summary = cell_summary(results)
    mkpath(DATA_DIR)
    CSV.write(GRID_RESULTS_OUTPUT, results)
    CSV.write(GRID_TRACE_OUTPUT, trace)
    CSV.write(GRID_SUMMARY_OUTPUT, summary)
    println("saved: $GRID_RESULTS_OUTPUT")
    println("saved: $GRID_TRACE_OUTPUT")
    return println("saved: $GRID_SUMMARY_OUTPUT")
end

if abspath(PROGRAM_FILE) == @__FILE__
    grid_main()
end
