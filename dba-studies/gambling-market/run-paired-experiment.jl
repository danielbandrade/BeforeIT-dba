import BeforeIT as Bit

using CSV
using DataFrames
using Random

const N_RUNS = 20
const HORIZON = 16
const GAMBLING_SHARE = 0.02
const PARTICIPATION_SHARE = 0.10
const SELECTION_SEED = 1_000
const SIMULATION_SEED = 10_000
const OUTPUT = joinpath(@__DIR__, "paired-results.csv")
const GDP_OUTPUT = joinpath(@__DIR__, "paired-gdp-paths.csv")

function participant_ids(parameters, run)
    rng = MersenneTwister(SELECTION_SEED + run)

    number_of_firms = Int(sum(parameters["I_s"]))
    number_of_active_workers = Int(parameters["H_act"]) - number_of_firms - 1
    number_of_inactive_workers = Int(parameters["H_inact"])
    number_of_workers = number_of_active_workers + number_of_inactive_workers

    number_of_gamblers =
        max(1, round(Int, PARTICIPATION_SHARE * number_of_workers))
    selected_workers = randperm(rng, number_of_workers)[1:number_of_gamblers]

    active_ids = sort([
        id for id in selected_workers if id <= number_of_active_workers
    ])
    inactive_ids = sort([
        id - number_of_active_workers for id in selected_workers if
            id > number_of_active_workers
    ])

    number_of_owners =
        max(1, round(Int, PARTICIPATION_SHARE * number_of_firms))
    owner_ids = sort(randperm(rng, number_of_firms)[1:number_of_owners])

    return active_ids, inactive_ids, owner_ids
end

function run_scenario(
        base_parameters,
        base_initial_conditions,
        gambling_share,
        active_ids,
        inactive_ids,
        owner_ids,
        simulation_seed,
    )
    parameters = copy(base_parameters)
    initial_conditions = copy(base_initial_conditions)

    parameters["gambling_income_share"] = gambling_share
    initial_conditions["gambling_active_worker_ids"] = active_ids
    initial_conditions["gambling_inactive_worker_ids"] = inactive_ids
    initial_conditions["gambling_owner_ids"] = owner_ids

    Random.seed!(simulation_seed)
    model = Bit.Model(parameters, initial_conditions)
    Bit.run!(model, HORIZON; parallel = false)

    return model
end

function main()
    base_parameters = Bit.AUSTRIA2010Q1.parameters
    base_initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions
    rows = NamedTuple[]
    gdp_rows = NamedTuple[]

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
            model = run_scenario(
                base_parameters,
                base_initial_conditions,
                gambling_share,
                active_ids,
                inactive_ids,
                owner_ids,
                simulation_seed,
            )

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

    @assert nrow(results) == 2 * N_RUNS
    @assert all(
        iszero,
        results.cumulative_gambling_volume[results.scenario .== "baseline"],
    )
    @assert length(gdp_rows) == 2 * N_RUNS * (HORIZON + 1)

    CSV.write(OUTPUT, results)
    CSV.write(GDP_OUTPUT, DataFrame(gdp_rows))
    println("saved: $OUTPUT")
    println("saved: $GDP_OUTPUT")
end

main()
