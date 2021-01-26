
## Plotting J~PPFD (simplification here, JMax = JMaxRef):

```@example
using Plots;
A = Fvcb(); PPFD = 0:100:2000;
plot(x -> PlantBiophysics.J(x, A.JMaxRef, A.α, A.θ), PPFD, xlabel = "PPFD (μmol m⁻² s⁻¹)",
            ylab = "J (μmol m⁻² s⁻¹)", label = "Default values", legend = :bottomright);
plot!(x -> PlantBiophysics.J(x, A.JMaxRef, A.α, A.θ * 0.5), PPFD, label = "θ * 0.5");
plot!(x -> PlantBiophysics.J(x, A.JMaxRef, A.α * 0.5, A.θ), PPFD, label = "α * 0.5");
savefig("f-plot.svg"); nothing hide
```

![](f-plot.svg)
