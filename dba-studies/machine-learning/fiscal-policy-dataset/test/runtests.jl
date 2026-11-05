using Test, Random

include(joinpath(@__DIR__, "..", "generate_dataset.jl"))

settings = load_settings(joinpath(@__DIR__, "..", "experiment.toml"))
parameters, initial_conditions = calibration(settings)
bounds = policy_bounds(parameters, settings)
configs = configurations(parameters, bounds, settings.n, MersenneTwister(settings.master_seed))

@test all(bounds[name] == (0.0, 2 * (name == "spending_multiplier" ? 1.0 : parameters[name]))
          for name in POLICY_NAMES)
@test nrow(configs) == settings.n
@test configs.kind[8] == "spending_multiplier_low"
@test configs.spending_multiplier[8] == 0.0

trajectory = simulate(parameters, initial_conditions, configs[8, :], 8,
                      settings.master_seed + 1, settings.horizon)
@test nrow(trajectory) == settings.horizon
@test all(iszero, trajectory.planned_government_consumption)
@test all(iszero, trajectory.realized_government_consumption)
@test all(isfinite, trajectory.real_gdp)

all_zero = (tau_INC = 0.0, tau_VAT = 0.0, theta_UB = 0.0,
            spending_multiplier = 0.0)
all_zero_trajectory = simulate(parameters, initial_conditions, all_zero, 0,
                               settings.master_seed + 1, settings.horizon)
@test nrow(all_zero_trajectory) == settings.horizon
@test all(isfinite, all_zero_trajectory.real_gdp)
