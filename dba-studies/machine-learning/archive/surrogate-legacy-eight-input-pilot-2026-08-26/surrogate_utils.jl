using CSV
using DataFrames
using JLD2
using LinearAlgebra
using Random
using Statistics
using TOML

const PARAMETER_NAMES = ["psi", "psi_H", "mu", "theta_UB", "theta_DIV", "theta", "zeta", "zeta_LTV"]
const TARGET_NAMES = [
    "real_gdp_growth_12q",
    "mean_quarterly_real_gdp_growth",
    "maximum_gdp_decline",
    "mean_implicit_gdp_inflation",
    "final_real_household_consumption",
    "final_real_capitalformation",
    "final_real_exports",
    "final_real_imports",
    "final_wages",
]

function parameter_bounds(parameters; width = 0.20)
    bounds = Dict{String, Tuple{Float64, Float64}}()
    for name in PARAMETER_NAMES
        baseline = Float64(parameters[name])
        lower, upper = baseline * (1 - width), baseline * (1 + width)
        bounds[name] = name == "mu" ? (max(0.0, lower), upper) : (max(0.0, lower), min(1.0, upper))
    end
    return bounds
end

function sample_configurations(parameters, n::Int, rng::AbstractRNG)
    bounds = parameter_bounds(parameters)
    samples = Matrix{Float64}(undef, n, length(PARAMETER_NAMES))
    for (j, name) in enumerate(PARAMETER_NAMES)
        lower, upper = bounds[name]
        samples[:, j] = lower .+ (upper - lower) .* ((randperm(rng, n) .- rand(rng, n)) ./ n)
    end

    psi, psi_h = findfirst(==("psi"), PARAMETER_NAMES), findfirst(==("psi_H"), PARAMETER_NAMES)
    for i in axes(samples, 1)
        if samples[i, psi] + samples[i, psi_h] > 1
            lower, upper = bounds["psi"]
            samples[i, psi] = lower + rand(rng) * (min(upper, 1 - samples[i, psi_h]) - lower)
        end
    end
    return samples, bounds
end

trajectory(data) = Dict(String(name) => deepcopy(getfield(data, name)) for name in fieldnames(typeof(data)))

function validate_trajectory(values::AbstractDict, horizon::Int)
    expected_periods = horizon + 1 # Initial state plus one observation per simulated quarter.
    for (name, series) in values
        length(series) == expected_periods || error("$name has $(length(series)) periods; expected $expected_periods")
        for value in series
            numbers = value isa AbstractArray ? value : (value,)
            all(isfinite, numbers) || error("$name contains a non-finite value")
        end
    end
    return true
end

function scalar_targets(values::AbstractDict)
    real_gdp = values["real_gdp"]
    nominal_gdp = values["nominal_gdp"]
    length(real_gdp) >= 2 || error("At least two periods are required to derive targets")
    all(>(0), real_gdp) || error("Real GDP must be positive")
    deflator = nominal_gdp ./ real_gdp
    all(>(0), deflator) || error("The implicit GDP deflator must be positive")
    growth = diff(log.(real_gdp))

    return Dict(
        "real_gdp_growth_12q" => real_gdp[end] / real_gdp[1] - 1,
        "mean_quarterly_real_gdp_growth" => mean(growth),
        "maximum_gdp_decline" => max(0.0, maximum((real_gdp[1] .- real_gdp) ./ real_gdp[1])),
        "mean_implicit_gdp_inflation" => mean(diff(log.(deflator))),
        "final_real_household_consumption" => values["real_household_consumption"][end],
        "final_real_capitalformation" => values["real_capitalformation"][end],
        "final_real_exports" => values["real_exports"][end],
        "final_real_imports" => values["real_imports"][end],
        "final_wages" => values["wages"][end],
    )
end

function split_ids(ids; rng = MersenneTwister(2025))
    shuffled = shuffle(rng, collect(ids))
    n = length(shuffled)
    n_train = max(1, floor(Int, 0.70n))
    n_validation = n >= 7 ? max(1, floor(Int, 0.15n)) : 0
    n_train = min(n_train, n - n_validation - (n >= 2 ? 1 : 0))
    return (
        train = shuffled[1:n_train],
        validation = shuffled[(n_train + 1):(n_train + n_validation)],
        test = shuffled[(n_train + n_validation + 1):end],
    )
end

function metrics(actual, predicted)
    residual = actual .- predicted
    scale = quantile(actual, 0.95) - quantile(actual, 0.05)
    return (
        mae = mean(abs.(residual)),
        nrmse = iszero(scale) ? NaN : sqrt(mean(abs2, residual)) / scale,
        r2 = iszero(var(actual)) ? NaN : 1 - sum(abs2, residual) / sum(abs2, actual .- mean(actual)),
    )
end
