# [Uncertainty propagation] (@id uncertainty_propagation_page)

## Monte Carlo uncertainty propagation

Thanks to the implementation of `PlantBiophysics.jl`, it is possible to propagate uncertainties in an easy way. Instead of using classic datatypes as `Float64`, we use specific datatype implemented in the Julia package `MonteCarloMeasurements.jl` so we can propagate distributions rather than scalars.



```@example 1
using PlantBiophysics
using MonteCarloMeasurements

meteo = Atmosphere(T = 22.0 ∓ 0.1, Wind = 0.8333 ∓ 0.1, P = 101.325 ∓ 1., Rh = 0.4490995 ∓ 0.02, Cₐ = 400. ∓ 1.)
leaf = LeafModels(energy = Monteith(),
            photosynthesis = Fvcb(),
            stomatal_conductance = Medlyn(0.03, 12.0),
            Rₛ = 13.747 ∓ 1., skyFraction = 1.0, PPFD = 1500.0 ∓ 1., d = 0.03 ∓ 0.001)

results = energy_balance(leaf,meteo)

p1 = plot(meteo.T,legend=:false,xlabel="Tₐ (°C)",ylabel="density",dpi=300,title="(a)",titlefontsize=9)
p2 = plot(leaf.status.d,legend=:false,xlabel="d (m)",ylabel="density",dpi=300,title="(b)",titlefontsize=9)
p3 = plot(results.Tₗ,legend=:false,xlabel="Tₗ (°C)",ylabel="density",dpi=300,title="(c)",titlefontsize=9)
p4 = plot(results.A,legend=:false,xlabel="A",ylabel="density",dpi=300,title="(d)",titlefontsize=9)
plot(p1,p2,p3,p4,dpi=300,titleloc=:right)
savefig("distributions-example.svg"); nothing #hide
```

![](distributions-example.svg)