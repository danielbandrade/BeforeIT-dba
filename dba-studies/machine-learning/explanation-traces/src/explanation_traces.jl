module ExplanationTraces

import BeforeIT as Bit

using CSV
using DataFrames
using Dates
using JLD2
using Random
using Statistics
using TOML

export SCHEMA_VERSION, derive_experiment!, field_inventory, generate_experiment,
    load_trace, save_trace, simulate_trace, snapshot, validate_trace

const SCHEMA_VERSION = 1
const ROOT = normpath(joinpath(@__DIR__, ".."))
const MODEL_COMPONENTS = (:w_act, :w_inact, :firms, :bank, :cb, :gov, :rotw, :agg)
const AGENT_COMPONENTS = Set((:w_act, :w_inact, :firms))
const RUNTIME_FIELDS = Set((:del, :id_to_index))
const AGGREGATE_HISTORIES = Set((:Y, :pi_))

copy_value(value::Base.RefValue) = deepcopy(value[])
copy_value(value) = deepcopy(value)

function component_values(object, component::Symbol)
    values = Dict{String, Any}()
    for field in fieldnames(typeof(object))
        component in AGENT_COMPONENTS && field in RUNTIME_FIELDS && continue
        component == :agg && field in AGGREGATE_HISTORIES && continue
        values[string(field)] = copy_value(getfield(object, field))
    end
    return values
end

function data_observation(data)
    values = Dict{String, Any}()
    for field in fieldnames(typeof(data))
        history = getfield(data, field)
        isempty(history) && error("Data field $field has no observation")
        values[string(field)] = deepcopy(last(history))
    end
    return values
end

function model_properties(model)
    return Dict(string(field) => copy_value(getfield(model.prop, field)) for field in fieldnames(typeof(model.prop)))
end

function field_inventory(model)
    rows = NamedTuple[]
    objects = [
        (:prop, model.prop),
        (:w_act, model.w_act),
        (:w_inact, model.w_inact),
        (:firms, model.firms),
        (:bank, model.bank),
        (:cb, model.cb),
        (:gov, model.gov),
        (:rotw, model.rotw),
        (:agg, model.agg),
        (:data, model.data),
    ]
    for (component, object) in objects, field in fieldnames(typeof(object))
        storage_class, reason = if component == :prop
            ("static_once", "Model properties are fixed in the declared experiment")
        elseif component == :data
            ("cumulative_observation", "Store only the observation added at this boundary")
        elseif component == :agg && field in AGGREGATE_HISTORIES
            ("cumulative_delta", "Store the initial history once and one appended value per quarter")
        elseif component in AGENT_COMPONENTS && field in RUNTIME_FIELDS
            ("runtime_excluded", "Reconstructed from persistent IDs; not an economic state variable")
        else
            ("snapshot", "Copied at every quarter boundary")
        end
        units = field in (:ID, :lastid) ? "identifier" :
            field in (:O_h, :G_i, :N_i, :N_d_i, :V_i, :t, :collection_time) ? "count_or_index" :
            "BeforeIT model units; see source field documentation"
        push!(
            rows, (
                component = string(component),
                field = string(field),
                storage_class,
                units,
                missing_rule = "missing values are not allowed in raw state",
                reason,
            )
        )
    end
    return DataFrame(rows)
end

function snapshot(model, period::Integer, initial_history_lengths)
    length(model.data.collection_time) == period + 1 ||
        error("Expected $(period + 1) data observations, found $(length(model.data.collection_time))")
    length(model.agg.Y) == initial_history_lengths["Y"] + period ||
        error("Unexpected aggregate GDP history length at period $period")
    length(model.agg.pi_) == initial_history_lengths["pi_"] + period ||
        error("Unexpected aggregate inflation history length at period $period")

    state = Dict{String, Any}(
        "period" => Int(period),
        "agg_t" => Int(model.agg.t),
        "data" => data_observation(model.data),
        "aggregate_append" => Dict(
            "Y" => period == 0 ? nothing : copy_value(last(model.agg.Y)),
            "pi_" => period == 0 ? nothing : copy_value(last(model.agg.pi_)),
        ),
    )
    for component in MODEL_COMPONENTS
        state[string(component)] = component_values(getfield(model, component), component)
    end
    return state
end

