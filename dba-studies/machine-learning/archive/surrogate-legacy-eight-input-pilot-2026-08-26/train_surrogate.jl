include("surrogate_utils.jl")

function train_surrogate(data_dir = joinpath(@__DIR__, "data"), results_dir = joinpath(@__DIR__, "results"); ridge = 1e-8)
    data = CSV.read(joinpath(data_dir, "configuration_targets.csv"), DataFrame)
    nrow(data) >= 3 || error("At least three configurations are required to train and test the surrogate")
    splits = split_ids(data.configuration_id)
    train = filter(:configuration_id => in(Set(splits.train)), data)
    test = filter(:configuration_id => in(Set(splits.test)), data)
    isempty(test) && error("The configuration-level test split is empty")

    means = [mean(train[!, name]) for name in PARAMETER_NAMES]
    scales = [std(train[!, name]) for name in PARAMETER_NAMES]
    scales[iszero.(scales)] .= 1
    design(frame) = hcat(ones(nrow(frame)), (Matrix(frame[:, PARAMETER_NAMES]) .- means') ./ scales')
    x_train, x_test = design(train), design(test)
    penalty = Diagonal(vcat(0.0, fill(ridge, length(PARAMETER_NAMES))))

    coefficients = DataFrame(term = vcat("intercept", PARAMETER_NAMES))
    predictions = DataFrame(configuration_id = test.configuration_id)
    metric_rows = DataFrame()
    intervals = Dict{String, Vector{Float64}}()
    for target in TARGET_NAMES
        y_train, y_test = train[!, target], test[!, target]
        beta = (x_train' * x_train + penalty) \ (x_train' * y_train)
        predicted = x_test * beta
        residuals = y_train - x_train * beta
        approximation_error = quantile(abs.(residuals), 0.90)
        simulation_error = 1.645 * median(train[!, "$(target)_std"])
        half_width = hypot(approximation_error, simulation_error)
        interval = [-half_width, half_width]
        score = metrics(y_test, predicted)
        coefficients[!, target] = beta
        predictions[!, "actual_$target"] = y_test
        predictions[!, "predicted_$target"] = predicted
        intervals[target] = interval
        push!(metric_rows, (target = target, mae = score.mae, nrmse = score.nrmse, r2 = score.r2))
    end

    mkpath(results_dir)
    CSV.write(joinpath(results_dir, "coefficients.csv"), coefficients)
    CSV.write(joinpath(results_dir, "test_predictions.csv"), predictions)
    CSV.write(joinpath(results_dir, "metrics.csv"), metric_rows)
    JLD2.save(joinpath(results_dir, "surrogate.jld2"), "parameter_names", PARAMETER_NAMES, "target_names", TARGET_NAMES, "means", means, "scales", scales, "coefficients", Matrix(coefficients[:, TARGET_NAMES]), "residual_intervals", intervals, "bounds", TOML.parsefile(joinpath(data_dir, "metadata.toml"))["parameters"])
    return metric_rows
end

abspath(PROGRAM_FILE) == (@__FILE__) && train_surrogate()
