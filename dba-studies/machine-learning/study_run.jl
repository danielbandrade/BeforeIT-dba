import BeforeIT as Bit

using Random, Plots

parameters = Bit.AUSTRIA2010Q1.parameters
initial_conditions = Bit.AUSTRIA2010Q1.initial_conditions

T, n_sims = 20, 32
base = Bit.Model(parameters, initial_conditions)
models = Bit.ensemblerun!([deepcopy(base) for _ in 1:n_sims], T)
dv = Bit.DataVector(models)          # fields become T×n_sims matrices

g = dv.real_gdp
m, s = mean(g, dims=2), std(g, dims=2) ./ sqrt(n_sims)
plot(m, ribbon=s, fillalpha=0.2, label="mean real GDP ± s.e.")