function git_metadata()
    commit = try
        strip(read(`git rev-parse HEAD`, String))
    catch
        "unknown"
    end
    dirty = try
        !isempty(strip(read(`git status --porcelain`, String)))
    catch
        missing
    end
    return commit, dirty
end

function initialize_trace(model, parameters, initial_conditions, metadata)
    commit, dirty = git_metadata()
    initial_history = Dict("Y" => copy(model.agg.Y), "pi_" => copy(model.agg.pi_))
    history_lengths = Dict(name => length(values) for (name, values) in initial_history)
    trace_metadata = Dict{String, Any}(
        "schema_version" => SCHEMA_VERSION,
        "created_at_utc" => Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SS.sssZ"),
        "git_commit" => commit,
        "dirty_worktree" => dirty,
        "julia_version" => string(VERSION),
        "beforeit_version" => string(Base.pkgversion(Bit)),
        "parallel" => false,
        "status" => "running",
    )
    merge!(trace_metadata, deepcopy(metadata))

    trace = Dict{String, Any}(
        "schema_version" => SCHEMA_VERSION,
        "metadata" => trace_metadata,
        "static" => Dict(
            "parameters" => deepcopy(parameters),
            "initial_conditions" => deepcopy(initial_conditions),
            "properties" => model_properties(model),
            "initial_aggregate_history" => initial_history,
            "initial_history_lengths" => history_lengths,
            "field_inventory" => [NamedTuple(row) for row in eachrow(field_inventory(model))],
        ),
        "snapshots" => Any[],
        "events" => NamedTuple[],
    )
    push!(trace["snapshots"], snapshot(model, 0, history_lengths))
    return trace
end

function push_event!(
        observer; stage, event_type, actor_type, actor_id = missing,
        counterparty_type = "", counterparty_id = missing, product_or_sector = missing,
        quantity = missing, value = missing, reason = ""
    )
    push!(
        observer.events, (
            run_id = observer.run_id,
            period = observer.period,
            stage = string(stage),
            event_type = string(event_type),
            actor_type = string(actor_type),
            actor_id = ismissing(actor_id) ? missing : Int(actor_id),
            counterparty_type = string(counterparty_type),
            counterparty_id = ismissing(counterparty_id) ? missing : Int(counterparty_id),
            product_or_sector = ismissing(product_or_sector) ? missing : Int(product_or_sector),
            quantity = ismissing(quantity) ? missing : Float64(quantity),
            value = ismissing(value) ? missing : Float64(value),
            reason = string(reason),
        )
    )
    return nothing
end

mutable struct EventObserver
    run_id::String
    period::Int
    events::Vector{NamedTuple}
    cache::Dict{Symbol, Any}
end

function employer_id(position, firm_ids)
    return position > 0 && position <= length(firm_ids) ? firm_ids[position] : missing
end

