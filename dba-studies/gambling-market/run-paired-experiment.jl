import BeforeIT as Bit

using CSV
using DataFrames
using Random

const N_RUNS = 20
const HORIZON = 16
const GAMBLING_SHARE = 0.02
const PARTICIPATION_SHARE = 0.1
const SELECTION_SEED = 1_000
const SIMULATION_SEED = 10_000
const DATA_DIR = joinpath(@__DIR__, "data")
const OUTPUT = joinpath(DATA_DIR, "paired-results.csv")
const GDP_OUTPUT = joinpath(DATA_DIR, "paired-gdp-paths.csv")
const TRACE_OUTPUT = joinpath(DATA_DIR, "paired-period-trace.csv")

function gini_coefficient(values)
    sorted_values = sort(values)
    total = sum(sorted_values)
    iszero(total) && return 0.0

    n = length(sorted_values)
    return sum(
        (2 * index - n - 1) * value for
            (index, value) in enumerate(sorted_values)
    ) / (n * total)
end

@assert gini_coefficient(fill(1.0, 3)) == 0.0
@assert isapprox(gini_coefficient([0.0, 0.0, 1.0]), 2 / 3)

function participant_ids(parameters, run)
    rng = MersenneTwister(SELECTION_SEED + run)

    number_of_firms = Int(sum(parameters["I_s"]))
    number_of_active_workers = Int(parameters["H_act"]) - number_of_firms - 1
    number_of_inactive_workers = Int(parameters["H_inact"])
    number_of_workers = number_of_active_workers + number_of_inactive_workers

    number_of_gamblers =
        max(1, round(Int, PARTICIPATION_SHARE * number_of_workers))
    selected_workers = randperm(rng, number_of_workers)[1:number_of_gamblers]

    active_ids = sort(
        [
            id for id in selected_workers if id <= number_of_active_workers
        ]
    )
    inactive_ids = sort(
        [
            id - number_of_active_workers for id in selected_workers if
                id > number_of_active_workers
        ]
    )

    number_of_owners =
        max(1, round(Int, PARTICIPATION_SHARE * number_of_firms))
    owner_ids = sort(randperm(rng, number_of_firms)[1:number_of_owners])

    return active_ids, inactive_ids, owner_ids
end

