module GovernmentPolicy

import BeforeIT as Bit
using Random

export PolicyModel, run_episode

Bit.@object mutable struct PolicyModel(Bit.Model) <: Bit.AbstractModel
    spending_multiplier::Bit.typeFloat
end

function Bit.gov_expenditure(model::PolicyModel)
    C_G, C_d_j = invoke(Bit.gov_expenditure, Tuple{Any}, model)
    m = model.spending_multiplier
    return m * C_G, m .* C_d_j
end

function observe(model, quarter)
    nominal_gdp = last(model.data.nominal_gdp)
    nominal_gdp > 0 || error("Nominal GDP must be positive")

    return (
        quarter = quarter,
        tax_rate = model.prop.tau_INC,
        benefit_rate = model.prop.theta_UB,
        real_gdp = last(model.data.real_gdp),
        unemployment_rate = count(iszero, model.w_act.O_h) / length(model.w_act.O_h),
        debt_to_gdp = model.gov.L_G / nominal_gdp,
        government_revenue = quarter == 0 ? missing : model.gov.Y_G,
        real_government_consumption =
            quarter == 0 ? missing : last(model.data.real_government_consumption),
    )
end

function run_episode(
    policy, parameters, initial_conditions;
    horizon::Int = 12, seed::Int = 1, policy_seed::Int = 2, reward_config = nothing,
)
    horizon > 0 || throw(ArgumentError("horizon must be positive"))

    Random.seed!(seed)
    base = Bit.Model(deepcopy(parameters), deepcopy(initial_conditions))
    model = PolicyModel(Bit.fields(base)..., one(Bit.typeFloat))
    policy_rng = MersenneTwister(policy_seed)
    rows = NamedTuple[]

    previous_action = (
        tax_rate = model.prop.tau_INC,
        benefit_rate = model.prop.theta_UB,
        log_spending_multiplier = 0.0,
    )


    for quarter in 1:horizon
        action = policy(observe(model, quarter - 1), policy_rng)

        all(isfinite, (
            action.tax_rate,
            action.benefit_rate,
            action.log_spending_multiplier,
        )) || throw(ArgumentError("policy action must be finite"))

        multiplier = exp(action.log_spending_multiplier)
        isfinite(multiplier) && multiplier > 0 ||
            throw(ArgumentError("spending multiplier must be finite and positive"))

        model.prop.tau_INC = action.tax_rate
        model.prop.theta_UB = action.benefit_rate
        model.spending_multiplier = multiplier

        Bit.step!(model; parallel = false)
        Bit.collect_data!(model)

        reward_terms = isnothing(reward_config) ? (;) :
        reward_components(model, action, previous_action, reward_config)

        push!(rows, merge(observe(model, quarter), (
            spending_multiplier = multiplier,
            planned_government_consumption = model.gov.C_G,
            realized_government_consumption = model.gov.C_j,
        ), reward_terms))

        previous_action = action
    end

    return model, rows
end

function reward_components(model, action, previous_action, cfg)
    consumption = vcat(
        model.w_act.C_h,
        model.w_inact.C_h,
        model.firms.C_h,
        model.bank.C_h,
    )
    H = length(consumption)
    H == model.prop.H || error("Household count does not match the model")

    real_consumption =
        (1 + model.prop.tau_VAT) .* consumption ./ model.agg.P_bar_h

    household = sum(
        log((c + cfg.c_floor) / cfg.c_ref) for c in real_consumption
    ) / H
    public = cfg.lambda_g * log(
        (last(model.data.real_government_consumption) / H + cfg.g_floor) /
        cfg.g_ref
    )
    unemployment =
        -cfg.lambda_u * count(iszero, model.w_act.O_h) / length(model.w_act.O_h)
    inflation =
        -cfg.lambda_pi * abs(last(model.agg.pi_) - cfg.inflation_target)
    policy_change = -cfg.lambda_a * sqrt(
        ((action.tax_rate - previous_action.tax_rate) / cfg.tax_step)^2 +
        ((action.benefit_rate - previous_action.benefit_rate) / cfg.benefit_step)^2 +
        (
            (action.log_spending_multiplier -
             previous_action.log_spending_multiplier) / cfg.spending_step
        )^2
    )

    total = household + public + unemployment + inflation + policy_change
    isfinite(total) || error("Reward is not finite")

    return (; household, public, unemployment, inflation, policy_change, reward = total)
end

end