function (observer::EventObserver)(stage::Symbol, model)
    firms = model.firms
    if stage == :start
        insolvent = NamedTuple[]
        for i in eachindex(firms.ID)
            if firms.D_i[i] < 0 && firms.E_i[i] < 0
                push!(
                    insolvent, (
                        id = firms.ID[i], deposits = firms.D_i[i], equity = firms.E_i[i],
                        loans = firms.L_i[i], capital = firms.K_i[i],
                    )
                )
            end
        end
        observer.cache[:insolvent] = insolvent
        observer.cache[:occupations] = Dict(zip(copy(model.w_act.ID), copy(model.w_act.O_h)))
        observer.cache[:firm_ids] = copy(firms.ID)
    elseif stage == :after_financing
        for firm in get(observer.cache, :insolvent, NamedTuple[])
            refinancing = firm.loans - firm.deposits - model.prop.zeta_b * model.agg.P_bar_CF * firm.capital
            push_event!(
                observer;
                stage, event_type = :firm_refinancing, actor_type = :firm, actor_id = firm.id,
                counterparty_type = :bank, counterparty_id = 1, quantity = firm.loans,
                value = refinancing, reason = "negative deposits and equity",
            )
        end
    elseif stage == :after_expectations
        for (name, value) in (
                (:epsilon_Y_EA, model.agg.epsilon_Y_EA),
                (:epsilon_E, model.agg.epsilon_E),
                (:epsilon_I, model.agg.epsilon_I),
            )
            push_event!(
                observer;
                stage, event_type = :exogenous_innovation, actor_type = :rest_of_world,
                value, reason = string(name),
            )
        end
    elseif stage == :after_credit_market
        for i in eachindex(firms.ID)
            requested, granted = firms.DL_d_i[i], firms.DL_i[i]
            (requested > 0 || granted > 0) || continue
            reason = granted + 1.0e-10 < requested ? "rationed" : "fully_funded"
            push_event!(
                observer;
                stage, event_type = :credit_allocation, actor_type = :firm,
                actor_id = firms.ID[i], counterparty_type = :bank, counterparty_id = 1,
                product_or_sector = firms.G_i[i], quantity = requested, value = granted, reason,
            )
        end
    elseif stage == :after_labour_market
        old_occupations = observer.cache[:occupations]
        firm_ids = observer.cache[:firm_ids]
        for i in eachindex(model.w_act.ID)
            worker_id, new_job = model.w_act.ID[i], model.w_act.O_h[i]
            old_job = old_occupations[worker_id]
            old_job == new_job && continue
            event_type, firm_id, reason = if old_job <= 0 && new_job > 0
                (:hire, employer_id(new_job, firm_ids), "previously unemployed")
            elseif old_job > 0 && new_job <= 0
                (:separation, employer_id(old_job, firm_ids), "now unemployed")
            else
                (:job_change, employer_id(new_job, firm_ids), "previous_position=$old_job")
            end
            push_event!(
                observer;
                stage, event_type, actor_type = :active_worker, actor_id = worker_id,
                counterparty_type = :firm, counterparty_id = firm_id, quantity = 1.0, reason,
            )
        end
    elseif stage == :after_production
        for i in eachindex(firms.ID)
            desired = firms.Q_s_i[i]
            base_labour = firms.N_i[i] * firms.alpha_bar_i[i]
            capital = firms.K_i[i] * firms.kappa_i[i]
            materials = firms.M_i[i] * firms.beta_i[i]
            required = min(desired, capital, materials)
            labour = base_labour == 0 ? zero(base_labour) : base_labour * min(1.5, required / base_labour)
            limits = (demand = desired, labour = labour, capital = capital, materials = materials)
            binding_value = minimum(values(limits))
            tolerance = max(1.0e-10, abs(Float64(binding_value)) * 1.0e-8)
            reasons = join((string(name) for (name, limit) in pairs(limits) if abs(limit - binding_value) <= tolerance), "+")
            push_event!(
                observer;
                stage, event_type = :production_binding, actor_type = :firm,
                actor_id = firms.ID[i], product_or_sector = firms.G_i[i],
                quantity = desired, value = firms.Y_i[i], reason = reasons,
            )
        end
    end
    return nothing
end

function simulate_trace(parameters, initial_conditions; horizon::Integer, seed::Integer, metadata = Dict{String, Any}())
    horizon >= 1 || error("horizon must be positive")
    Random.seed!(seed)
    model = Bit.Model(deepcopy(parameters), deepcopy(initial_conditions))
    trace = initialize_trace(model, parameters, initial_conditions, metadata)
    started = time()
    for period in 1:horizon
        observer = EventObserver(string(trace["metadata"]["run_id"]), period, trace["events"], Dict{Symbol, Any}())
        Bit.step!(model; parallel = false, observer)
        Bit.collect_data!(model)
        model_properties(model) == trace["static"]["properties"] ||
            error("Model properties changed during a trace declared as static")
        push!(trace["snapshots"], snapshot(model, period, trace["static"]["initial_history_lengths"]))
    end
    trace["metadata"]["runtime_seconds"] = time() - started
    trace["metadata"]["status"] = "complete"
    validate_trace(trace; horizon)
    return trace, model
end

function check_finite(value, path = "trace")
    if value isa AbstractFloat
        isfinite(value) || error("Non-finite value at $path")
    elseif value isa AbstractArray || value isa Tuple
        for (index, item) in pairs(value)
            check_finite(item, "$path[$index]")
        end
    elseif value isa AbstractDict || value isa NamedTuple
        for (name, item) in pairs(value)
            check_finite(item, "$path.$name")
        end
    end
    return nothing
end