function period_trace(
        model,
        run,
        scenario,
        simulation_seed,
        period,
        active_gambler_mask,
        inactive_gambler_mask,
        recipient_owner_mask,
    )
    w_act, w_inact, firms, bank =
        model.w_act, model.w_inact, model.firms, model.bank
    data = model.data

    if iszero(period)
        income_act_pre = copy(w_act.Y_h)
        income_inact_pre = copy(w_inact.Y_h)
        income_owners_pre = copy(firms.Y_h)
        stakes_act = zeros(length(w_act))
        stakes_inact = zeros(length(w_inact))
        receipts_owners = zeros(length(firms))
    else
        income_act_pre = Bit.households_income_act(model)
        income_inact_pre = Bit.households_income_inact(model)
        income_owners_pre = Bit.households_income_firms(model)
        stakes_act, stakes_inact, receipts_owners = Bit.gambling_transfers(
            model;
            income_act = income_act_pre,
            income_inact = income_inact_pre,
        )

        @assert isapprox(w_act.Y_h, income_act_pre - stakes_act)
        @assert isapprox(w_inact.Y_h, income_inact_pre - stakes_inact)
        @assert isapprox(firms.Y_h, income_owners_pre + receipts_owners)
    end

    gamblers(active_values, inactive_values) =
        sum(active_values[active_gambler_mask]) +
        sum(inactive_values[inactive_gambler_mask])
    other_workers(active_values, inactive_values) =
        sum(active_values) + sum(inactive_values) -
        gamblers(active_values, inactive_values)
    recipients(values) = sum(values[recipient_owner_mask])
    other_owners(values) = sum(values) - recipients(values)

    active_worker_stakes = sum(stakes_act)
    inactive_worker_stakes = sum(stakes_inact)
    owner_receipts = sum(receipts_owners)
    gambling_volume = data.gambling_volume[end]

    @assert isapprox(
        active_worker_stakes + inactive_worker_stakes,
        gambling_volume,
    )
    @assert isapprox(owner_receipts, gambling_volume)
    @assert period == length(data.real_gdp) - 1

    household_consumption_desired =
        sum(w_act.C_d_h) + sum(w_inact.C_d_h) + sum(firms.C_d_h) + bank.C_d_h
    household_consumption_realized =
        sum(w_act.C_h) + sum(w_inact.C_h) + sum(firms.C_h) + bank.C_h
    household_housing_desired =
        sum(w_act.I_d_h) + sum(w_inact.I_d_h) + sum(firms.I_d_h) + bank.I_d_h
    household_housing_realized =
        sum(w_act.I_h) + sum(w_inact.I_h) + sum(firms.I_h) + bank.I_h
    household_income_pre_transfer =
        sum(income_act_pre) + sum(income_inact_pre) + sum(income_owners_pre) + bank.Y_h
    household_income_post_transfer =
        sum(w_act.Y_h) + sum(w_inact.Y_h) + sum(firms.Y_h) + bank.Y_h
    household_income_gini = gini_coefficient(
        [
            w_act.Y_h
            w_inact.Y_h
            firms.Y_h
            bank.Y_h
        ]
    )

    function purchase_groups(values)
        return (
            gambler = values[1],
            other_worker = values[2],
            recipient_owner = values[3],
            other_owner = values[4],
            bank = values[5],
        )
    end

    domestic_quantity = purchase_groups(model.agg.household_domestic_purchase_quantity)
    imported_quantity = purchase_groups(model.agg.household_imported_purchase_quantity)
    domestic_expenditure =
        purchase_groups(model.agg.household_domestic_purchase_expenditure)
    imported_expenditure =
        purchase_groups(model.agg.household_imported_purchase_expenditure)
    unfilled_demand = purchase_groups(model.agg.household_unfilled_purchase_demand)

    if !iszero(period)
        fulfilled_purchase_expenditure =
            sum(model.agg.household_domestic_purchase_expenditure) +
            sum(model.agg.household_imported_purchase_expenditure)
        @assert isapprox(
            fulfilled_purchase_expenditure,
            household_consumption_realized + household_housing_realized;
            atol = 1.0e-8,
        )
        @assert isapprox(
            fulfilled_purchase_expenditure +
                sum(model.agg.household_unfilled_purchase_demand),
            household_consumption_desired + household_housing_desired;
            atol = 1.0e-8,
        )
    end

    real_gdp_expenditure_residual =
        data.real_gdp[end] - data.real_household_consumption[end] -
        data.real_government_consumption[end] - data.real_capitalformation[end] -
        data.real_exports[end] + data.real_imports[end]
    nominal_gdp_expenditure_residual =
        data.nominal_gdp[end] - data.nominal_household_consumption[end] -
        data.nominal_government_consumption[end] - data.nominal_capitalformation[end] -
        data.nominal_exports[end] + data.nominal_imports[end]

    return (
        run = run,
        scenario = scenario,
        simulation_seed = simulation_seed,
        period = period,
        gambling_income_share = model.prop.gambling_income_share,
        active_gamblers = count(active_gambler_mask),
        inactive_gamblers = count(inactive_gambler_mask),
        recipient_owners = count(recipient_owner_mask),
        active_worker_stakes = active_worker_stakes,
        inactive_worker_stakes = inactive_worker_stakes,
        owner_receipts = owner_receipts,
        transfer_residual = active_worker_stakes + inactive_worker_stakes - owner_receipts,
        gambling_volume = gambling_volume,
        gambler_income_pre = gamblers(income_act_pre, income_inact_pre),
        gambler_income_post = gamblers(w_act.Y_h, w_inact.Y_h),
        other_worker_income = other_workers(w_act.Y_h, w_inact.Y_h),
        recipient_owner_income_pre = recipients(income_owners_pre),
        recipient_owner_income_post = recipients(firms.Y_h),
        other_owner_income = other_owners(firms.Y_h),
        household_income_pre_transfer = household_income_pre_transfer,
        household_income_post_transfer = household_income_post_transfer,
        household_income_gini = household_income_gini,
        gambler_consumption_desired = gamblers(w_act.C_d_h, w_inact.C_d_h),
        gambler_consumption_realized = gamblers(w_act.C_h, w_inact.C_h),
        other_worker_consumption_desired = other_workers(w_act.C_d_h, w_inact.C_d_h),
        other_worker_consumption_realized = other_workers(w_act.C_h, w_inact.C_h),
        recipient_owner_consumption_desired = recipients(firms.C_d_h),
        recipient_owner_consumption_realized = recipients(firms.C_h),
        other_owner_consumption_desired = other_owners(firms.C_d_h),
        other_owner_consumption_realized = other_owners(firms.C_h),
        gambler_housing_desired = gamblers(w_act.I_d_h, w_inact.I_d_h),
        gambler_housing_realized = gamblers(w_act.I_h, w_inact.I_h),
        other_worker_housing_desired = other_workers(w_act.I_d_h, w_inact.I_d_h),
        other_worker_housing_realized = other_workers(w_act.I_h, w_inact.I_h),
        recipient_owner_housing_desired = recipients(firms.I_d_h),
        recipient_owner_housing_realized = recipients(firms.I_h),
        other_owner_housing_desired = other_owners(firms.I_d_h),
        other_owner_housing_realized = other_owners(firms.I_h),
        gambler_deposits = gamblers(w_act.D_h, w_inact.D_h),
        other_worker_deposits = other_workers(w_act.D_h, w_inact.D_h),
        recipient_owner_deposits = recipients(firms.D_h),
        other_owner_deposits = other_owners(firms.D_h),
        household_consumption_desired = household_consumption_desired,
        household_consumption_realized = household_consumption_realized,
        household_housing_desired = household_housing_desired,
        household_housing_realized = household_housing_realized,
        household_domestic_purchase_quantity =
            sum(model.agg.household_domestic_purchase_quantity),
        household_imported_purchase_quantity =
            sum(model.agg.household_imported_purchase_quantity),
        household_domestic_purchase_expenditure =
            sum(model.agg.household_domestic_purchase_expenditure),
        household_imported_purchase_expenditure =
            sum(model.agg.household_imported_purchase_expenditure),
        household_unfilled_purchase_demand =
            sum(model.agg.household_unfilled_purchase_demand),
        gambler_domestic_purchase_quantity = domestic_quantity.gambler,
        gambler_imported_purchase_quantity = imported_quantity.gambler,
        gambler_domestic_purchase_expenditure = domestic_expenditure.gambler,
        gambler_imported_purchase_expenditure = imported_expenditure.gambler,
        gambler_unfilled_purchase_demand = unfilled_demand.gambler,
        other_worker_domestic_purchase_quantity = domestic_quantity.other_worker,
        other_worker_imported_purchase_quantity = imported_quantity.other_worker,
        other_worker_domestic_purchase_expenditure = domestic_expenditure.other_worker,
        other_worker_imported_purchase_expenditure = imported_expenditure.other_worker,
        other_worker_unfilled_purchase_demand = unfilled_demand.other_worker,
        recipient_owner_domestic_purchase_quantity = domestic_quantity.recipient_owner,
        recipient_owner_imported_purchase_quantity = imported_quantity.recipient_owner,
        recipient_owner_domestic_purchase_expenditure = domestic_expenditure.recipient_owner,
        recipient_owner_imported_purchase_expenditure = imported_expenditure.recipient_owner,
        recipient_owner_unfilled_purchase_demand = unfilled_demand.recipient_owner,
        other_owner_domestic_purchase_quantity = domestic_quantity.other_owner,
        other_owner_imported_purchase_quantity = imported_quantity.other_owner,
        other_owner_domestic_purchase_expenditure = domestic_expenditure.other_owner,
        other_owner_imported_purchase_expenditure = imported_expenditure.other_owner,
        other_owner_unfilled_purchase_demand = unfilled_demand.other_owner,
        bank_domestic_purchase_quantity = domestic_quantity.bank,
        bank_imported_purchase_quantity = imported_quantity.bank,
        bank_domestic_purchase_expenditure = domestic_expenditure.bank,
        bank_imported_purchase_expenditure = imported_expenditure.bank,
        bank_unfilled_purchase_demand = unfilled_demand.bank,
        firm_output_desired = sum(firms.Q_s_i),
        firm_output_realized = sum(firms.Y_i),
        firm_sales = sum(firms.Q_i),
        firm_revenue = sum(firms.P_i .* firms.Q_i),
        firm_profit = sum(firms.Pi_i),
        firm_employment_desired = sum(firms.N_d_i),
        firm_employment_realized = sum(firms.N_i),
        firm_investment_desired = sum(firms.I_d_i),
        firm_investment_realized = sum(firms.I_i),
        firm_credit_desired = sum(firms.DL_d_i),
        firm_credit_realized = sum(firms.DL_i),
        firm_capital_stock = sum(firms.K_i),
        firm_material_stock = sum(firms.M_i),
        firm_finished_goods_stock = sum(firms.S_i),
        firm_deposits = sum(firms.D_i),
        firm_loans = sum(firms.L_i),
        nominal_gdp = data.nominal_gdp[end],
        real_gdp = data.real_gdp[end],
        nominal_gva = data.nominal_gva[end],
        real_gva = data.real_gva[end],
        nominal_household_consumption = data.nominal_household_consumption[end],
        real_household_consumption = data.real_household_consumption[end],
        nominal_government_consumption = data.nominal_government_consumption[end],
        real_government_consumption = data.real_government_consumption[end],
        nominal_capitalformation = data.nominal_capitalformation[end],
        real_capitalformation = data.real_capitalformation[end],
        nominal_exports = data.nominal_exports[end],
        real_exports = data.real_exports[end],
        nominal_imports = data.nominal_imports[end],
        real_imports = data.real_imports[end],
        nominal_gdp_expenditure_residual = nominal_gdp_expenditure_residual,
        real_gdp_expenditure_residual = real_gdp_expenditure_residual,
    )
