# [Photosynthesis](@id photosynthesis_page)

List all models available for photosynthesis, how to use them, what are the parameters...


## Parameter effects
### J~PPFD

First we import the packages needed:

```@example 1
using Plots;
using PlantBiophysics
```

Then we set up our models and their parameter values:

```@example 1
A = Fvcb(); PPFD = 0:100:2000;
```

And finally we plot `J ~ PPFD` with different parameter values, with the simplification that JMax is equal to JMaxRef:

```@example 1
plot(x -> PlantBiophysics.get_J(x, A.JMaxRef, A.α, A.θ), PPFD, xlabel = "PPFD (μmol m⁻² s⁻¹)",
            ylab = "J (μmol m⁻² s⁻¹)", label = "Default values", legend = :bottomright);
plot!(x -> PlantBiophysics.get_J(x, A.JMaxRef, A.α, A.θ * 0.5), PPFD, label = "θ * 0.5");
plot!(x -> PlantBiophysics.get_J(x, A.JMaxRef, A.α * 0.5, A.θ), PPFD, label = "α * 0.5");
savefig("f-plot.svg"); nothing # hide
```

![](f-plot.svg)