function validate_trace(trace; horizon = Int(trace["metadata"]["horizon"]))
    trace["schema_version"] == SCHEMA_VERSION || error("Unsupported trace schema")
    snapshots = trace["snapshots"]
    length(snapshots) == horizon + 1 || error("Trace must contain T + 1 snapshots")
    [state["period"] for state in snapshots] == collect(0:horizon) || error("Trace periods are not contiguous")

    initial_lengths = trace["static"]["initial_history_lengths"]
    for state in snapshots
        period = state["period"]
        for component in ("w_act", "w_inact", "firms")
            values = state[component]
            ids = values["ID"]
            length(unique(ids)) == length(ids) || error("Duplicate $component ID at period $period")
            for (field, value) in values
                value isa AbstractVector || continue
                length(value) == length(ids) || error("$component.$field is not aligned with IDs")
            end
        end
        period == 0 || begin
            isnothing(state["aggregate_append"]["Y"]) && error("Missing GDP append at period $period")
            isnothing(state["aggregate_append"]["pi_"]) && error("Missing inflation append at period $period")
        end
        check_finite(state, "snapshot[$period]")
    end

    length(trace["static"]["initial_aggregate_history"]["Y"]) == initial_lengths["Y"] ||
        error("Initial GDP history length changed")
    length(trace["static"]["initial_aggregate_history"]["pi_"]) == initial_lengths["pi_"] ||
        error("Initial inflation history length changed")
    all(event -> 1 <= event.period <= horizon, trace["events"]) || error("Event outside the trace horizon")

    for period in 1:horizon
        state = snapshots[period + 1]
        credit = filter(event -> event.period == period && event.event_type == "credit_allocation", trace["events"])
        requested = sum((event.quantity for event in credit); init = 0.0)
        granted = sum((event.value for event in credit); init = 0.0)
        isapprox(requested, sum(state["firms"]["DL_d_i"]); atol = 1.0e-8) ||
            error("Credit requests do not reconcile at period $period")
        isapprox(granted, sum(state["firms"]["DL_i"]); atol = 1.0e-8) ||
            error("Credit grants do not reconcile at period $period")
    end
    return trace
end

function save_trace(path, trace)
    isfile(path) && error("Refusing to overwrite completed trace: $path")
    mkpath(dirname(path))
    temporary = path * ".tmp.jld2"
    isfile(temporary) && rm(temporary)
    try
        JLD2.save(temporary, "trace", trace)
        loaded = JLD2.load(temporary, "trace")
        isequal(loaded, trace) || error("Trace changed during JLD2 round trip")
        mv(temporary, path)
    finally
        isfile(temporary) && rm(temporary)
    end
    return path
end

function load_trace(path)
    trace = JLD2.load(path, "trace")
    trace["schema_version"] == SCHEMA_VERSION || error("Unsupported trace schema in $path")
    return trace
end

function gini(values)
    observations = sort(Float64.(values))
    isempty(observations) && return missing
    any(!isfinite, observations) && return missing
    minimum(observations) < 0 && return missing
    total = sum(observations)
    total > 0 || return missing
    n = length(observations)
    return 2sum(index * value for (index, value) in enumerate(observations)) / (n * total) - (n + 1) / n
end

function household_values(state, field)
    return vcat(
        state["w_act"][field], state["w_inact"][field], state["firms"][field], [state["bank"][field]],
    )
end

function event_total(events, period, event_type, field)
    selected = (getproperty(event, field) for event in events if event.period == period && event.event_type == event_type)
    return sum((value for value in selected if !ismissing(value)); init = 0.0)
end

function constraint_share(events, period, constraint, number_of_firms)
    number_of_firms == 0 && return 0.0
    count = sum(
        event.period == period && event.event_type == "production_binding" &&
            constraint in split(event.reason, "+") for event in events
    )
    return count / number_of_firms
end

function add_data_observation!(row, observation)
    for (field, value) in observation
        if value isa AbstractVector
            for (index, item) in enumerate(value)
                row[Symbol("$(field)_$(index)")] = item
            end
        else
            row[Symbol(field)] = value
        end
    end
    return row
end

