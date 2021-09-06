# Getting started

```@setup usepkg
using PlantBiophysics
leaf = LeafModels(photosynthesis = Fvcb(), stomatal_conductance = Medlyn(0.03, 12.0))
```

## TL;DR

Here your first simulation for the leaf energy balance, photosynthesis and stomatal conductance altogether with few lines of codes:

```@example usepkg
meteo = Atmosphere(T = 22.0, Wind = 0.8333, P = 101.325, Rh = 0.4490995)

leaf = LeafModels(
        energy = Monteith(),
        photosynthesis = Fvcb(),
        stomatal_conductance = Medlyn(0.03, 12.0),
        Rₛ = 13.747, skyFraction = 1.0, PPFD = 1500.0, d = 0.03
    )

energy_balance!(leaf,meteo)

DataFrame(leaf)
```

Curious to understand more ? Let's first introduce the package design and then what are the `LeafModels`, `Atmosphere` or models such as `Monteith`.
