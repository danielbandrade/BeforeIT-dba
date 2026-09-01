import BeforeIT as Bit
using JLD2
ENV["GKSwstype"] = "100"
using Plots

const INPUT = joinpath(@__DIR__, "scale-1-results.jld2")
const OUTPUT = joinpath(@__DIR__, "scale-1-results.png")

isfile(INPUT) || error("Run dba-studies/scaling-experiments/run-scale-0.1.jl first")
data = JLD2.load(INPUT, "data")
quarters = 0:(length(data.collection_time) - 1)
indexed(series) = 100 .* series ./ first(series)

p1 = plot(
    quarters,
    [data.nominal_gdp data.real_gdp];
    label = ["Nominal GDP" "Real GDP"],
    title = "GDP levels",
    xlabel = "",
    ylabel = "Model units",
    linewidth = 2,
)

p2 = plot(
    quarters,
    hcat(
        indexed(data.real_household_consumption),
        indexed(data.real_government_consumption),
        indexed(data.real_capitalformation),
        indexed(data.real_exports),
        indexed(data.real_imports),
    );
    label = ["Households" "Government" "Capital" "Exports" "Imports"],
    title = "Real expenditure (initial = 100)",
    xlabel = "",
    ylabel = "Index",
    linewidth = 2,
)

gdp_growth = 100 .* diff(log.(data.real_gdp))
deflator = data.nominal_gdp ./ data.real_gdp
inflation = 100 .* diff(log.(deflator))
p3 = plot(
    1:last(quarters),
    [gdp_growth inflation];
    label = ["Real GDP growth" "GDP inflation"],
    title = "Quarterly growth and inflation",
    xlabel = "",
    ylabel = "%",
    linewidth = 2,
)

p4 = plot(
    quarters,
    [data.wages data.compensation_employees data.operating_surplus];
    label = ["Wages" "Compensation" "Operating surplus"],
    title = "Income distribution",
    xlabel = "",
    ylabel = "Model units",
    linewidth = 2,
)

p5 = plot(
    quarters,
    100 .* [data.euribor data.gdp_deflator_growth_ea];
    label = ["Euribor" "Euro-area inflation"],
    title = "External financial conditions",
    xlabel = "Quarter",
    ylabel = "%",
    linewidth = 2,
)

final_sector_gva = data.real_sector_gva[end]
top_sectors = sortperm(final_sector_gva; rev = true)[1:10]
p6 = bar(
    string.(top_sectors),
    final_sector_gva[top_sectors];
    label = false,
    title = "Largest sectors by final real GVA",
    xlabel = "Sector number",
    ylabel = "Real GVA",
)

metadata = JLD2.load(INPUT, "metadata")
dashboard = plot(
    p1, p2, p3, p4, p5, p6;
    layout = (3, 2),
    size = (1400, 1500),
    plot_title = "$(metadata["country"]) — scale $(metadata["scale"]), seed $(metadata["seed"])",
)
savefig(dashboard, OUTPUT)
println("saved: ", OUTPUT)