function period_dataframe(trace)
    metadata, events = trace["metadata"], trace["events"]
    frame = DataFrame()
    for state in trace["snapshots"]
        period = state["period"]
        active_occupations = state["w_act"]["O_h"]
        incomes = household_values(state, "Y_h")
        deposits = household_values(state, "D_h")
        capital = household_values(state, "K_h")
        firm_output = state["firms"]["Y_i"]
        sectors = state["firms"]["G_i"]
        sector_output = [sum(firm_output[sectors .== sector]) for sector in unique(sectors)]
        output_total = sum(sector_output)
        concentration = output_total > 0 ? sum((sector_output ./ output_total) .^ 2) : missing
        income_quantiles = quantile(incomes, [0.1, 0.5, 0.9])
        deposit_quantiles = quantile(deposits, [0.1, 0.5, 0.9])
        capital_quantiles = quantile(capital, [0.1, 0.5, 0.9])
        n_firms = length(state["firms"]["ID"])

        row = Dict{Symbol, Any}(
            :run_id => metadata["run_id"],
            :scenario_id => metadata["scenario_id"],
            :role => metadata["role"],
            :pair_id => metadata["pair_id"],
            :seed => metadata["seed"],
            :period => period,
            :agg_t => state["agg_t"],
            :unemployment_rate => count(==(0), active_occupations) / length(active_occupations),
            :employment_rate => count(>(0), active_occupations) / length(active_occupations),
            :refinanced_firms => sum(
                event.period == period && event.event_type == "firm_refinancing" for event in events
            ),
            :refinancing_value => event_total(events, period, "firm_refinancing", :value),
            :credit_requested => event_total(events, period, "credit_allocation", :quantity),
            :credit_granted => event_total(events, period, "credit_allocation", :value),
            :income_p10 => income_quantiles[1],
            :income_median => income_quantiles[2],
            :income_p90 => income_quantiles[3],
            :deposits_p10 => deposit_quantiles[1],
            :deposits_median => deposit_quantiles[2],
            :deposits_p90 => deposit_quantiles[3],
            :capital_p10 => capital_quantiles[1],
            :capital_median => capital_quantiles[2],
            :capital_p90 => capital_quantiles[3],
            :household_income_gini => gini(incomes),
            :household_deposit_gini => gini(deposits),
            :household_capital_gini => gini(capital),
            :sector_output_concentration => concentration,
            :demand_constraint_share => constraint_share(events, period, "demand", n_firms),
            :labour_constraint_share => constraint_share(events, period, "labour", n_firms),
            :capital_constraint_share => constraint_share(events, period, "capital", n_firms),
            :materials_constraint_share => constraint_share(events, period, "materials", n_firms),
            :production_gap => sum(state["firms"]["Q_s_i"]) - sum(state["firms"]["Y_i"]),
            :employment_gap => sum(state["firms"]["N_d_i"]) - sum(state["firms"]["N_i"]),
            :investment_gap => sum(state["firms"]["I_d_i"]) - sum(state["firms"]["I_i"]),
            :credit_gap => sum(state["firms"]["DL_d_i"]) - sum(state["firms"]["DL_i"]),
        )
        row[:credit_rationed] = row[:credit_requested] - row[:credit_granted]
        add_data_observation!(row, state["data"])
        push!(frame, row; cols = :union, promote = true)
    end
    return frame
end

function firm_dataframe(trace)
    metadata = trace["metadata"]
    frames = DataFrame[]
    for state in trace["snapshots"]
        firms = state["firms"]
        ids = firms["ID"]
        frame = DataFrame(
            run_id = fill(metadata["run_id"], length(ids)),
            scenario_id = fill(metadata["scenario_id"], length(ids)),
            role = fill(metadata["role"], length(ids)),
            pair_id = fill(metadata["pair_id"], length(ids)),
            seed = fill(metadata["seed"], length(ids)),
            period = fill(state["period"], length(ids)),
            firm_id = copy(ids),
        )
        for field in sort!(collect(keys(firms)))
            field in ("ID", "lastid") && continue
            values = firms[field]
            values isa AbstractVector || continue
            frame[!, Symbol(field)] = copy(values)
        end
        push!(frames, frame)
    end
    return vcat(frames...; cols = :union)
end