end

function run_scenario(
        run,
        scenario,
        base_parameters,
        base_initial_conditions,
        gambling_share,
        active_ids,
        inactive_ids,
        owner_ids,
        simulation_seed,
        ;
        horizon = HORIZON,
    )
    parameters = copy(base_parameters)
    initial_conditions = copy(base_initial_conditions)

    parameters["gambling_income_share"] = gambling_share
    initial_conditions["gambling_active_worker_ids"] = active_ids
    initial_conditions["gambling_inactive_worker_ids"] = inactive_ids
    initial_conditions["gambling_owner_ids"] = owner_ids

    Random.seed!(simulation_seed)
    model = Bit.Model(parameters, initial_conditions)
    active_gambler_mask = in.(model.w_act.ID, Ref(Set(active_ids)))
    inactive_gambler_mask = in.(model.w_inact.ID, Ref(Set(inactive_ids)))
    recipient_owner_mask = in.(model.firms.ID, Ref(Set(owner_ids)))
    trace_rows = [
        period_trace(
            model,
            run,
            scenario,
            simulation_seed,
            0,
            active_gambler_mask,
            inactive_gambler_mask,
            recipient_owner_mask,
        ),
    ]

    for period in 1:horizon
        Bit.step!(model; parallel = false)
        Bit.collect_data!(model)
        push!(
            trace_rows,
            period_trace(
                model,
                run,
                scenario,
                simulation_seed,
                period,
                active_gambler_mask,
                inactive_gambler_mask,
                recipient_owner_mask,
            ),
        )
    end

    return model, trace_rows
