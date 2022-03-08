# [Photosynthesis](@id photosynthesis_page)

```@setup usepkg
using PlantBiophysics
```

The photosynthesis process can be simulated using [`photosynthesis!`](@ref) or [`photosynthesis`](@ref). Several models are available to simulate it:

- [`Fvcb`](@ref): an implementation of the Farquhar–von Caemmerer–Berry (FvCB) model for C3 photosynthesis (Farquhar et al., 1980; von Caemmerer and Farquhar, 1981) using an analytical resolution
- [`FvcbIter`](@ref): the same model but implemented using an iterative computation over Cᵢ
- [`FvcbRaw`](@ref): the same model but without the coupling with the stomatal conductance, *i.e.* as presented in the original paper. This version needs Cᵢ as input.
- [`ConstantA`](@ref): a model to set the photosynthesis to a constant value (mainly for testing)

You can choose which model you use by passing a component with an assimilation model set to one of the `structs` above.

For example, you can simulate a constant assimilation for a leaf using the following:

```@example usepkg
meteo = Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)

leaf = LeafModels(
    photosynthesis = ConstantA(25.0),
    Cₛ = 380.0
)

photosynthesis(leaf,meteo)
```

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