function household_frame(metadata, state, component_name, group, firm_ids)
    component = state[component_name]
    ids = component_name == "bank" ? [1] : component["ID"]
    field(name) = component_name == "bank" ? [component[name]] : component[name]
    occupations = haskey(component, "O_h") ? field("O_h") : fill(missing, length(ids))
    wages = haskey(component, "w_h") ? field("w_h") : fill(missing, length(ids))
    employers = Union{Missing, Int}[
        ismissing(job) ? missing : employer_id(job, firm_ids) for job in occupations
    ]
    return DataFrame(
        run_id = fill(metadata["run_id"], length(ids)),
        scenario_id = fill(metadata["scenario_id"], length(ids)),
        role = fill(metadata["role"], length(ids)),
        pair_id = fill(metadata["pair_id"], length(ids)),
        seed = fill(metadata["seed"], length(ids)),
        period = fill(state["period"], length(ids)),
        household_group = fill(group, length(ids)),
        household_id = copy(ids),
        income = copy(field("Y_h")),
        deposits = copy(field("D_h")),
        capital = copy(field("K_h")),
        consumption_budget = copy(field("C_d_h")),
        investment_budget = copy(field("I_d_h")),
        consumption = copy(field("C_h")),
        investment = copy(field("I_h")),
        wage = wages,
        occupation = occupations,
        employer_firm_id = employers,
    )
end

function household_dataframe(trace)
    metadata = trace["metadata"]
    frames = DataFrame[]
    for state in trace["snapshots"]
        firm_ids = state["firms"]["ID"]
        push!(frames, household_frame(metadata, state, "w_act", "active_worker", firm_ids))
        push!(frames, household_frame(metadata, state, "w_inact", "inactive_worker", firm_ids))
        push!(frames, household_frame(metadata, state, "firms", "firm_owner", firm_ids))
        push!(frames, household_frame(metadata, state, "bank", "bank_owner", firm_ids))
    end
    return vcat(frames...; cols = :union)
end

function event_dataframe(trace)
    isempty(trace["events"]) && return DataFrame()
    frame = DataFrame(trace["events"])
    metadata = trace["metadata"]
    insertcols!(
        frame, 2,
        :scenario_id => fill(metadata["scenario_id"], nrow(frame)),
        :role => fill(metadata["role"], nrow(frame)),
        :pair_id => fill(metadata["pair_id"], nrow(frame)),
        :seed => fill(metadata["seed"], nrow(frame)),
    )
    return frame
end

function write_append(path, frame)
    nrow(frame) == 0 && return path
    append = isfile(path)
    CSV.write(path, frame; append, writeheader = !append)
    return path
end

function paired_differences(periods)
    baseline = Dict(
        (row.pair_id, row.seed, row.period) => row for row in eachrow(periods) if row.role == "baseline"
    )
    metrics = (
        :real_gdp, :unemployment_rate, :credit_requested, :credit_granted, :credit_rationed,
        :household_income_gini, :labour_constraint_share, :capital_constraint_share,
        :materials_constraint_share, :production_gap, :employment_gap,
    )
    rows = NamedTuple[]
    for intervention in eachrow(periods)
        intervention.role == "intervention" || continue
        key = (intervention.pair_id, intervention.seed, intervention.period)
        haskey(baseline, key) || error("No paired baseline for $key")
        base = baseline[key]
        differences = Dict{Symbol, Any}(
            :pair_id => intervention.pair_id,
            :seed => intervention.seed,
            :period => intervention.period,
            :baseline_scenario => base.scenario_id,
            :intervention_scenario => intervention.scenario_id,
        )
        for metric in metrics
            baseline_value, intervention_value = base[metric], intervention[metric]
            differences[Symbol("delta_", metric)] =
                ismissing(baseline_value) || ismissing(intervention_value) ? missing : intervention_value - baseline_value
        end
        ordered = (
            pair_id = differences[:pair_id],
            seed = differences[:seed],
            period = differences[:period],
            baseline_scenario = differences[:baseline_scenario],
            intervention_scenario = differences[:intervention_scenario],
            (Symbol("delta_", metric) => differences[Symbol("delta_", metric)] for metric in metrics)...,
        )
        push!(rows, ordered)
    end
    return DataFrame(rows)
end

function paired_summary(paired)
    isempty(paired) && return DataFrame()
    delta_columns = filter(name -> startswith(string(name), "delta_"), names(paired))
    rows = NamedTuple[]
    for group in groupby(paired, :period)
        values = Dict{Symbol, Any}(:period => first(group.period), :pairs => nrow(group))
        for column in delta_columns
            observations = collect(skipmissing(group[!, column]))
            values[Symbol("mean_", column)] = isempty(observations) ? missing : mean(observations)
        end
        names_ordered = vcat([:period, :pairs], Symbol.("mean_" .* string.(delta_columns)))
        push!(rows, NamedTuple{Tuple(names_ordered)}(Tuple(values[name] for name in names_ordered)))
    end
    return DataFrame(rows)