end

function main()
    base_parameters = Bit.AUSTRIA2010Q1.parameters
    base_initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    rows = NamedTuple[]
    gdp_rows = NamedTuple[]
    trace_rows = NamedTuple[]

    # ponytail: sequential pairs keep global-RNG matching simple; use explicit
    # per-model RNGs if runtime becomes a problem.
    for run in 1:N_RUNS
        active_ids, inactive_ids, owner_ids =
            participant_ids(base_parameters, run)
        simulation_seed = SIMULATION_SEED + run

        for (scenario, gambling_share) in (
                ("baseline", 0.0),
                ("gambling", GAMBLING_SHARE),
            )
            model, scenario_trace_rows = run_scenario(
                run,
                scenario,
                base_parameters,
                base_initial_conditions,
                gambling_share,
                active_ids,
                inactive_ids,
                owner_ids,
                simulation_seed,
            )
            append!(trace_rows, scenario_trace_rows)

            push!(
                rows,
                (
                    run = run,
                    scenario = scenario,
                    simulation_seed = simulation_seed,
                    gambling_income_share = gambling_share,
                    active_gamblers = length(active_ids),
                    inactive_gamblers = length(inactive_ids),
                    recipient_owners = length(owner_ids),
                    final_real_gdp = model.data.real_gdp[end],
                    final_active_worker_deposits = sum(model.w_act.D_h),
                    final_inactive_worker_deposits = sum(model.w_inact.D_h),
                    final_owner_deposits = sum(model.firms.D_h),
                    cumulative_household_consumption =
                        sum(model.data.nominal_household_consumption[2:end]),
                    cumulative_gambling_volume =
                        sum(model.data.gambling_volume[2:end]),
                ),
            )

            for (period, real_gdp) in enumerate(model.data.real_gdp)
                push!(
                    gdp_rows,
                    (
                        run = run,
                        scenario = scenario,
                        simulation_seed = simulation_seed,
                        period = period - 1,
                        real_gdp = real_gdp,
                    ),
                )
            end
        end

        println("completed pair $run/$N_RUNS")
    end

    results = DataFrame(rows)
    trace = DataFrame(trace_rows)

    @assert nrow(results) == 2 * N_RUNS
    @assert all(
        iszero,
        results.cumulative_gambling_volume[results.scenario .== "baseline"],
    )
    @assert length(gdp_rows) == 2 * N_RUNS * (HORIZON + 1)
    @assert nrow(trace) == 2 * N_RUNS * (HORIZON + 1)
    @assert all(
        isapprox.(
            trace.gambling_volume,
            trace.active_worker_stakes .+ trace.inactive_worker_stakes,
        ),
    )
    @assert all(isapprox.(trace.transfer_residual, 0.0; atol = 1.0e-8))
    @assert all(
        iszero,
        trace.gambling_volume[trace.scenario .== "baseline"],
    )
    @assert all(
        isapprox.(trace.real_gdp_expenditure_residual, 0.0; atol = 1.0e-6),
    )
    @assert all(
        isapprox.(trace.nominal_gdp_expenditure_residual, 0.0; atol = 1.0e-6),
    )

    mkpath(DATA_DIR)
    CSV.write(OUTPUT, results)
    CSV.write(GDP_OUTPUT, DataFrame(gdp_rows))
    CSV.write(TRACE_OUTPUT, trace)
    println("saved: $OUTPUT")
    println("saved: $GDP_OUTPUT")
    return println("saved: $TRACE_OUTPUT")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