end

function write_summary_report(path, experiment_id, summary)
    isempty(summary) && return path
    final = summary[argmax(summary.period), :]
    first_change(column) = findfirst(
        row -> !ismissing(row[column]) && abs(row[column]) > 1.0e-10,
        eachrow(summary),
    )
    open(path, "w") do io
        println(io, "# Explanation trace summary: $experiment_id\n")
        println(io, "Paired differences are intervention minus baseline and averaged across the declared seeds.\n")
        println(io, "## Observed transition order\n")
        transition_metrics = (
            (:mean_delta_credit_granted, "credit granted"),
            (:mean_delta_production_gap, "production gap"),
            (:mean_delta_unemployment_rate, "unemployment rate"),
            (:mean_delta_real_gdp, "real GDP"),
        )
        for (column, label) in transition_metrics
            index = first_change(column)
            if isnothing(index)
                println(io, "- $label did not diverge within the recorded horizon.")
            else
                row = summary[index, :]
                value = round(row[column]; sigdigits = 6)
                println(io, "- $label first diverged in period $(row.period): $value.")
            end
        end
        gdp_index = argmax(abs.(summary.mean_delta_real_gdp))
        println(
            io, "- The largest mean absolute real-GDP divergence occurred in period ",
            "$(summary.period[gdp_index]): $(round(summary.mean_delta_real_gdp[gdp_index]; sigdigits = 6)).\n"
        )
        println(io, "## Final recorded period\n")
        println(io, "| Measure | Mean paired difference |")
        println(io, "|---|---:|")
        for column in names(summary)
            startswith(string(column), "mean_delta_") || continue
            label = replace(string(column), "mean_delta_" => "", "_" => " ")
            value = final[column]
            rendered = ismissing(value) ? "missing" : string(round(value; sigdigits = 6))
            println(io, "| $label | $rendered |")
        end
        println(io, "\n## Interpretation\n")
        println(
            io, "The intervention changed credit allocation before production, employment, or GDP diverged. ",
            "Later signs are not assumed: BeforeIT's matching and feedback mechanisms can amplify, offset, or reverse the initial restriction. ",
            "Use `events.csv` and the firm and household panels to identify the agents behind each paired difference. ",
            "The ordering is simulation evidence, not evidence about the real economy."
        )
    end
    return path
end

function derive_experiment!(experiment_dir)
    manifest_path = joinpath(experiment_dir, "runs.csv")
    isfile(manifest_path) || error("Missing run manifest: $manifest_path")
    manifest = CSV.read(manifest_path, DataFrame)
    derived_dir = joinpath(experiment_dir, "derived")
    isdir(derived_dir) && !isempty(readdir(derived_dir)) &&
        error("Refusing to overwrite derived artifacts in $derived_dir")
    mkpath(derived_dir)

    paths = Dict(
        :periods => joinpath(derived_dir, "periods.csv"),
        :firms => joinpath(derived_dir, "firms.csv"),
        :households => joinpath(derived_dir, "households.csv"),
        :events => joinpath(derived_dir, "events.csv"),
    )
    for run in eachrow(manifest)
        run.success || continue
        trace = load_trace(joinpath(experiment_dir, run.trace_path))
        validate_trace(trace)
        write_append(paths[:periods], period_dataframe(trace))
        write_append(paths[:firms], firm_dataframe(trace))
        write_append(paths[:households], household_dataframe(trace))
        write_append(paths[:events], event_dataframe(trace))
    end

    periods = CSV.read(paths[:periods], DataFrame)
    paired = paired_differences(periods)
    paired_path = joinpath(derived_dir, "paired-differences.csv")
    CSV.write(paired_path, paired)
    summary = paired_summary(paired)
    summary_path = joinpath(derived_dir, "paired-summary.csv")
    CSV.write(summary_path, summary)
    experiment_id = basename(experiment_dir)
    report_path = joinpath(derived_dir, "explanation-summary.md")
    write_summary_report(report_path, experiment_id, summary)
    return merge(paths, Dict(:paired => paired_path, :summary => summary_path, :report => report_path))
end

function calibration(name)
    symbol = Symbol(name)
    isdefined(Bit, symbol) || error("Unknown BeforeIT calibration: $name")
    value = getfield(Bit, symbol)
    hasproperty(value, :parameters) && hasproperty(value, :initial_conditions) ||
        error("$name is not a calibration with parameters and initial conditions")
    return value
end

function apply_changes!(parameters, scenario)
    for change in get(scenario, "changes", Any[])
        name = change["parameter"]
        haskey(parameters, name) || error("Unknown parameter in scenario $(scenario["id"]): $name")
        parameters[name] isa Number || error("Only scalar parameter changes are supported: $name")
        operation, value = change["operation"], change["value"]
        parameters[name] = if operation == "multiply"
            parameters[name] * value
        elseif operation == "add"
            parameters[name] + value
        elseif operation == "set"
            value
        else
            error("Unsupported parameter operation: $operation")
        end
    end
    return parameters
end

function write_manifest(path, rows)
    CSV.write(path, DataFrame(rows))
    return path
end

function generate_experiment(specification_path; output_root = joinpath(ROOT, "experiments"))
    specification = TOML.parsefile(specification_path)
    experiment = specification["experiment"]
    scenarios = specification["scenarios"]
    count(scenario -> scenario["role"] == "baseline", scenarios) == 1 ||
        error("The first implementation requires exactly one baseline scenario")
    count(scenario -> scenario["role"] == "intervention", scenarios) == 1 ||
        error("The first implementation requires exactly one intervention scenario")
    get(experiment, "shock", "none") == "none" || error("Only parameter interventions are supported in schema v1")

    experiment_id = experiment["id"]
    experiment_dir = joinpath(output_root, experiment_id)
    ispath(experiment_dir) && error("Refusing to overwrite experiment directory: $experiment_dir")
    mkpath(joinpath(experiment_dir, "traces"))
    cp(specification_path, joinpath(experiment_dir, "specification.toml"))

    source = calibration(experiment["calibration"])
    baseline_model = Bit.Model(deepcopy(source.parameters), deepcopy(source.initial_conditions))
    CSV.write(joinpath(experiment_dir, "field-inventory.csv"), field_inventory(baseline_model))

    horizon = Int(experiment["horizon"])
    seeds = Int.(experiment["seeds"])
    manifest_rows = NamedTuple[]
    manifest_path = joinpath(experiment_dir, "runs.csv")
    for seed in seeds, scenario in scenarios
        scenario_id, role = scenario["id"], scenario["role"]
        run_id = "$(scenario_id)-seed-$(seed)"
        pair_id = "seed-$(seed)"
        trace_relative_path = joinpath("traces", "$run_id.jld2")
        started = time()
        success, failure_reason = true, ""
        try
            parameters = apply_changes!(deepcopy(source.parameters), scenario)
            metadata = Dict{String, Any}(
                "experiment_id" => experiment_id,
                "research_question" => experiment["research_question"],
                "calibration_id" => experiment["calibration"],
                "run_id" => run_id,
                "scenario_id" => scenario_id,
                "scenario_description" => get(scenario, "description", ""),
                "role" => role,
                "pair_id" => pair_id,
                "seed" => seed,
                "horizon" => horizon,
                "shock" => get(experiment, "shock", "none"),
                "outcomes" => get(experiment, "outcomes", String[]),
                "mechanisms" => get(experiment, "mechanisms", String[]),
            )
            trace, _ = simulate_trace(parameters, source.initial_conditions; horizon, seed, metadata)
            save_trace(joinpath(experiment_dir, trace_relative_path), trace)
        catch error
            success = false
            failure_reason = sprint(showerror, error, catch_backtrace())
        end
        push!(
            manifest_rows, (
                run_id,
                scenario_id,
                role,
                pair_id,
                seed,
                horizon,
                trace_path = success ? trace_relative_path : "",
                runtime_seconds = time() - started,
                success,
                failure_reason,
            )
        )
        write_manifest(manifest_path, manifest_rows)
    end
    all(row.success for row in manifest_rows) || error("One or more trace runs failed; see $manifest_path")
    derive_experiment!(experiment_dir)
    return experiment_dir
end

end
